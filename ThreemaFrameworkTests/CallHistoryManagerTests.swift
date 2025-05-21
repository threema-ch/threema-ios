//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class CallHistoryManagerTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInsertAndRead() async throws {
        
        // Setup mocks
        let userSettingsMock = UserSettingsMock()

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: userSettingsMock
        )
        
        businessInjectorMock.entityManager.performSyncBlockAndSafe {
            let contact = businessInjectorMock.entityManager.entityCreator.contact()
            contact?.setIdentity(to: "ECHOECHO")
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let manager = CallHistoryManager(identity: "ECHOECHO", businessInjector: businessInjectorMock)
        
        var callIDs = [UInt32]()
        
        for _ in 0..<10 {
            let callID = UInt32.random(in: UInt32.min..<UInt32.max)
            let date = Date()
            callIDs.append(callID)
            
            await manager.store(callID: callID, date: date)
        }
        
        for callID in callIDs {
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertFalse(isMissedCall)
        }
        
        for _ in 0..<10 {
            let callID = UInt32.random(in: UInt32.min..<UInt32.max)
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertEqual(!callIDs.contains(callID), isMissedCall)
        }
    }
    
    func testDelete() async throws {
        
        // Setup mocks
        let userSettingsMock = UserSettingsMock()

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: userSettingsMock
        )
        
        businessInjectorMock.entityManager.performSyncBlockAndSafe {
            let contact = businessInjectorMock.entityManager.entityCreator.contact()
            contact?.setIdentity(to: "ECHOECHO")
            contact?.publicKey = MockData.generatePublicKey()
        }
        
        let manager = CallHistoryManager(identity: "ECHOECHO", businessInjector: businessInjectorMock)
        
        var callIDs = [UInt32]()
        var deletedCallIDs = [UInt32]()
        
        for i in 0..<10 {
            let callID = UInt32(i)
            let date = Date()
            callIDs.append(callID)
            
            await manager.store(callID: callID, date: date)
        }
        
        for i in 11..<20 {
            let callID = UInt32(i)
            let date = Calendar.current.date(byAdding: .day, value: -(14 + i), to: Date())!
            deletedCallIDs.append(callID)
            
            await manager.store(callID: callID, date: date)
        }
        
        for callID in callIDs {
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertFalse(isMissedCall)
        }
        
        for callID in deletedCallIDs {
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertTrue(isMissedCall)
        }
        
        let callID = UInt32(21)
        let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
        XCTAssertTrue(isMissedCall)
    }
}
