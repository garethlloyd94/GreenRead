import Foundation

/// Train-mode verdict for one putt, comparing the golfer's read with the measured slope.
public enum Verdict: String, Codable, CaseIterable, Sendable {
    case spotOn, underRead, overRead, wrongWay

    public var title: String {
        switch self {
        case .spotOn: "Spot on"
        case .underRead: "Under-read"
        case .overRead: "Over-read"
        case .wrongWay: "Wrong way"
        }
    }
}
