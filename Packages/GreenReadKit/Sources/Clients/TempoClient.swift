import AVFoundation
import CoreHaptics
import Dependencies
import DependenciesMacros
import Foundation

public enum TempoBeatKind: Equatable, Sendable {
    case back, through
}

public struct TempoBeat: Equatable, Sendable {
    /// 0, 1, 2… from Start. Even beats are BACK, odd are THROUGH.
    public var index: Int
    public var kind: TempoBeatKind { index.isMultiple(of: 2) ? .back : .through }

    public init(index: Int) {
        self.index = index
    }
}

public struct TempoOptions: Equatable, Sendable {
    public var bpm: Int
    public var soundsOn: Bool
    public var hapticsOn: Bool

    public init(bpm: Int, soundsOn: Bool, hapticsOn: Bool) {
        self.bpm = bpm
        self.soundsOn = soundsOn
        self.hapticsOn = hapticsOn
    }
}

/// The metronome. `beats` starts it and yields each beat as it sounds; cancelling the
/// stream stops it. Clicks are scheduled ahead on the audio clock, not with timers.
@DependencyClient
public struct TempoClient: Sendable {
    public var beats: @Sendable (_ options: TempoOptions) -> AsyncStream<TempoBeat> = { _ in .finished }
    public var setBPM: @Sendable (_ bpm: Int) async -> Void
}

extension TempoClient: DependencyKey {
    public static var liveValue: Self {
        let current = LockIsolated<Metronome?>(nil)
        return Self(
            beats: { options in
                AsyncStream { continuation in
                    let metronome = Metronome(options: options) { continuation.yield($0) }
                    current.setValue(metronome)
                    continuation.onTermination = { _ in
                        metronome.stop()
                        current.withValue { if $0 === metronome { $0 = nil } }
                    }
                    if !metronome.start() {
                        continuation.finish()
                    }
                    metronome.onInterruption = { continuation.finish() }
                }
            },
            setBPM: { bpm in current.value?.setBPM(bpm) }
        )
    }

    /// Beats on a plain timer, for previews and the Simulator UI.
    public static var previewValue: Self {
        let bpm = LockIsolated(76)
        return Self(
            beats: { options in
                bpm.setValue(options.bpm)
                return AsyncStream { continuation in
                    let task = Task {
                        var index = 0
                        while !Task.isCancelled {
                            continuation.yield(TempoBeat(index: index))
                            index += 1
                            try? await Task.sleep(for: .seconds(60.0 / Double(bpm.value)))
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            setBPM: { bpm.setValue($0) }
        )
    }

    public static let testValue = Self()
}

// MARK: - Live engine

/// AVAudioEngine metronome. All mutable state is touched only on `queue`.
final class Metronome: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.garethlloyd.greenread.metronome", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let backClick: AVAudioPCMBuffer
    private let throughClick: AVAudioPCMBuffer
    private var haptics: CHHapticEngine?
    private var timer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []

    private var options: TempoOptions
    private let onBeat: @Sendable (TempoBeat) -> Void
    var onInterruption: (@Sendable () -> Void)?

    /// Player timeline (samples) and host time of the next beat to schedule.
    private var nextBeatSample: AVAudioFramePosition = 0
    private var nextBeatHostTime: UInt64 = 0
    private var nextBeatIndex = 0
    /// Scheduled beats not yet reported to the UI, in order.
    private var pending: [(index: Int, hostTime: UInt64)] = []

    /// How far ahead clicks are queued.
    private static let lookahead: TimeInterval = 0.25

    init(options: TempoOptions, onBeat: @escaping @Sendable (TempoBeat) -> Void) {
        self.options = options
        self.onBeat = onBeat
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        self.backClick = Self.click(frequency: 1_900, duration: 0.03, format: format)
        self.throughClick = Self.click(frequency: 950, duration: 0.05, format: format)
    }

    /// Returns false if audio couldn't start.
    func start() -> Bool {
        queue.sync {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)

                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                engine.mainMixerNode.outputVolume = options.soundsOn ? 1 : 0
                try engine.start()

                if options.hapticsOn, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                    let haptics = try CHHapticEngine()
                    haptics.isAutoShutdownEnabled = false
                    try haptics.start()
                    self.haptics = haptics
                }

                let startHost = mach_absolute_time() + Self.hostTicks(seconds: 0.1)
                nextBeatHostTime = startHost
                nextBeatSample = 0
                player.play(at: AVAudioTime(hostTime: startHost))
                scheduleAhead()
                startTimer()
                observeInterruptions()
                return true
            } catch {
                return false
            }
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            player.stop()
            engine.stop()
            haptics?.stop()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func setBPM(_ bpm: Int) {
        queue.async { [self] in
            options.bpm = bpm
        }
    }

    // MARK: Scheduling

    private var beatSeconds: TimeInterval { 60.0 / Double(options.bpm) }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.scheduleAhead()
            self?.reportDueBeats()
        }
        timer.resume()
        self.timer = timer
    }

    /// Queues every beat that falls within the lookahead window.
    private func scheduleAhead() {
        let horizon = mach_absolute_time() + Self.hostTicks(seconds: Self.lookahead)
        while nextBeatHostTime <= horizon {
            let index = nextBeatIndex
            let buffer = index.isMultiple(of: 2) ? backClick : throughClick
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: nextBeatSample, atRate: format.sampleRate))
            scheduleHaptic(index: index, hostTime: nextBeatHostTime)
            pending.append((index, nextBeatHostTime))

            let seconds = beatSeconds
            nextBeatSample += AVAudioFramePosition((seconds * format.sampleRate).rounded())
            nextBeatHostTime += Self.hostTicks(seconds: seconds)
            nextBeatIndex += 1
        }
    }

    private func reportDueBeats() {
        let now = mach_absolute_time()
        while let first = pending.first, first.hostTime <= now {
            pending.removeFirst()
            onBeat(TempoBeat(index: first.index))
        }
    }

    private func scheduleHaptic(index: Int, hostTime: UInt64) {
        guard let haptics else { return }
        let isBack = index.isMultiple(of: 2)
        let now = mach_absolute_time()
        let delay = hostTime > now ? Self.seconds(hostTicks: hostTime - now) : 0
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: isBack ? 0.6 : 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: isBack ? 0.9 : 0.4),
            ],
            relativeTime: 0
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? haptics.makePlayer(with: pattern)
        else { return }
        try? player.start(atTime: haptics.currentTime + delay)
    }

    private func observeInterruptions() {
        let observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: raw) == .began
            else { return }
            self?.onInterruption?()
        }
        observers.append(observer)
    }

    // MARK: Sounds

    /// A short sine click with a fast exponential decay.
    private static func click(frequency: Double, duration: TimeInterval, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let envelope = exp(-t * 90)
            samples[frame] = Float(sin(2 * .pi * frequency * t) * envelope * 0.9)
        }
        return buffer
    }

    // MARK: Host time

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func hostTicks(seconds: TimeInterval) -> UInt64 {
        UInt64(seconds * 1_000_000_000 * Double(timebase.denom) / Double(timebase.numer))
    }

    private static func seconds(hostTicks: UInt64) -> TimeInterval {
        Double(hostTicks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }
}
