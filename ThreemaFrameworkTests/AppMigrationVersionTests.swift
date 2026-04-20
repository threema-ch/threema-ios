import XCTest
@testable import ThreemaFramework

final class AppMigrationVersionTests: XCTestCase {

    func testIsAppMigrationRequiredTrue() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.appMigratedToVersion = AppMigrationVersion.none.rawValue

        XCTAssertTrue(AppMigrationVersion.isMigrationRequired(userSettings: userSettingsMock))
    }

    func testIsAppMigrationRequiredFalse() throws {
        let userSettingsMock = UserSettingsMock()
        let latestMigrationVersion = try XCTUnwrap(AppMigrationVersion.allCases.last)
        userSettingsMock.appMigratedToVersion = latestMigrationVersion.rawValue

        XCTAssertFalse(AppMigrationVersion.isMigrationRequired(userSettings: userSettingsMock))
    }

    func testLatestVersion() throws {
        XCTAssertEqual(AppMigrationVersion.latestVersion, .v7_1)
    }
}
