import Foundation

/// Our website (myskin.cc): legal pages, support and the remote config file.
/// Every address the app opens or fetches lives here.
nonisolated enum AppLinks {
    static let website = page("")
    static let privacy = page("privacy/")
    static let terms = page("terms/")
    static let support = page("support/")
    static let healthDataPrivacy = page("health-data-privacy/")
    /// Static JSON read by `RemoteConfigStore` (C14).
    static let remoteConfig = page("config.json")

    static let supportEmail = "support@myskin.cc"
    /// Opens Mail with the support address and a subject — nothing about the diary.
    static let contactSupport = URL(string: "mailto:\(supportEmail)?subject=MySkin%20support")

    private static func page(_ path: String) -> URL? {
        URL(string: "https://myskin.cc/" + path)
    }
}
