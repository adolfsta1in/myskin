import SwiftUI

/// Full-screen warning for red flags (spec §2.8). Always shown when a flag fires — no setting hides it.
struct RedFlagView: View {
    let flags: [RedFlag]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let number = EmergencyNumber.current

    var body: some View {
        ZStack {
            WarmBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.intensitySevere)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .accessibilityHidden(true)
                    Text("Seek medical care now")
                        .font(.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(flags) { flag in
                            Label(flag.message, systemImage: "exclamationmark.circle")
                                .font(.rounded(.body, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .glassCard(tint: Theme.intensityModerate)

                    Text("MySkin is a diary and can't assess you. If you feel very unwell, call emergency services or go to the nearest emergency department.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    PrimaryButton(title: "Call \(number)", systemImage: "phone.fill") {
                        if let url = EmergencyNumber.url(number) { openURL(url) }
                    }
                    SecondaryButton(title: "Find emergency care nearby") {
                        if let url = URL(string: "maps://?q=emergency%20room") { openURL(url) }
                    }
                    Button("I understand") { dismiss() }
                        .font(.rounded(.headline, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
        .fontDesign(.rounded)
    }
}

#Preview {
    RedFlagView(flags: [.widespreadPustules])
        .previewSetup()
}
