import Foundation

/// Age assurance for regions whose laws require it (Texas, Utah, Louisiana app store acts).
/// MySkin is rated 16+ and is not for children. The age range comes from Apple's Declared Age Range
/// service and is used only for this decision; nothing about it is stored.
nonisolated enum AgeGate {
    /// Youngest age MySkin is for (App Store rating 16+, Terms).
    static let minimumAge = 16

    enum Status: Equatable, Sendable {
        /// Not checked yet, or the check couldn't run (offline, no Apple Account) — try again next launch.
        case unknown
        /// The person's region doesn't require age assurance.
        case notRequired
        case allowed
        /// Declared younger than `minimumAge`.
        case underMinimum
    }

    /// What Apple's service answered, without its types.
    enum Answer: Equatable, Sendable {
        /// `lowerBound` is nil when the person is below the lowest age gate.
        case sharing(lowerBound: Int?)
        /// Only possible outside regulated regions.
        case declined
        case failed
    }

    static func status(isRequired: Bool?, answer: Answer?) -> Status {
        guard let isRequired else { return .unknown }
        guard isRequired else { return .notRequired }
        switch answer {
        case .sharing(let lowerBound?) where lowerBound >= minimumAge: return .allowed
        case .sharing: return .underMinimum
        // In regulated regions the system answers by itself; a decline or an error means we couldn't
        // check this time. Keep the app usable and ask again on the next launch.
        case .declined, .failed, nil: return .unknown
        }
    }

    /// Only people declared under the minimum age are kept out.
    static func isBlocked(_ status: Status) -> Bool { status == .underMinimum }
}
