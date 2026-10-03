import Foundation
import SwiftData

// Current model types. Screens use these aliases, so a new schema version only changes the alias targets.
typealias Profile = SchemaV2.Profile
typealias DailyCheckIn = SchemaV2.DailyCheckIn
typealias ZoneAssessment = SchemaV2.ZoneAssessment
typealias Treatment = SchemaV2.Treatment
typealias DoseLog = SchemaV2.DoseLog
typealias Photo = SchemaV2.Photo
typealias QuestionnaireResult = SchemaV2.QuestionnaireResult

/// Current schema. Changes from V1: profile name, sex, birth year and arthritis status;
/// weather on the check-in; `syncID` on every record that is synced to the cloud.
/// Never change models here after release — add `SchemaV3` and a migration stage instead.
///
/// Enums are stored as their string raw values (`…ID` / `…IDs` fields) so that
/// predicates work and stored data does not depend on Swift type names.
///
/// `syncID` is optional so the lightweight migration can add it; records migrated
/// from V1 get one from the sync engine before their first upload.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Profile.self, DailyCheckIn.self, ZoneAssessment.self,
            Treatment.self, DoseLog.self, Photo.self, QuestionnaireResult.self,
        ]
    }

    // MARK: - Profile

    /// Single record with onboarding answers.
    @Model
    final class Profile {
        var syncID: UUID?
        /// First name for the greeting; empty if not given.
        var name: String = ""
        /// `Sex` raw value.
        var sexID: String?
        /// Age is asked in onboarding and stored as a birth year, so it stays correct.
        var birthYear: Int?
        /// `ArthritisStatus` raw value.
        var arthritisStatusID: String?
        var psoriasisTypeIDs: [String]
        var onsetYear: Int?
        var goalIDs: [String]
        /// Self-rated skin at onboarding, 0 (clear) … 1 (very bad).
        var baselineSelfRating: Double?
        var createdAt: Date

        init(
            name: String = "",
            sex: Sex? = nil,
            birthYear: Int? = nil,
            arthritisStatus: ArthritisStatus? = nil,
            psoriasisTypes: [PsoriasisType] = [],
            onsetYear: Int? = nil,
            goals: [Goal] = [],
            baselineSelfRating: Double? = nil,
            createdAt: Date = .now
        ) {
            self.syncID = UUID()
            self.name = name
            self.sexID = sex?.rawValue
            self.birthYear = birthYear
            self.arthritisStatusID = arthritisStatus?.rawValue
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

        var sex: Sex? {
            get { sexID.flatMap(Sex.init(rawValue:)) }
            set { sexID = newValue?.rawValue }
        }

        var arthritisStatus: ArthritisStatus? {
            get { arthritisStatusID.flatMap(ArthritisStatus.init(rawValue:)) }
            set { arthritisStatusID = newValue?.rawValue }
        }
    }

    // MARK: - Daily check-in

    /// One record per calendar day; editing the same day updates it.
    @Model
    final class DailyCheckIn {
        /// Start of the local day.
        var syncID: UUID?
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
        /// Weather where the user was, saved with the check-in (Open-Meteo). Nil if not available.
        /// Relative humidity, %.
        var humidity: Double?
        /// UV index (daily maximum).
        var uvIndex: Double?
        /// Air temperature, °C.
        var temperature: Double?
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
            self.syncID = UUID()
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

        var syncID: UUID?
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
            self.syncID = UUID()
            self.day = calendar.startOfDay(for: day)
            self.zoneID = zoneID
            self.palms = palms
            self.erythema = erythema
            self.induration = induration
            self.scale = scale
            self.pustules = pustules
        }
    }

    // MARK: - Treatment

    /// One item of the user's treatment plan. The medication catalog lives in code, not here.
    @Model
    final class Treatment {
        var syncID: UUID?
        var name: String
        /// `MedicationCatalog` item id, or nil for a custom medication.
        var catalogID: String?
        var kindID: String
        var steroidClassID: String?
        var scheduleKindID: String
        /// For `timesPerDay`: doses per day.
        var timesPerDay: Int
        /// For `everyNDays` / `everyNWeeks`: the N.
        var interval: Int
        /// For `weekly`: 1 = Sunday … 7 = Saturday (`Calendar` weekday).
        var weekday: Int?
        /// Reminder times as minutes after midnight, e.g. 480 = 08:00.
        var doseMinutes: [Int]
        var fingertipUnits: Double?
        /// Stable `BodyZone.id` values.
        var zoneIDs: [String]
        var startDate: Date
        var endDate: Date?
        var stopReason: String?
        var notes: String

        @Relationship(deleteRule: .cascade, inverse: \DoseLog.treatment)
        var doses: [DoseLog] = []

        init(
            name: String,
            catalogID: String? = nil,
            kind: TreatmentKind,
            steroidClass: SteroidClass? = nil,
            scheduleKind: ScheduleKind,
            timesPerDay: Int = 1,
            interval: Int = 1,
            weekday: Int? = nil,
            doseMinutes: [Int] = [],
            fingertipUnits: Double? = nil,
            zoneIDs: [String] = [],
            startDate: Date = .now,
            notes: String = ""
        ) {
            self.syncID = UUID()
            self.name = name
            self.catalogID = catalogID
            self.kindID = kind.rawValue
            self.steroidClassID = steroidClass?.rawValue
            self.scheduleKindID = scheduleKind.rawValue
            self.timesPerDay = timesPerDay
            self.interval = interval
            self.weekday = weekday
            self.doseMinutes = doseMinutes
            self.fingertipUnits = fingertipUnits
            self.zoneIDs = zoneIDs
            self.startDate = startDate
            self.notes = notes
        }

        /// Unknown raw values (from a newer app version) fall back to a safe default.
        var kind: TreatmentKind {
            get { TreatmentKind(rawValue: kindID) ?? .cream }
            set { kindID = newValue.rawValue }
        }

        var steroidClass: SteroidClass? {
            get { steroidClassID.flatMap(SteroidClass.init(rawValue:)) }
            set { steroidClassID = newValue?.rawValue }
        }

        var scheduleKind: ScheduleKind {
            get { ScheduleKind(rawValue: scheduleKindID) ?? .asNeeded }
            set { scheduleKindID = newValue.rawValue }
        }

        var isActive: Bool { endDate == nil }
    }

    // MARK: - Dose log

    /// A dose marked as done or skipped.
    @Model
    final class DoseLog {
        var syncID: UUID?
        var treatment: Treatment?
        /// The planned slot this entry closes, if it came from the schedule.
        var scheduledAt: Date?
        var timestamp: Date
        var statusID: String
        /// `InjectionSite` raw value, for biologics.
        var injectionSiteID: String?
        var fingertipUnits: Double?
        /// Free text, e.g. side effects.
        var note: String

        init(
            treatment: Treatment? = nil,
            scheduledAt: Date? = nil,
            timestamp: Date = .now,
            status: DoseStatus,
            injectionSite: InjectionSite? = nil,
            fingertipUnits: Double? = nil,
            note: String = ""
        ) {
            self.syncID = UUID()
            self.treatment = treatment
            self.scheduledAt = scheduledAt
            self.timestamp = timestamp
            self.statusID = status.rawValue
            self.injectionSiteID = injectionSite?.rawValue
            self.fingertipUnits = fingertipUnits
            self.note = note
        }

        var status: DoseStatus {
            get { DoseStatus(rawValue: statusID) ?? .done }
            set { statusID = newValue.rawValue }
        }

        var injectionSite: InjectionSite? {
            get { injectionSiteID.flatMap(InjectionSite.init(rawValue:)) }
            set { injectionSiteID = newValue?.rawValue }
        }
    }

    // MARK: - Photo

    /// Metadata for a zone photo. The image itself is a file in Application Support/Photos.
    /// Photos are never synced, so there is no `syncID`.
    @Model
    final class Photo {
        /// Start of the local day.
        var day: Date
        var createdAt: Date
        /// Stable `BodyZone.id`.
        var zoneID: String
        /// File name inside the protected photo folder (not a full path).
        var fileName: String
        var notes: String

        init(day: Date, zoneID: String, fileName: String, notes: String = "", calendar: Calendar = .current) {
            self.day = calendar.startOfDay(for: day)
            self.createdAt = .now
            self.zoneID = zoneID
            self.fileName = fileName
            self.notes = notes
        }
    }

    // MARK: - Questionnaire result

    @Model
    final class QuestionnaireResult {
        var syncID: UUID?
        var kindID: String
        var date: Date
        /// Raw answers in question order.
        var answers: [Int]
        var score: Int

        init(kind: QuestionnaireKind, date: Date = .now, answers: [Int], score: Int) {
            self.syncID = UUID()
            self.kindID = kind.rawValue
            self.date = date
            self.answers = answers
            self.score = score
        }

        var kind: QuestionnaireKind {
            get { QuestionnaireKind(rawValue: kindID) ?? .dlqi }
            set { kindID = newValue.rawValue }
        }
    }
}
