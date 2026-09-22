import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class CallHistoryManagerTests: XCTestCase {
    private var databaseMainCnx: DatabaseContextProtocol!
    private var databaseBackgroundCnx: DatabaseContextProtocol!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let testDatabase = TestDatabase()
        databaseMainCnx = testDatabase.context
        databaseBackgroundCnx = testDatabase.backgroundContext
    }

    func testInsertAndRead() async throws {
        
        // Setup mocks
        let userSettingsMock = UserSettingsMock()

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx, isRemoteSecretEnabled: false),
            userSettings: userSettingsMock
        )
        
        businessInjectorMock.entityManager.performAndWaitSave {
            _ = businessInjectorMock.entityManager.entityCreator.contactEntity(
                identity: "ECHOECHO",
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let manager = CallHistoryManager(identity: "ECHOECHO", businessInjector: businessInjectorMock)
        
        var callIDs = [VoIPCallID]()
        
        for _ in 0..<10 {
            let callID = VoIPCallID.generate()
            let date = Date()
            callIDs.append(callID)
            
            await manager.store(callID: callID, date: date)
        }
        
        for callID in callIDs {
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertFalse(isMissedCall)
        }
        
        for _ in 0..<10 {
            let callID = VoIPCallID.generate()
            let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
            XCTAssertEqual(!callIDs.contains(callID), isMissedCall)
        }
    }
    
    func testDelete() async throws {
        
        // Setup mocks
        let userSettingsMock = UserSettingsMock()

        let businessInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx, isRemoteSecretEnabled: false),
            userSettings: userSettingsMock
        )
        
        businessInjectorMock.entityManager.performAndWaitSave {
            _ = businessInjectorMock.entityManager.entityCreator.contactEntity(
                identity: "ECHOECHO",
                publicKey: BytesUtility.generatePublicKey(),
                sortOrderFirstName: true
            )
        }
        
        let manager = CallHistoryManager(identity: "ECHOECHO", businessInjector: businessInjectorMock)
        
        var callIDs = [VoIPCallID]()
        var deletedCallIDs = [VoIPCallID]()
        
        for i in 0..<10 {
            let callID = VoIPCallID(callID: UInt32(i))
            let date = Date()
            callIDs.append(callID)
            
            await manager.store(callID: callID, date: date)
        }
        
        for i in 11..<20 {
            let callID = VoIPCallID(callID: UInt32(i))
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
        
        let callID = VoIPCallID(callID: UInt32(21))
        let isMissedCall = await manager.isMissedCall(from: "ECHOECHO", callID: callID)
        XCTAssertTrue(isMissedCall)
    }
}
