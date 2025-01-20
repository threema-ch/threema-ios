//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
@testable import ThreemaProtocols

class FeatureMaskTests: XCTestCase {
    private var deviceGroupKeys: DeviceGroupKeys!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        deviceGroupKeys = MockData.deviceGroupKeys
    }

    override func tearDownWithError() throws { }

    func testCurrentFeatureMask0() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().build()

        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue == 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue == 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue == 0)
    }

    func testCurrentFeatureMask1() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: true)
            .groupCalls(enabled: true)
            .editMessage(enabled: true)
            .build()

        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue != 0)
    }

    func testCurrentFeatureMask2() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: false)
            .groupCalls(enabled: true)
            .editMessage(enabled: true)
            .build()

        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue == 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue != 0)
    }

    func testFeatureMaskRawValue() {
        for flag in ThreemaProtocols.Common_CspFeatureMaskFlag.allCases {
            switch flag {
            case .reactionSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.reactionSupport.rawValue,
                    Int(FEATURE_MASK_REACTION)
                )
            case .deleteMessageSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.deleteMessageSupport.rawValue,
                    Int(FEATURE_MASK_DELETE_MESSAGE)
                )
            case .editMessageSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue,
                    Int(FEATURE_MASK_EDIT_MESSAGE)
                )
            case .fileMessageSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue,
                    Int(FEATURE_MASK_FILE_TRANSFER)
                )
            case .forwardSecuritySupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue,
                    Int(FEATURE_MASK_FORWARD_SECURITY)
                )
            case .groupCallSupport:
                break
            case .groupSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue,
                    Int(FEATURE_MASK_GROUP_CHAT)
                )
            case .none:
                break
            case .o2OAudioCallSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue,
                    Int(FEATURE_MASK_VOIP)
                )
            case .o2OVideoCallSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue,
                    Int(FEATURE_MASK_VOIP_VIDEO)
                )
            case .pollSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue,
                    Int(FEATURE_MASK_BALLOT)
                )
            case .voiceMessageSupport:
                XCTAssertEqual(
                    ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue,
                    Int(FEATURE_MASK_AUDIO_MSG)
                )
            case .UNRECOGNIZED:
                break
            }
        }
    }

    func testCheckMessage() {
        let tests: [(members: [(identity: String, mask: Int)], isSupported: Bool, unsupported: [String])] = [
            ([("MEMBER01", 0), ("MEMBER02", 0)], false, ["MEMBER01", "MEMBER02"]),
            ([("MEMBER01", Int(FEATURE_MASK_EDIT_MESSAGE)), ("MEMBER02", 0)], true, ["MEMBER02"]),
            (
                [("MEMBER01", Int(FEATURE_MASK_EDIT_MESSAGE)), ("MEMBER02", Int(FEATURE_MASK_EDIT_MESSAGE))],
                true,
                [String]()
            ),
        ]

        for test in tests {
            let dbPreparer = DatabasePreparer(
                context: DatabasePersistentContext.devNullContext().mainContext
            )

            let myIdentityStoreMock = MyIdentityStoreMock()

            let message = dbPreparer.save {
                var members = [ContactEntity]()
                for member in test.members {
                    members.append(
                        dbPreparer.createContact(identity: member.identity, featureMask: member.mask)
                    )
                }

                let group = dbPreparer.createGroupEntity(
                    groupID: MockData.generateGroupID(),
                    groupCreator: myIdentityStoreMock.identity
                )
                let conversation = dbPreparer.createConversation()
                // swiftformat:disable:next acronyms
                conversation.groupId = group.groupId
                conversation.members = Set(members)

                let message = dbPreparer.createTextMessage(
                    conversation: conversation,
                    isOwn: true,
                    sender: nil,
                    remoteSentDate: nil
                )
                return message
            }

            let result = FeatureMask.check(message: message, for: .editMessageSupport)

            XCTAssertEqual(test.isSupported, result.isSupported)
            XCTAssertEqual(test.unsupported.count, result.unsupported.count)
            for identity in test.unsupported {
                XCTAssertTrue(
                    result.unsupported.map(\.identity.string).contains(identity)
                )
            }
        }
    }
}
