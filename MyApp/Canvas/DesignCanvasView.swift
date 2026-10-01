#if DEBUG
import SwiftData
import SwiftUI

/// All screens laid out on one canvas: onboarding row on top, main app row below.
/// Debug-only design tool — not shipped in release builds.
struct DesignCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 0.3

    private static let phoneSize = CGSize(width: 393, height: 852)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("MySkin · Design canvas")
                    .font(.rounded(.headline, weight: .semibold))
                Spacer()
                Image(systemName: "minus.magnifyingglass")
                Slider(value: $scale, in: 0.2...1)
                    .frame(width: 140)
                Image(systemName: "plus.magnifyingglass")
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }
            .foregroundStyle(Theme.ink)
            .padding(14)

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 48 * scale + 20) {
                    row(title: "Onboarding") {
                        ForEach(OnboardingStep.allCases) { step in
                            phone(step.label) {
                                OnboardingFlow(startAt: step)
                                    .modelContainer(PreviewData.emptyContainer())
                            }
                        }
                    }
                    row(title: "Main app") {
                        phone("1 · Today · Calm") { MainTabView(selection: .today) }
                        phone("1 · Today · Flare") { MainTabView(selection: .today).modelContainer(PreviewData.flareContainer) }
                        phone("2 · Body map") { MainTabView(selection: .body) }
                        phone("Photos") { MainTabView(selection: .photos) }
                        phone("4 · Zone progress") {
                            NavigationStack { ZoneProgressView(zoneID: "back.elbow.left") }
                        }
                        phone("5 · Treatment") { MainTabView(selection: .treatment) }
                        phone("6 · Insights") { MainTabView(selection: .insights) }
                        phone("7 · Doctor report") {
                            NavigationStack { DoctorReportView() }
                        }
                        phone("Questionnaires") {
                            NavigationStack { QuestionnaireHistoryView() }
                        }
                        phone("DLQI") { QuestionnaireView(kind: .dlqi) }
                        phone("Red flag") { RedFlagView(flags: [.widespreadPustules]) }
                        phone("Settings") { SettingsView() }
                        phone("Privacy lock") { PrivacyLockView() }
                    }
                }
                .padding(32)
            }
            .background(Color(hex: 0xE4DED2))
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .environment(PreviewData.settings)
        .environment(AppLock(isLocked: true))
        .modelContainer(PreviewData.container)
    }

    private func row<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 44 * scale + 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            // Lazy so off-screen phones aren't built until scrolled into view.
            LazyHStack(alignment: .top, spacing: 60 * scale + 12) {
                content()
            }
        }
    }

    /// A phone-sized frame rendered at full size, then scaled down to fit the canvas.
    private func phone<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        let size = Self.phoneSize
        return VStack(spacing: 10) {
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 55, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 55, style: .continuous)
                        .stroke(Color(hex: 0x2B2A26), lineWidth: 10)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
            Text(label)
                .font(.rounded(.caption, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

#Preview("Design Canvas") {
    DesignCanvasView()
}
#endif
