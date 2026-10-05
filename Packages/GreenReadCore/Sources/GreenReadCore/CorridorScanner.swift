import Foundation

/// A point in AR world space, metres. y is up.
public struct Point3: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// What the scan prompt pill should ask for.
public enum ScanPrompt: Equatable, Sendable {
    case walkToHole, coverLeft, coverRight, gapBehind, slowDown

    public var text: String {
        switch self {
        case .walkToHole: "Walk slowly to the hole"
        case .coverLeft: "Cover left side"
        case .coverRight: "Cover right side"
        case .gapBehind: "Gap behind you"
        case .slowDown: "Slow down"
        }
    }
}

public struct ScanProgress: Equatable, Sendable {
    /// 0–1 share of the corridor's cells with enough surface.
    public var coverage: Double
    public var prompt: ScanPrompt
    /// The plane through the corridor so far; nil until there's enough to fit.
    public var slope: SlopeReading?

    public init(coverage: Double, prompt: ScanPrompt, slope: SlopeReading?) {
        self.coverage = coverage
        self.prompt = prompt
        self.slope = slope
    }
}

/// Accumulates scene-reconstruction mesh vertices over the ball→hole corridor and fits a
/// plane to it.
///
/// Corridor coordinates: `u` runs from the ball (0) toward the hole (`length`), `v` runs
/// across, positive to the right looking from ball to hole. Surface height is binned into
/// 10 cm cells; each mesh anchor's contribution is replaced when that anchor updates.
public struct CorridorScanner: Sendable {
    public static let cellSize = 0.1
    /// Half-width of the corridor either side of the line.
    public static let halfWidth = 0.5
    /// Extra corridor behind the ball and past the hole.
    public static let margin = 0.3
    /// Vertices a cell needs before it counts as covered.
    public static let minimumVertices = 3
    /// Coverage needed for a trustworthy read (S4 below this).
    public static let goodCoverage = 0.7
    /// Coverage at which the scan finishes on its own.
    public static let completeCoverage = 0.95

    public let ball: Point3
    public let hole: Point3
    public let length: Double

    private let forward: (x: Double, z: Double)
    private let right: (x: Double, z: Double)
    private let columns: Int
    private let rows: Int
    private var anchors: [String: [Int: CellSum]] = [:]

    struct CellSum: Sendable {
        var height = 0.0
        var count = 0
    }

    public init(ball: Point3, hole: Point3) {
        self.ball = ball
        self.hole = hole
        let dx = hole.x - ball.x
        let dz = hole.z - ball.z
        let length = max(0.01, (dx * dx + dz * dz).squareRoot())
        self.length = length
        self.forward = (dx / length, dz / length)
        self.right = (-dz / length, dx / length)
        self.columns = Int(((length + 2 * Self.margin) / Self.cellSize).rounded(.up))
        self.rows = Int((2 * Self.halfWidth / Self.cellSize).rounded(.up))
    }

    /// Replaces everything one mesh anchor contributed with its current vertices.
    public mutating func update(anchor id: String, vertices: [Point3]) {
        var cells: [Int: CellSum] = [:]
        for vertex in vertices {
            guard let cell = cellIndex(vertex) else { continue }
            cells[cell, default: CellSum()].height += vertex.y
            cells[cell, default: CellSum()].count += 1
        }
        anchors[id] = cells.isEmpty ? nil : cells
    }

    public mutating func remove(anchor id: String) {
        anchors[id] = nil
    }

    public mutating func reset() {
        anchors.removeAll()
    }

    // MARK: Results

    public var progress: ScanProgress {
        let cells = mergedCells()
        let covered = cells.filter { $0.value.count >= Self.minimumVertices }
        let total = columns * rows
        let coverage = Double(covered.count) / Double(max(1, total))
        return ScanProgress(coverage: coverage, prompt: prompt(covered: covered), slope: fit(covered))
    }

    /// Corridor (u, v) for a world point, ignoring height.
    public func corridor(_ point: Point3) -> (u: Double, v: Double) {
        let dx = point.x - ball.x
        let dz = point.z - ball.z
        return (dx * forward.x + dz * forward.z, dx * right.x + dz * right.z)
    }

    /// World point for corridor (u, v) at a given height.
    public func world(u: Double, v: Double, y: Double) -> Point3 {
        Point3(
            x: ball.x + u * forward.x + v * right.x,
            y: y,
            z: ball.z + u * forward.z + v * right.z
        )
    }

    /// Centres of every covered cell, for the lime paint overlay.
    public var coveredCells: [(u: Double, v: Double)] {
        mergedCells()
            .filter { $0.value.count >= Self.minimumVertices }
            .map { index, _ in centre(of: index) }
    }

    // MARK: Private

    private func cellIndex(_ point: Point3) -> Int? {
        let (u, v) = corridor(point)
        let column = Int(((u + Self.margin) / Self.cellSize).rounded(.down))
        let row = Int(((v + Self.halfWidth) / Self.cellSize).rounded(.down))
        guard (0..<columns).contains(column), (0..<rows).contains(row) else { return nil }
        return column * rows + row
    }

    private func centre(of index: Int) -> (u: Double, v: Double) {
        let column = index / rows
        let row = index % rows
        return (
            (Double(column) + 0.5) * Self.cellSize - Self.margin,
            (Double(row) + 0.5) * Self.cellSize - Self.halfWidth
        )
    }

    private func mergedCells() -> [Int: CellSum] {
        var merged: [Int: CellSum] = [:]
        for cells in anchors.values {
            for (index, sum) in cells {
                merged[index, default: CellSum()].height += sum.height
                merged[index, default: CellSum()].count += sum.count
            }
        }
        return merged
    }

    private func prompt(covered: [Int: CellSum]) -> ScanPrompt {
        var left = 0, right = 0, behind = 0
        let leftTotal = Double(columns * (rows / 2))
        let behindColumns = max(1, columns / 3)
        for index in covered.keys {
            let (u, v) = centre(of: index)
            if v < 0 { left += 1 } else { right += 1 }
            if u < length / 3 { behind += 1 }
        }
        let leftShare = Double(left) / max(1, leftTotal)
        let rightShare = Double(right) / max(1, leftTotal)
        let behindShare = Double(behind) / Double(behindColumns * rows)
        let overall = Double(covered.count) / Double(max(1, columns * rows))

        guard overall > 0.15 else { return .walkToHole }
        if leftShare + 0.2 < rightShare { return .coverLeft }
        if rightShare + 0.2 < leftShare { return .coverRight }
        if behindShare + 0.2 < overall { return .gapBehind }
        return .walkToHole
    }

    /// Least-squares plane height = a + b·u + c·v over covered cell centres.
    private func fit(_ covered: [Int: CellSum]) -> SlopeReading? {
        guard covered.count >= 12 else { return nil }
        var n = 0.0, su = 0.0, sv = 0.0, sh = 0.0
        var suu = 0.0, svv = 0.0, suv = 0.0, suh = 0.0, svh = 0.0
        for (index, sum) in covered {
            let (u, v) = centre(of: index)
            let h = sum.height / Double(sum.count)
            n += 1; su += u; sv += v; sh += h
            suu += u * u; svv += v * v; suv += u * v; suh += u * h; svh += v * h
        }
        // Centre the sums so the 2×2 system for b and c is well conditioned.
        let mu = su / n, mv = sv / n, mh = sh / n
        let cuu = suu / n - mu * mu
        let cvv = svv / n - mv * mv
        let cuv = suv / n - mu * mv
        let cuh = suh / n - mu * mh
        let cvh = svh / n - mv * mh
        let determinant = cuu * cvv - cuv * cuv
        guard abs(determinant) > 1e-9 else { return nil }
        let b = (cuh * cvv - cvh * cuv) / determinant
        let c = (cvh * cuu - cuh * cuv) / determinant
        return SlopeReading(uphillPercent: b * 100, sidePercent: c * 100)
    }
}

/// The curved putting line drawn on the green: it leaves the ball toward the aim point
/// and breaks back into the hole.
public enum BreakLine {
    /// Corridor points (u, v) from ball to hole. `aimMetres` is positive right of the hole.
    public static func points(length: Double, aimMetres: Double, count: Int = 32) -> [(u: Double, v: Double)] {
        // Cubic Bézier: start heading at the aim point, finish at the hole.
        let p0 = (u: 0.0, v: 0.0)
        let p1 = (u: length * 0.4, v: aimMetres * 0.4)
        let p2 = (u: length * 0.8, v: aimMetres * 0.75)
        let p3 = (u: length, v: 0.0)
        return (0...count).map { step in
            let t = Double(step) / Double(count)
            let a = (1 - t) * (1 - t) * (1 - t)
            let b = 3 * (1 - t) * (1 - t) * t
            let c = 3 * (1 - t) * t * t
            let d = t * t * t
            return (
                a * p0.u + b * p1.u + c * p2.u + d * p3.u,
                a * p0.v + b * p1.v + c * p2.v + d * p3.v
            )
        }
    }

    /// Lateral aim offset in metres for an aim result: right of the hole is positive.
    public static func aimMetres(_ result: AimResult) -> Double {
        let metres = Double(result.aimInches) * 0.0254
        switch result.aimSide {
        case .right: return metres
        case .left: return -metres
        case .centre: return 0
        }
    }
}
