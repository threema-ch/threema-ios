//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import Foundation
import ThreemaEssentials
import XCTest

@testable import GroupCalls

final class GroupCallViewModelTests: XCTestCase {
    fileprivate var navigationTitle = ""
    
    fileprivate var closed = false
    fileprivate lazy var creatorIdentity = ThreemaIdentity("ECHOECHO")
    fileprivate lazy var groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: creatorIdentity)
    fileprivate lazy var localContactModel = ContactModel(identity: creatorIdentity, nickname: "ECHOECHO")
    fileprivate lazy var groupModel = GroupCallThreemaGroupModel(groupIdentity: groupIdentity, groupName: "TESTGROUP")
    fileprivate lazy var sfuBaseURL = URL(string: "sfu.threema.test")!

    func testBasicInit() async throws {
        let dependencies = MockDependencies().create()
        let groupCallActor = try! GroupCallActor(
            localContactModel: localContactModel,
            groupModel: groupModel,
            sfuBaseURL: sfuBaseURL,
            gck: Data(repeating: 0x01, count: 32),
            dependencies: dependencies
        )
        
        let viewModel = GroupCallViewModel(groupCallActor: groupCallActor)
        
        viewModel.setViewDelegate(self)
        
        await groupCallActor.uiContinuation.yield(.connected)
        
        await Task.yield()
        
        // This isn't great since our tests will either succeed or fail by timing out
        // we never quickly discover that our tests fail. But otherwise we might not wait long enough for the state to
        // converge.
        while navigationTitle != "Connected" {
            await Task.yield()
        }
        
        XCTAssertEqual("Connected", navigationTitle)
    }
    
//    func testBasicAddRemoveParticipant() async throws {
//        let dependencies = MockDependencies().create()
//
//        let gck = Data(repeating: 0x01, count: 32)
//        let groupIdentity = GroupIdentity(id: Data(repeating: 0x00, count: 8), creator: ThreemaIdentity("ECHOECHO"))
//
//        let groupCallActor = try! GroupCallActor(
//            localContactModel: localContactModel,
//            groupModel: groupModel,
//            sfuBaseURL: "",
//            gck: gck,
//            dependencies: dependencies
//        )
//        let groupCallDescription = try GroupCallBaseState(
//            group: groupModel,
//            startedAt: Date(),
//            dependencies: dependencies,
//            groupCallStartData: GroupCallStartData(protocolVersion: 0, gck: gck, sfuBaseURL: "")
//        )
//
//        let viewModel = GroupCallViewModel(groupCallActor: groupCallActor)
//
//        viewModel.setViewDelegate(self)
//        let participantID = ParticipantID(id: 0)
//        let remoteParticipant = await PendingRemoteParticipant(
//            participantID: participantID,
//            dependencies: dependencies,
//            groupCallMessageCrypto: groupCallDescription,
//            isExistingParticipant: false
//        )
//
//        let viewModelParticipant = await ViewModelParticipant(
//            remoteParticipant: remoteParticipant,
//            name: "ECHOECHO",
//            idColor: .red
//        )
//
//        await groupCallActor.uiContinuation
//            .yield(.add(viewModelParticipant))
//
//        while viewModel.snapshotPublisher.numberOfItems != 1 {
//            await Task.yield()
//            try! await Task.sleep(nanoseconds: 1_000_000_000)
//        }
//
//        XCTAssertEqual(viewModel.snapshotPublisher.numberOfItems, 1)
//
//        await groupCallActor.uiContinuation.yield(.remove(ParticipantID(id: 1)))
//        await groupCallActor.uiContinuation.yield(.remove(ParticipantID(id: 1)))
//
//        await Task.yield()
//        try! await Task.sleep(nanoseconds: 1_000_000_000)
//
//        XCTAssertEqual(viewModel.snapshotPublisher.numberOfItems, 1)
//
//        await groupCallActor.uiContinuation.yield(.remove(participantID))
//
//        await Task.yield()
//        try! await Task.sleep(nanoseconds: 1_000_000_000)
//
//        XCTAssertEqual(viewModel.snapshotPublisher.numberOfItems, 0)
//    }
}

// MARK: - GroupCallViewModelDelegate

extension GroupCallViewModelTests: GroupCallViewModelDelegate {
    func showRecordAudioPermissionAlert() { }
    
    func showRecordVideoPermissionAlert() { }
    
    func updateCollectionViewLayout() { }
    
    func dismissGroupCallView(animated: Bool) async {
        closed = true
    }
    
    func updateNavigationContent(_ contentUpdate: GroupCalls.GroupCallNavigationBarContentUpdate) async { }
}
