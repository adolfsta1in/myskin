#if DEBUG
import Foundation
import SwiftData

/// Debug builds only: App Store screenshots. `-screenshots` opens the app on the sample diary
/// (`PreviewData`), past onboarding and the paywall, without touching the real diary.
/// `-screenshotTab body|treatment|insights|report|paywall` picks the screen, `-screenshotFlare` uses the Flare sample,
/// `-screenshotBack` turns the body map around.
enum ScreenshotMode {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isOn: Bool { arguments.contains("-screenshots") }

    static var container: ModelContainer {
        arguments.contains("-screenshotFlare") ? PreviewData.flareContainer : PreviewData.container
    }

    private static var screen: String? {
        guard let index = arguments.firstIndex(of: "-screenshotTab"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// `-screenshotBack`: the body map opens on the back view.
    static var bodySide: BodySide { isOn && arguments.contains("-screenshotBack") ? .back : .front }

    /// Keeps today's saved check-in open instead of folding it.
    static var expandsCheckIn: Bool { isOn && !arguments.contains("-screenshotFlare") }

    static var showsReport: Bool { isOn && screen == "report" }

    /// `-screenshotTab paywall`: the paywall with sample US prices (no StoreKit in a plain simulator launch).
    static var showsPaywall: Bool { isOn && screen == "paywall" }

    static var tab: AppTab {
        guard isOn else { return .today }
        switch screen {
        case "body": return .body
        case "photos": return .photos
        case "treatment": return .treatment
        case "insights": return .insights
        default: return .today
        }
    }
}
#endif
