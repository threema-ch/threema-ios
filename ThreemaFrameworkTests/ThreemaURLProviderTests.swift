import Foundation
import Testing

@testable import ThreemaFramework

@Suite("Threema URL Provider Tests")
struct ThreemaURLProviderTests {

    @Test(
        "Private support page is in German",
        arguments: ["de", "de-CH", "de-AT", "gsw-CH", "rm", "rm-CH"]
    )
    func germanPrivateSupport(languageTag: String) {
        #expect(
            ThreemaURLProvider.privateSupport(for: languageTag) ==
                URL(string: "https://threema.com/de/support/private")!
        )
    }

    @Test(
        "Private support page is in French",
        arguments: ["fr", "fr-CH", "fr-BE", "fr-CA"]
    )
    func frenchPrivateSupport(languageTag: String) {
        #expect(
            ThreemaURLProvider.privateSupport(for: languageTag) ==
                URL(string: "https://threema.com/fr/support/private")!
        )
    }

    @Test(
        "Private support page is in Spanish",
        arguments: ["es", "es-MX", "ca", "ca-ES", "gl"]
    )
    func spanishPrivateSupport(languageTag: String) {
        #expect(
            ThreemaURLProvider.privateSupport(for: languageTag) ==
                URL(string: "https://threema.com/es/support/private")!
        )
    }

    @Test(
        "Private support page falls back to English",
        arguments: [
            "en",
            "en-GB",
            "bg",
            "cs",
            "it",
            "ja",
            "ko",
            "nl",
            "pl",
            "pt-BR",
            "ru",
            "sk",
            "tr",
            "uk",
            "zh-Hans",
            "zh-Hant",
            "",
        ]
    )
    func englishPrivateSupport(languageTag: String) {
        #expect(
            ThreemaURLProvider.privateSupport(for: languageTag) ==
                URL(string: "https://threema.com/en/support/private")!
        )
    }

    @Test("Private support page falls back to English without a language")
    func missingLanguagePrivateSupport() {
        #expect(
            ThreemaURLProvider.privateSupport(for: nil) ==
                URL(string: "https://threema.com/en/support/private")!
        )
    }
}
