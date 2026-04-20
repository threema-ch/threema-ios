import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

final class BusinessInjectorTests: XCTestCase {
    private var dbPreparer: TestDatabasePreparer!
    private var backgroundEntityManager: EntityManager!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer

        backgroundEntityManager = testDatabase.backgroundEntityManager

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)
    }

    func testRunOnBackground() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        dbPreparer.save {
            dbPreparer.createContact(identity: expectedThreemaIdentity.rawValue)
        }

        let businessInjector = BusinessInjector(entityManager: backgroundEntityManager)

        let result: ThreemaIdentity? = await businessInjector.runInBackground { backgroundBusinessInjector in
            await backgroundBusinessInjector.entityManager.perform {
                guard !Thread.isMainThread else {
                    XCTFail("Closure should't running on main thread")
                    return nil
                }
                return backgroundBusinessInjector.entityManager.entityFetcher
                    .contactEntity(for: expectedThreemaIdentity.rawValue)?.threemaIdentity
            }
        }

        XCTAssertEqual(expectedThreemaIdentity, result)
    }

    func testRunOnBackgroundAndWait() throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        dbPreparer.save {
            dbPreparer.createContact(identity: expectedThreemaIdentity.rawValue)
        }

        let expect = expectation(description: "BusinessInjector.runOnBackgroundAndWait")

        DispatchQueue.global().async {
            let businessInjector = BusinessInjector(entityManager: self.backgroundEntityManager)

            let result: ThreemaIdentity? = businessInjector
                .runInBackgroundAndWait { backgroundBusinessInjector in
                    backgroundBusinessInjector.entityManager.performAndWait {
                        guard !Thread.isMainThread else {
                            XCTFail("Closure should't running on main thread")
                            return nil
                        }
                        return backgroundBusinessInjector.entityManager.entityFetcher
                            .contactEntity(for: expectedThreemaIdentity.rawValue)?.threemaIdentity
                    }
                }

            XCTAssertEqual(expectedThreemaIdentity, result)

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)
    }
}
