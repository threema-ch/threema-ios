//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BusinessInjectorTests: XCTestCase {
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    private var backgroundEntityManager: EntityManager!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: backgroundCnx!)

        backgroundEntityManager =
            EntityManager(databaseContext: DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx))
    }

    func testRunOnBackground() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        dbPreparer.save {
            dbPreparer.createContact(identity: expectedThreemaIdentity.string)
        }

        let businessInjector = BusinessInjector(entityManager: backgroundEntityManager)

        let result: ThreemaIdentity? = await businessInjector.runInBackground { backgroundBusinessInjector in
            await backgroundBusinessInjector.entityManager.perform {
                guard !Thread.isMainThread else {
                    XCTFail("Closure should't running on main thread")
                    return nil
                }
                return backgroundBusinessInjector.entityManager.entityFetcher
                    .contact(for: expectedThreemaIdentity.string).threemaIdentity
            }
        }

        XCTAssertEqual(expectedThreemaIdentity, result)
    }

    func testRunOnBackgroundAndWait() throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        dbPreparer.save {
            dbPreparer.createContact(identity: expectedThreemaIdentity.string)
        }

        let expect = expectation(description: "BusinessInjector.runOnBackgroundAndWait")

        DispatchQueue.global().async {
            let businessInjector = BusinessInjector(entityManager: self.backgroundEntityManager)

            var result: ThreemaIdentity? = businessInjector
                .runInBackgroundAndWait { backgroundBusinessInjector in
                    backgroundBusinessInjector.entityManager.performAndWait {
                        guard !Thread.isMainThread else {
                            XCTFail("Closure should't running on main thread")
                            return nil
                        }
                        return backgroundBusinessInjector.entityManager.entityFetcher
                            .contact(for: expectedThreemaIdentity.string).threemaIdentity
                    }
                }

            XCTAssertEqual(expectedThreemaIdentity, result)

            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)
    }
}
