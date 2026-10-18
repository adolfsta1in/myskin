import Foundation

/// Our website (myskin.cc): legal pages, support, the remote config file and usage counts.
/// Every address the app opens or fetches lives here.
nonisolated enum AppLinks {
    static let website = page("")
    static let privacy = page("privacy/")
    static let terms = page("terms/")
    static let support = page("support/")
    static let healthDataPrivacy = page("health-data-privacy/")
    /// Static JSON read by `RemoteConfigStore` (C14).
    static let remoteConfig = page("config.json")
    /// Anonymous usage counts sent by `UsageStats` (step 63).
    static let usageStats = page("v1/usage")

    static let supportEmail = "support@myskin.cc"
    /// Opens Mail with the support address and a subject — nothing about the diary.
    static let contactSupport = URL(string: "mailto:\(supportEmail)?subject=Velvi%20support")

    private static func page(_ path: String) -> URL? {
        URL(string: "https://myskin.cc/" + path)
    }
}
