import Testing
@testable import ThreemaFramework

struct ThreemaFrameworkBundleTests {
    // MARK: - Private properties

    @Test("Bundle info dictionary keys are correctly defined")
    func infoDictionaryKeys() async throws {
        #expect(
            BundleUtil
                .object(forThreemaFrameworkConfigurationKey: "ThreemaWebURL") as? String == "https://web.threema.ch/"
        )
        
        #expect(
            BundleUtil
                .object(forThreemaFrameworkConfigurationKey: "ThreemaWorkServerNamePrefix") as? String == "w-"
        )
        
        #expect(
            BundleUtil
                .object(forThreemaFrameworkConfigurationKey: "ThreemaWorkServerNamePrefixv6") as? String == "ds.w-"
        )
    }
}
