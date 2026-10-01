import Foundation

/// Answers to the extra flare questions in the check-in (spec §2.1, §2.8).
struct RedFlagSymptoms: Hashable, Sendable {
    var fever = false
    /// Weakness or feeling generally unwell.
    var feelsUnwell = false
    var chills = false
    /// Recently stopped steroid tablets or injections (not creams).
    var stoppedSystemicSteroids = false
}

/// Conditions for the blocking «Seek medical care now» card.
/// Always shown — settings must not be able to hide them.
nonisolated enum RedFlag: String, CaseIterable, Identifiable, Sendable {
    case widespreadPustules, widespreadRedness, flareAfterSteroidWithdrawal

    var id: String { rawValue }

    var title: String { "Seek medical care now" }

    /// Neutral wording: describes the signs, does not name a diagnosis.
    var message: String {
        switch self {
        case .widespreadPustules:
            "Widespread pus-filled bumps together with fever or feeling unwell need urgent medical attention."
        case .widespreadRedness:
            "Redness over most of your body needs urgent medical attention, especially with chills or peeling."
        case .flareAfterSteroidWithdrawal:
            "Your skin is getting worse after stopping steroid tablets or injections. Contact your doctor today."
        }
    }
}

/// Red flags from the current body map and symptoms (spec §2.8).
/// PHQ-9 question 9 is not part of the MVP questionnaires and is not checked here.
enum RedFlagRules {
    /// Thresholds in one place so they are easy to tune.
    enum Threshold {
        /// Pustules over at least this share of the body count as widespread.
        /// Above palm-and-sole disease, which stays small.
        static let pustularBSA = 5.0
        /// Redness over more than this share of the body (erythroderma: 75–90 %).
        static let rednessBSA = 75.0
    }

    /// - Parameters:
    ///   - zones: current body map, latest assessment per zone.
    ///   - isFlare: current mode from `FlareDetector`.
    static func flags(zones: [ZoneScore], symptoms: RedFlagSymptoms, isFlare: Bool = false) -> [RedFlag] {
        var flags: [RedFlag] = []

        let pustularArea = SeverityCalculator.snapshot(for: zones.filter(\.pustules)).bsa
        if pustularArea >= Threshold.pustularBSA && (symptoms.fever || symptoms.feelsUnwell) {
            flags.append(.widespreadPustules)
        }

        // Redness this widespread is an emergency on its own; chills or peeling only add to it.
        let redArea = SeverityCalculator.snapshot(for: zones.filter { $0.erythema > 0 }).bsa
        if redArea > Threshold.rednessBSA {
            flags.append(.widespreadRedness)
        }

        if symptoms.stoppedSystemicSteroids && isFlare {
            flags.append(.flareAfterSteroidWithdrawal)
        }
        return flags
    }

    static func flags(assessments: [ZoneAssessment], symptoms: RedFlagSymptoms, isFlare: Bool = false) -> [RedFlag] {
        flags(zones: assessments.map(\.score), symptoms: symptoms, isFlare: isFlare)
    }
}
