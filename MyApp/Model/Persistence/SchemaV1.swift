import Foundation
import SwiftData

// Current model types. Screens use these aliases, so a new schema version only changes the alias targets.
typealias Profile = SchemaV1.Profile
typealias DailyCheckIn = SchemaV1.DailyCheckIn
typealias ZoneAssessment = SchemaV1.ZoneAssessment

/// First persisted schema. Never change models here after release —
/// add `SchemaV2` and a migration stage instead.
///
/// Enums are stored as their string raw values (`…ID` / `…IDs` fields) so that
/// predicates work and stored data does not depend on Swift type names.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Profile.self, DailyCheckIn.self, ZoneAssessment.self]
    }

    // MARK: - Profile

    /// Single record with onboarding answers.
    @Model
    final class Profile {
        var psoriasisTypeIDs: [String]
        var onsetYear: Int?
        var goalIDs: [String]
        /// Self-rated skin at onboarding, 0 (clear) … 1 (very bad).
        var baselineSelfRating: Double?
        var createdAt: Date

        init(
            psoriasisTypes: [PsoriasisType] = [],
            onsetYear: Int? = nil,
            goals: [Goal] = [],
            baselineSelfRating: Double? = nil,
            createdAt: Date = .now
        ) {
            self.psoriasisTypeIDs = psoriasisTypes.map(\.rawValue)
            self.onsetYear = onsetYear
            self.goalIDs = goals.map(\.rawValue)
            self.baselineSelfRating = baselineSelfRating
            self.createdAt = createdAt
        }

        var psoriasisTypes: [PsoriasisType] {
            get { psoriasisTypeIDs.compactMap(PsoriasisType.init(rawValue:)) }
            set { psoriasisTypeIDs = newValue.map(\.rawValue) }
        }

        var goals: [Goal] {
            get { goalIDs.compactMap(Goal.init(rawValue:)) }
            set { goalIDs = newValue.map(\.rawValue) }
        }
    }

    // MARK: - Daily check-in

    /// One record per calendar day; editing the same day updates it.
    @Model
    final class DailyCheckIn {
        /// Start of the local day.
        @Attribute(.unique) var day: Date
        /// Itch, 0–10 (NRS).
        var itch: Int
        /// Pain / burning, 0–10.
        var pain: Int?
        /// Sleep quality, 0–10.
        var sleep: Int?
        /// Mood / stress, 1–5.
        var mood: Int?
        var triggerIDs: [String]
        /// User-defined tags, stored as typed by the user.
        var customTags: [String]
        /// "New or spreading spots" — one of the flare signals.
        var newSpots: Bool
        var note: String
        var updatedAt: Date

        init(
            day: Date,
            itch: Int,
            pain: Int? = nil,
            sleep: Int? = nil,
            mood: Int? = nil,
            triggers: [Trigger] = [],
            customTags: [String] = [],
            newSpots: Bool = false,
            note: String = "",
            calendar: Calendar = .current
        ) {
            self.day = calendar.startOfDay(for: day)
            self.itch = itch
            self.pain = pain
            self.sleep = sleep
            self.mood = mood
            self.triggerIDs = triggers.map(\.rawValue)
            self.customTags = customTags
            self.newSpots = newSpots
            self.note = note
            self.updatedAt = .now
        }

        var triggers: [Trigger] {
            get { triggerIDs.compactMap(Trigger.init(rawValue:)) }
            set { triggerIDs = newValue.map(\.rawValue) }
        }
    }

    // MARK: - Zone assessment

    /// Self-assessment of one body zone on one day.
    @Model
    final class ZoneAssessment {
        #Unique<ZoneAssessment>([\.day, \.zoneID])

        /// Start of the local day.
        var day: Date
        /// Stable `BodyZone.id`, e.g. `front.elbow.left`.
        var zoneID: String
        /// Affected area in palms (1 palm ≈ 1 % of body surface).
        var palms: Double
        /// Redness, 0–4.
        var erythema: Int
        /// Thickness, 0–4.
        var induration: Int
        /// Scaling, 0–4.
        var scale: Int
        var pustules: Bool

        init(
            day: Date,
            zoneID: String,
            palms: Double,
            erythema: Int = 0,
            induration: Int = 0,
            scale: Int = 0,
            pustules: Bool = false,
            calendar: Calendar = .current
        ) {
            self.day = calendar.startOfDay(for: day)
            self.zoneID = zoneID
            self.palms = palms
            self.erythema = erythema
            self.induration = induration
            self.scale = scale
            self.pustules = pustules
        }
    }
}
