import Foundation
import Testing
@testable import MySkin

struct AppLinksTests {
    @Test func pagesAreHttpsOnOurSiteWithoutQuery() throws {
        let pages = [AppLinks.website, AppLinks.privacy, AppLinks.terms, AppLinks.support,
                     AppLinks.healthDataPrivacy, AppLinks.remoteConfig]
        for page in pages {
            let url = try #require(page)
            #expect(url.scheme == "https")
            #expect(url.host() == "myskin.cc")
            #expect(url.query() == nil)
            #expect(url.fragment() == nil)
        }
        #expect(AppLinks.privacy?.absoluteString == "https://myskin.cc/privacy/")
        #expect(AppLinks.remoteConfig?.absoluteString == "https://myskin.cc/config.json")
    }

    @Test func remoteConfigFetchesFromOurSite() {
        #expect(RemoteConfigStore.endpoint == AppLinks.remoteConfig)
    }

    @Test func contactSupportIsAMailtoWithoutDiaryData() throws {
        let url = try #require(AppLinks.contactSupport)
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString == "mailto:support@myskin.cc?subject=MySkin%20support")
    }
}
