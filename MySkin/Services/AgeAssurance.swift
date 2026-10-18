import DeclaredAgeRange
import Observation
import SwiftUI

/// Runs the age check once per launch, only where the law requires it (see `AgeGate`).
@Observable
final class AgeAssurance {
    private(set) var status: AgeGate.Status = .unknown
    @ObservationIgnored private var hasChecked = false

    var isBlocked: Bool { AgeGate.isBlocked(status) }

    func check(using requestAgeRange: sending DeclaredAgeRangeAction) async {
        guard !hasChecked else { return }
        hasChecked = true
        let isRequired = await Self.isAgeAssuranceRequired()
        guard isRequired == true else {
            status = AgeGate.status(isRequired: isRequired, answer: nil)
            return
        }
        let answer: AgeGate.Answer
        do {
            switch try await requestAgeRange(ageGates: AgeGate.minimumAge) {
            case .sharing(let range): answer = .sharing(lowerBound: range.lowerBound)
            case .declinedSharing: answer = .declined
            @unknown default: answer = .failed
            }
        } catch {
            answer = .failed
        }
        status = AgeGate.status(isRequired: true, answer: answer)
    }

    /// Nil when it can't be told (older iOS, no Apple Account, error).
    @concurrent
    private static func isAgeAssuranceRequired() async -> Bool? {
        guard #available(iOS 26.2, *) else { return nil }
        return try? await AgeRangeService.shared.isEligibleForAgeFeatures
    }
}

/// Shown instead of the app to someone declared under 16. Safety information stays reachable.
struct AgeRestrictedView: View {
    @State private var showsSafety = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Velvi is for people \(AgeGate.minimumAge) and older")
                .font(.rounded(.title2, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Your Apple Account says you're younger than \(AgeGate.minimumAge). If you have psoriasis, a parent or your doctor can help you keep track of it.")
                .font(.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Urgent symptoms?") { showsSafety = true }
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("If your age is wrong, update it in Settings › [your name] › Personal Information.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 24)
        .screenScaffold()
        .fullScreenCover(isPresented: $showsSafety) {
            RedFlagView(flags: RedFlag.allCases)
        }
    }
}

#Preview("Age restricted") {
    AgeRestrictedView()
        .previewSetup()
}
