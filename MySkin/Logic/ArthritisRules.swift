import Foundation

/// Psoriatic arthritis: what the user told us in onboarding plus the joint check.
enum ArthritisRules {
    /// Known or suspected arthritis, or joint symptoms in the latest joint check,
    /// raise the severity category like a special site.
    static func isSuspected(status: ArthritisStatus?, jointSymptomsNoted: Bool) -> Bool {
        switch status {
        case .diagnosed, .suspected: true
        default: jointSymptomsNoted
        }
    }

    /// The joint check isn't needed once a doctor has diagnosed arthritis.
    static func needsJointCheck(_ status: ArthritisStatus?) -> Bool {
        status != .diagnosed
    }

    /// Line for the doctor's report; nil when the user didn't answer.
    static func reportText(_ status: ArthritisStatus?) -> String? {
        switch status {
        case .diagnosed: String(localized: "Psoriatic arthritis: diagnosed")
        case .suspected: String(localized: "Psoriatic arthritis: suspected by the patient")
        case .no: String(localized: "Psoriatic arthritis: none known")
        case .unsure: String(localized: "Psoriatic arthritis: not sure")
        case nil: nil
        }
    }
}
