import Dependencies
import DependenciesMacros
import Foundation

/// One video in the Drills library.
public struct Drill: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var creator: String
    public var category: DrillCategory
    /// "4:12"
    public var duration: String
    /// `nil` for placeholders until real videos are chosen (Q6).
    public var youtubeID: String?

    public init(id: String, title: String, creator: String, category: DrillCategory, duration: String, youtubeID: String? = nil) {
        self.id = id
        self.title = title
        self.creator = creator
        self.category = category
        self.duration = duration
        self.youtubeID = youtubeID
    }

    /// "Coach Name · Short putts"
    public var subtitle: String { "\(creator) · \(category.title)" }
}

public enum DrillCategory: String, CaseIterable, Codable, Sendable {
    case greenReading, speedControl, tempo, alignment, shortPutts

    public var title: String {
        switch self {
        case .greenReading: "Green reading"
        case .speedControl: "Speed control"
        case .tempo: "Tempo"
        case .alignment: "Alignment"
        case .shortPutts: "Short putts"
        }
    }
}

/// The bundled `drills.json` catalogue.
@DependencyClient
public struct DrillCatalogClient: Sendable {
    public var load: @Sendable () throws -> [Drill]
}

extension DrillCatalogClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            load: {
                guard let url = Bundle.module.url(forResource: "drills", withExtension: "json") else { return [] }
                return try JSONDecoder().decode([Drill].self, from: Data(contentsOf: url))
            }
        )
    }

    public static var previewValue: Self { liveValue }

    public static let testValue = Self()
}
