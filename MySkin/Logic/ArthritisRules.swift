import Foundation

/// Psoriatic arthritis: what the user told us in onboarding plus the PEST screening.
enum ArthritisRules {
    /// Known or suspected arthritis raises the severity category like a special site.
    static func isSuspected(status: ArthritisStatus?, pestScore: Int?) -> Bool {
        switch status {
        case .diagnosed, .suspected: true
        default: pestScore.map(PEST.suggestsRheumatologist) ?? false
        }
    }

    /// PEST is a screening test; it isn't needed once a doctor has diagnosed arthritis.
    static func needsPEST(_ status: ArthritisStatus?) -> Bool {
        status != .diagnosed
    }

    /// Line for the doctor's report; nil when the user didn't answer.
    static func reportText(_ status: ArthritisStatus?) -> String? {
        switch status {
        case .diagnosed: "Psoriatic arthritis: diagnosed"
        case .suspected: "Psoriatic arthritis: suspected by the patient"
        case .no: "Psoriatic arthritis: none known"
        case .unsure: "Psoriatic arthritis: not sure"
        case nil: nil
        }
    }
}
