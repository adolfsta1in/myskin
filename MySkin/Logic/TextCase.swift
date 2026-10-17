import Foundation

extension String {
    /// A label placed inside a sentence («· mild», «after dairy»): lowercased, except in German,
    /// where nouns keep their capital.
    nonisolated var inSentence: String {
        Bundle.main.preferredLocalizations.first == "de" ? self : lowercased()
    }
}
