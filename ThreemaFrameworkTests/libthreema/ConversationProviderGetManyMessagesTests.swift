import Foundation
import libthreemaSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@Suite("Test libthreema ConversationProvider.GetManyMessages")
struct ConversationProviderGetManyMessagesTests {

    @Test func `getManyMessages not supported yet`() async throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: "ECHOECHO")
            let conversation = testDatabase.preparer.createConversation(contactEntity: contact)
            testDatabase.preparer.createAudioMessageEntity(conversation: conversation, duration: 1, complete: nil)
            testDatabase.preparer.createFileMessageEntity(conversation: conversation)
            testDatabase.preparer.createImageMessageEntity(
                conversation: conversation,
                image: nil,
                thumbnail: nil,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            testDatabase.preparer.createVideoMessageEntity(
                conversation: conversation,
                video: nil,
                duration: 1,
                thumbnail: nil,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }

        let ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .contact, batchIndex: 0)

        #expect(messages.isEmpty)
        #expect(ddLoggerMock.exists(message: "Audio message in data backup is not supported yet"))
        #expect(ddLoggerMock.exists(message: "File message in data backup is not supported yet"))
        #expect(ddLoggerMock.exists(message: "Image message in data backup is not supported yet"))
        #expect(ddLoggerMock.exists(message: "Video message in data backup is not supported yet"))

        DDLog.removeAllLoggers()
    }

    @Test func `getManyMessages deleted messages`() async throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let (deletedTextMessage, deletedLocationMessage) = testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: "ECHOECHO")
            let conversation = testDatabase.preparer.createConversation(contactEntity: contact)
            let textMessage = testDatabase.preparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: Date(),
            )
            textMessage.deletedAt = Date()

            let locationMessage = testDatabase.preparer.createLocationMessage(
                conversation: conversation,
                accuracy: 0,
                latitude: 0,
                longitude: 0,
                poiName: nil,
                isOwn: false
            )
            locationMessage.deletedAt = Date()

            return (textMessage, locationMessage)
        }

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .contact, batchIndex: 0)

        #expect(messages.count == 2)

        for message in messages {
            switch message.body {
            case let .deleted(deletedMessageState):
                switch deletedMessageState.previousMessageType {
                case .text:
                    #expect(deletedMessageState.deletedAt == deletedTextMessage.deletedAt?.millisecondsSince1970)
                case .location:
                    #expect(deletedMessageState.deletedAt == deletedLocationMessage.deletedAt?.millisecondsSince1970)
                default:
                    Issue.record("Wrong previous message type")
                }
            default:
                Issue.record("Wrong message type")
            }
        }
    }

    @Test func `getManyMessages outgoing one to one messages`() async throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedIdentity = "ECHOECHO"

        let expectedTextMessageText = "Test 123"
        let expectedTextMessageReaction = "👌"
        let expectedTextMessageHistoryEntryEditDate = Date()
        let expectedTextMessageHistoryEntryText = "Test 123 revision"

        let expectedBallotID = BytesUtility.generateBallotID()

        let expectedLongitude = 47.029926
        let expectedLatiude = 8.688774
        let expectedPoiName = "Gross Mythen"

        let (expectedTextMessage, expectedBallotMessage, expectedLocationMessage) = testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: expectedIdentity)
            let conversation = testDatabase.preparer.createConversation(contactEntity: contact)
            let textMessage = testDatabase.preparer.createTextMessage(
                conversation: conversation,
                text: expectedTextMessageText,
                isOwn: true,
                sender: nil,
                remoteSentDate: Date(),
            )
            testDatabase.preparer.createMessageReactionEntity(
                message: textMessage,
                reaction: expectedTextMessageReaction,
                contact: contact
            )
            testDatabase.preparer.createMessageHisoryEntry(
                message: textMessage,
                editDate: expectedTextMessageHistoryEntryEditDate,
                text: expectedTextMessageHistoryEntryText
            )

            let ballot = testDatabase.preparer.createBallot(conversation: conversation, ballotID: expectedBallotID)
            let ballotMessage = testDatabase.preparer.createBallotMessage(
                conversation: conversation,
                ballot: ballot,
                isOwn: true
            )

            let locationMessage = testDatabase.preparer.createLocationMessage(
                conversation: conversation,
                accuracy: 0,
                latitude: expectedLatiude,
                longitude: expectedLongitude,
                poiName: expectedPoiName,
                isOwn: true
            )

            return (textMessage, ballotMessage, locationMessage)
        }

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .contact, batchIndex: 0)

        #expect(messages.count == 3)

        for message in messages {
            switch message.body {
            case let .text(textMessageState):
                let expectedMessageID: UInt64 = try expectedTextMessage.id.littleEndian()
                // swiftformat:disable:next acronyms
                #expect(message.messageId == expectedMessageID)
                #expect(try message.createdAt == #require(expectedTextMessage.date).millisecondsSince1970)
                #expect(message.creatorIdentity == myIdentityStoreMock.identity)
                #expect(
                    // swiftformat:disable:next acronyms
                    try message.conversationId == .contact(#require(expectedTextMessage.conversation.contact).identity)
                )
                #expect(message.direction == .outgoing(
                    OutgoingMessageDirection(
                        sentAt: expectedTextMessage.remoteSentDate?.millisecondsSince1970,
                        deliveredAt: expectedTextMessage.deliveryDate?.millisecondsSince1970
                    )
                ))
                #expect(message.reactions.first?.creatorIdentity == expectedIdentity)
                #expect(message.reactions.first?.emoji.codepoint == expectedTextMessageReaction)

                #expect(textMessageState.original.text == expectedTextMessageText)
                #expect(textMessageState.revisions.count == 1)
                let revision = try #require(textMessageState.revisions.first)
                #expect(revision.createdAt == expectedTextMessageHistoryEntryEditDate.millisecondsSince1970)
                #expect(revision.message.text == expectedTextMessageHistoryEntryText)
            case let .pollOpen(pollOpen):
                let expectedMessageID: UInt64 = try expectedBallotMessage.id.littleEndian()
                // swiftformat:disable:next acronyms
                #expect(message.messageId == expectedMessageID)
                #expect(try message.createdAt == #require(expectedBallotMessage.date).millisecondsSince1970)
                #expect(message.creatorIdentity == myIdentityStoreMock.identity)
                #expect(
                    // swiftformat:disable:next acronyms
                    try message.conversationId == .contact(#require(expectedBallotMessage.conversation.contact).identity)
                )
                #expect(message.direction == .outgoing(
                    OutgoingMessageDirection(
                        sentAt: expectedBallotMessage.remoteSentDate?.millisecondsSince1970,
                        deliveredAt: expectedBallotMessage.deliveryDate?.millisecondsSince1970
                    )
                ))
                #expect(message.reactions.isEmpty)

                try #expect(pollOpen.id == expectedBallotID.littleEndian())
            case let .location(locationMessageState):
                let expectedMessageID: UInt64 = try expectedLocationMessage.id.littleEndian()
                // swiftformat:disable:next acronyms
                #expect(message.messageId == expectedMessageID)
                #expect(try message.createdAt == #require(expectedLocationMessage.date).millisecondsSince1970)
                #expect(message.creatorIdentity == myIdentityStoreMock.identity)
                #expect(
                    // swiftformat:disable:next acronyms
                    try message.conversationId == .contact(
                        #require(expectedLocationMessage.conversation.contact).identity
                    )
                )
                #expect(message.direction == .outgoing(
                    OutgoingMessageDirection(
                        sentAt: expectedLocationMessage.remoteSentDate?.millisecondsSince1970,
                        deliveredAt: expectedLocationMessage.deliveryDate?.millisecondsSince1970
                    )
                ))

                #expect(locationMessageState.accuracyM == 0)
                #expect(locationMessageState.latitude == expectedLatiude)
                #expect(locationMessageState.longitude == expectedLongitude)
                #expect(locationMessageState.address.isEmpty)
            default:
                Issue.record("Wrong message type")
            }
        }
    }

    @Test func `getManyMessages outgoing group text message`() async throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )
        let expectedMember = "ECHOECHO"
        let expectedText = "Test 123"
        let expectedReaction = "👌"
        let expectedHistoryEntryEditDate = Date()
        let expectedHistoryEntryText = "Test 123 rvision"

        let expectedMessage = testDatabase.preparer.save {
            let (_, _, conversation) = testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: [expectedMember],
                myIdentityStoreMock: myIdentityStoreMock
            )
            let message = testDatabase.preparer.createTextMessage(
                conversation: conversation,
                text: expectedText,
                isOwn: true,
                sender: nil,
                remoteSentDate: Date(),
            )
            testDatabase.preparer.createMessageReactionEntity(
                message: message,
                reaction: expectedReaction,
            )
            testDatabase.preparer.createMessageHisoryEntry(
                message: message,
                editDate: expectedHistoryEntryEditDate,
                text: expectedHistoryEntryText
            )

            return message
        }

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .group, batchIndex: 0)

        #expect(messages.count == 1)
        let message = try #require(messages.first)
        let expectedMessageID: UInt64 = try expectedMessage.id.littleEndian()
        // swiftformat:disable:next acronyms
        #expect(message.messageId == expectedMessageID)
        #expect(try message.createdAt == #require(expectedMessage.date).millisecondsSince1970)
        #expect(message.creatorIdentity == myIdentityStoreMock.identity)
        // swiftformat:disable:next acronyms
        #expect(try message.conversationId == .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)))
        #expect(message.reactions.first?.creatorIdentity == myIdentityStoreMock.identity)
        #expect(message.reactions.first?.emoji.codepoint == expectedReaction)
        #expect(message.direction == .outgoing(OutgoingMessageDirection(
            sentAt: expectedMessage.date?.millisecondsSince1970,
            deliveredAt: expectedMessage.deliveryDate?.millisecondsSince1970
        )))

        switch message.body {
        case let .text(textMessageState):
            #expect(textMessageState.original.text == expectedText)
            #expect(textMessageState.revisions.count == 1)
            let revision = try #require(textMessageState.revisions.first)
            #expect(revision.createdAt == expectedHistoryEntryEditDate.millisecondsSince1970)
            #expect(revision.message.text == expectedHistoryEntryText)
        default:
            Issue.record("Wrong message type")
        }
    }

    @Test func `getManyMessages incoming one to one text message`() async throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedText = "Test 123"
        let expectedMessage = testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: "ECHOECHO")
            let conversation = testDatabase.preparer.createConversation(contactEntity: contact)
            let message = testDatabase.preparer.createTextMessage(
                conversation: conversation,
                text: expectedText,
                isOwn: false,
                sender: contact,
                remoteSentDate: Date(),
            )
            message.deliveryDate = Date()
            return message
        }

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .contact, batchIndex: 0)

        #expect(messages.count == 1)
        let message = try #require(messages.first)
        let expectedMessageID: UInt64 = try expectedMessage.id.littleEndian()
        // swiftformat:disable:next acronyms
        #expect(message.messageId == expectedMessageID)
        #expect(try message.createdAt == #require(expectedMessage.date).millisecondsSince1970)
        #expect(try message.creatorIdentity == #require(expectedMessage.sender).identity)
        // swiftformat:disable:next acronyms
        #expect(try message.conversationId == .contact(#require(expectedMessage.conversation.contact).identity))
        #expect(try message.direction == .incoming(
            IncomingMessageDirection(
                receivedAt: #require(expectedMessage.date).millisecondsSince1970,
                overrides: MessageOverrides(deliveryReceiptPolicy: .default)
            )
        ))

        switch message.body {
        case let .text(textMessageState):
            #expect(textMessageState.original.text == expectedText)
            #expect(textMessageState.revisions.isEmpty)
        default:
            Issue.record("Wrong message type")
        }
    }

    @Test func `getManyMessages incoming group text message`() async throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )
        let expectedMember = "ECHOECHO"
        let expectedText = "Test 123"
        let expectedMessage = try testDatabase.preparer.save {
            let (_, _, conversation) = testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: [expectedMember],
                myIdentityStoreMock: myIdentityStoreMock
            )
            let message = try testDatabase.preparer.createTextMessage(
                conversation: conversation,
                text: expectedText,
                isOwn: false,
                sender: #require(conversation.members).first,
                remoteSentDate: Date(),
            )
            message.deliveryDate = Date()
            return message
        }

        // Act

        let messages = try conversationProvider.getManyMessages(conversationType: .group, batchIndex: 0)

        #expect(messages.count == 1)
        let message = try #require(messages.first)
        let expectedMessageID: UInt64 = try expectedMessage.id.littleEndian()
        // swiftformat:disable:next acronyms
        #expect(message.messageId == expectedMessageID)
        #expect(try message.createdAt == #require(expectedMessage.date).millisecondsSince1970)
        #expect(try message.creatorIdentity == #require(expectedMessage.sender).identity)
        // swiftformat:disable:next acronyms
        #expect(try message.conversationId == .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)))
        #expect(
            try message.direction == .incoming(
                IncomingMessageDirection(
                    receivedAt: #require(expectedMessage.date).millisecondsSince1970,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            )
        )

        switch message.body {
        case let .text(textMessageState):
            #expect(textMessageState.original.text == expectedText)
            #expect(textMessageState.revisions.isEmpty)
        default:
            Issue.record("Wrong message type")
        }
    }

    // MARK: Private functions

    private func makeSUT() -> (ThreemaFramework.ConversationProvider, MyIdentityStoreMock, TestDatabase) {
        let testDatabase = TestDatabase()
        let myIdentityStoreMock = MyIdentityStoreMock()

        let conversationProvider = ConversationProvider(
            userIdentity: ThreemaIdentity(myIdentityStoreMock.identity),
            entityManager: testDatabase.entityManager
        )

        return (conversationProvider, myIdentityStoreMock, testDatabase)
    }
}
