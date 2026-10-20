import Foundation
import libthreemaSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@Suite("Test libthreema ConversationProvider.AddMessages")
struct ConversationProviderAddMessagesTests {

    // MARK: Test addMessage for one to one messages

    @Test func `addMessages incoming one to one message sender contact is missing`() throws {
        let (conversationProvider, _, _) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender
        )

        // Act

        #expect(throws: ProviderError.ContractViolation("Contact not found")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages incoming one to one message sender contact is hidden`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            contactEntity.isHidden = true
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender
        )

        // Act

        #expect(throws: ProviderError.ContractViolation("Contact must have acquaintance level direct")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages incoming one to one message with existing conversation`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreateAt = Date().millisecondsSince1970
        let expectedReceivedAt = Date().millisecondsSince1970
        let expectedText = "Bla"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            createdAt: expectedCreateAt,
            direction: .incoming(
                IncomingMessageDirection(
                    receivedAt: expectedReceivedAt,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            ),
            body: .text(TextMessageState(original: MessageText(text: expectedText), revisions: []))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedSender)
        )
        let contactEntity = try #require(conversationEntity.contact)
        #expect(contactEntity.identity == expectedSender)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == false)
        #expect(textMessageEntity.isOwnMessage == false)
        #expect(textMessageEntity.sender == contactEntity)
        #expect(textMessageEntity.sent.boolValue == false)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedReceivedAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreateAt)
        #expect(textMessageEntity.delivered == false)
        #expect(textMessageEntity.deliveryDate == nil)
        #expect(textMessageEntity.read == false)
        #expect(textMessageEntity.readDate == nil)
        #expect(textMessageEntity.deletedAt == nil)
        #expect(textMessageEntity.lastEditedAt == nil)
        #expect(textMessageEntity.hasMarkers == false)
        #expect(textMessageEntity.messageMarkers == nil)
        #expect(textMessageEntity.reactions?.isEmpty == true)
        #expect(textMessageEntity.historyEntries?.isEmpty == true)
        #expect(textMessageEntity.text == expectedText)
    }

    @Test func `addMessages incoming one to one message create new conversation`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreateAt = Date().millisecondsSince1970
        let expectedReceivedAt = Date().millisecondsSince1970
        let expectedText = "Bla"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedSender)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            createdAt: expectedCreateAt,
            direction: .incoming(
                IncomingMessageDirection(
                    receivedAt: expectedReceivedAt,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            ),
            body: .text(TextMessageState(original: MessageText(text: expectedText), revisions: []))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedSender)
        )
        let contactEntity = try #require(conversationEntity.contact)
        #expect(contactEntity.identity == expectedSender)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == false)
        #expect(textMessageEntity.isOwnMessage == false)
        #expect(textMessageEntity.sender == contactEntity)
        #expect(textMessageEntity.sent.boolValue == false)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedReceivedAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreateAt)
        #expect(textMessageEntity.delivered == false)
        #expect(textMessageEntity.deliveryDate == nil)
        #expect(textMessageEntity.read == false)
        #expect(textMessageEntity.readDate == nil)
        #expect(textMessageEntity.deletedAt == nil)
        #expect(textMessageEntity.lastEditedAt == nil)
        #expect(textMessageEntity.hasMarkers == false)
        #expect(textMessageEntity.messageMarkers == nil)
        #expect(textMessageEntity.reactions?.isEmpty == true)
        #expect(textMessageEntity.historyEntries?.isEmpty == true)
        #expect(textMessageEntity.text == expectedText)
    }

    @Test func `addMessages outgoing one to one message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreatedAt = Date().addingTimeInterval(-62).millisecondsSince1970
        let expectedSentAt = Date().addingTimeInterval(-60).millisecondsSince1970
        let expectedDeliveredAt = Date().addingTimeInterval(-58).millisecondsSince1970
        let expectedReadAt = Date().addingTimeInterval(-55).millisecondsSince1970
        let expectedReactionCreatedAt = Date().addingTimeInterval(-45).millisecondsSince1970
        let expectedReactionCreatorIdentity = "ECHOECHO"
        let expectedReactionEmoji = "✅"
        let expectedText = "Bla bla"
        let expectedRevisionCreateAt = Date().addingTimeInterval(-59).millisecondsSince1970
        let expectedRevisionText = "Bli bli"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            createdAt: expectedCreatedAt,
            direction: .outgoing(OutgoingMessageDirection(
                sentAt: expectedSentAt,
                deliveredAt: expectedDeliveredAt
            )),
            readAt: expectedReadAt,
            starMarker: .star,
            reactions: [
                MessageReaction(
                    createdAt: expectedReactionCreatedAt,
                    creatorIdentity: expectedReactionCreatorIdentity,
                    emoji: EmojiReaction(codepoint: expectedReactionEmoji)
                )
            ],
            body: .text(TextMessageState(
                original: MessageText(text: expectedText),
                revisions: [
                    MessageTextRevision(
                        createdAt: expectedRevisionCreateAt,
                        message: MessageText(text: expectedRevisionText)
                    )
                ]
            ))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let contactEntity = try #require(conversationEntity.contact)
        #expect(contactEntity.identity == expectedReceiver)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == false)
        #expect(textMessageEntity.isOwnMessage == true)
        #expect(textMessageEntity.sender == nil)
        #expect(textMessageEntity.sent.boolValue == true)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedSentAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreatedAt)
        #expect(textMessageEntity.delivered == true)
        #expect(textMessageEntity.deliveryDate?.millisecondsSince1970 == expectedDeliveredAt)
        #expect(textMessageEntity.read == true)
        #expect(textMessageEntity.readDate?.millisecondsSince1970 == expectedReadAt)
        #expect(textMessageEntity.deletedAt == nil)
        #expect(textMessageEntity.lastEditedAt?.millisecondsSince1970 == expectedRevisionCreateAt)
        #expect(textMessageEntity.hasMarkers == true)
        #expect(textMessageEntity.text == expectedRevisionText)
        let messageMarkers = try #require(textMessageEntity.messageMarkers)
        #expect(messageMarkers.star.boolValue == true)
        let reactions = try #require(textMessageEntity.reactions)
        #expect(reactions.count == 1)
        #expect(reactions.first?.date.millisecondsSince1970 == expectedReactionCreatedAt)
        #expect(reactions.first?.creator?.identity == expectedReactionCreatorIdentity)
        #expect(reactions.first?.reaction == expectedReactionEmoji)
        let historyEntries = try #require(textMessageEntity.historyEntries)
        #expect(historyEntries.count == 1)
        #expect(historyEntries.first?.editDate.millisecondsSince1970 == expectedRevisionCreateAt)
        #expect(historyEntries.first?.text == expectedText)
    }

    @Test func `addMessages outgoing one to one deleted message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreatedAt = Date().addingTimeInterval(-62).millisecondsSince1970
        let expectedSentAt = Date().addingTimeInterval(-60).millisecondsSince1970
        let expectedDeliveredAt = Date().addingTimeInterval(-58).millisecondsSince1970
        let expectedReadAt = Date().addingTimeInterval(-55).millisecondsSince1970
        let expectedReactionCreatedAt = Date().addingTimeInterval(-45).millisecondsSince1970
        let expectedReactionCreatorIdentity = "ECHOECHO"
        let expectedReactionEmoji = "✅"
        let expectedDeletedAt = Date().millisecondsSince1970

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            createdAt: expectedCreatedAt,
            direction: .outgoing(.init(
                sentAt: expectedSentAt,
                deliveredAt: expectedDeliveredAt
            )),
            readAt: expectedReadAt,
            starMarker: .star,
            reactions: [
                MessageReaction(
                    createdAt: expectedReactionCreatedAt,
                    creatorIdentity: expectedReactionCreatorIdentity,
                    emoji: EmojiReaction(codepoint: expectedReactionEmoji)
                )
            ],
            body: .deleted(.init(previousMessageType: .text, deletedAt: expectedDeletedAt))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let contactEntity = try #require(conversationEntity.contact)
        #expect(contactEntity.identity == expectedReceiver)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == false)
        #expect(textMessageEntity.isOwnMessage == true)
        #expect(textMessageEntity.sender == nil)
        #expect(textMessageEntity.sent.boolValue == true)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedSentAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreatedAt)
        #expect(textMessageEntity.delivered == true)
        #expect(textMessageEntity.deliveryDate?.millisecondsSince1970 == expectedDeliveredAt)
        #expect(textMessageEntity.read == true)
        #expect(textMessageEntity.readDate?.millisecondsSince1970 == expectedReadAt)
        #expect(textMessageEntity.deletedAt?.millisecondsSince1970 == expectedDeletedAt)
        #expect(textMessageEntity.lastEditedAt == nil)
        #expect(textMessageEntity.hasMarkers == true)
        #expect(textMessageEntity.text == String.empty)
        let messageMarkers = try #require(textMessageEntity.messageMarkers)
        #expect(messageMarkers.star.boolValue == true)
        let reactions = try #require(textMessageEntity.reactions)
        #expect(reactions.count == 1)
        #expect(reactions.first?.date.millisecondsSince1970 == expectedReactionCreatedAt)
        #expect(reactions.first?.creator?.identity == expectedReactionCreatorIdentity)
        #expect(reactions.first?.reaction == expectedReactionEmoji)
        let historyEntries = try #require(textMessageEntity.historyEntries)
        #expect(historyEntries.isEmpty)
    }

    // MARK: Test addMessage for group messages

    @Test func `addMessages incoming group message group not exists`() throws {
        let (conversationProvider, myIdentityStoreMock, _) = makeSUT()

        let expectedGroupIdentity = ThreemaEssentials.GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: "MEMBER01"
        )

        // Act

        #expect(throws: ProviderError.ContractViolation("Group not found")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages incoming group message conversation not exists`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = ThreemaEssentials.GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createGroupEntity(
                groupID: expectedGroupIdentity.id,
                groupCreator: nil // The user is the creator
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: "MEMBER01"
        )

        // Act

        #expect(throws: ProviderError.ContractViolation("Group not found")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages incoming group message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = ThreemaEssentials.GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedSender: LibthreemaThreemaID = "MEMBER01"
        let expectedCreatedAt = Date().addingTimeInterval(-62).millisecondsSince1970
        let expectedReceivedAt = Date().addingTimeInterval(-60).millisecondsSince1970
        let expectedText = "Bla"

        try testDatabase.preparer.save {
            try testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: ["MEMBER01", "MEMBER01"],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: expectedSender,
            createdAt: expectedCreatedAt,
            direction: .incoming(
                IncomingMessageDirection(
                    receivedAt: expectedReceivedAt,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            ),
            body: .text(TextMessageState(original: MessageText(text: expectedText), revisions: []))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(
                for: expectedGroupIdentity,
                myIdentity: myIdentityStoreMock.identity
            )
        )
        #expect(conversationEntity.contact == nil)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == true)
        #expect(textMessageEntity.isOwnMessage == false)
        #expect(textMessageEntity.sender?.identity == expectedSender)
        #expect(textMessageEntity.sent.boolValue == false)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedCreatedAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedReceivedAt)
        #expect(textMessageEntity.delivered == false)
        #expect(textMessageEntity.deliveryDate == nil)
        #expect(textMessageEntity.read == false)
        #expect(textMessageEntity.readDate == nil)
        #expect(textMessageEntity.deletedAt == nil)
        #expect(textMessageEntity.lastEditedAt == nil)
        #expect(textMessageEntity.hasMarkers == false)
        #expect(textMessageEntity.messageMarkers == nil)
        #expect(textMessageEntity.reactions?.isEmpty == true)
        #expect(textMessageEntity.historyEntries?.isEmpty == true)
        #expect(textMessageEntity.text == expectedText)
    }

    @Test(arguments: [
        ["MEMBER01", "MEMBER01"],
        [],
    ])
    func `addMessages outgoing group message`(expectedMembers: [String]) throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )
        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreatedAt = Date().addingTimeInterval(-62).millisecondsSince1970
        let expectedSentAt = Date().addingTimeInterval(-60).millisecondsSince1970
        let expectedDeliveredAt = Date().addingTimeInterval(-58).millisecondsSince1970
        let expectedReadAt = Date().addingTimeInterval(-55).millisecondsSince1970
        let expectedReactionCreatedAt = Date().addingTimeInterval(-45).millisecondsSince1970
        let expectedReactionCreatorIdentity = "ECHOECHO"
        let expectedReactionEmoji = "✅"
        let expectedRevisionCreateAt = Date().addingTimeInterval(-40).millisecondsSince1970
        let expectedRevisionText = "Bli bli"
        let expectedText = "Bla bla"

        try testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)

            try testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: expectedMembers,
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: myIdentityStoreMock.identity,
            createdAt: expectedCreatedAt,
            direction: .outgoing(.init(
                sentAt: expectedSentAt,
                deliveredAt: expectedDeliveredAt
            )),
            readAt: expectedReadAt,
            starMarker: .star,
            reactions: [
                MessageReaction(
                    createdAt: expectedReactionCreatedAt,
                    creatorIdentity: expectedReactionCreatorIdentity,
                    emoji: EmojiReaction(codepoint: expectedReactionEmoji)
                )
            ],
            body: .text(.init(
                original: MessageText(text: expectedText),
                revisions: [
                    MessageTextRevision(
                        createdAt: expectedRevisionCreateAt,
                        message: MessageText(text: expectedRevisionText)
                    )
                ]
            ))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(
                for: expectedGroupIdentity,
                myIdentity: myIdentityStoreMock.identity
            )
        )
        #expect(conversationEntity.contact == nil)
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == true)
        #expect(textMessageEntity.isOwnMessage == true)
        #expect(textMessageEntity.sender == nil)
        #expect(textMessageEntity.sent.boolValue == true)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedSentAt)
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreatedAt)
        #expect(textMessageEntity.delivered == true)
        #expect(textMessageEntity.deliveryDate?.millisecondsSince1970 == expectedDeliveredAt)
        #expect(textMessageEntity.read == true)
        #expect(textMessageEntity.readDate?.millisecondsSince1970 == expectedReadAt)
        #expect(textMessageEntity.deletedAt == nil)
        #expect(textMessageEntity.lastEditedAt?.millisecondsSince1970 == expectedRevisionCreateAt)
        #expect(textMessageEntity.hasMarkers == true)
        let messageMarkers = try #require(textMessageEntity.messageMarkers)
        #expect(messageMarkers.star.boolValue == true)
        let reactions = try #require(textMessageEntity.reactions)
        #expect(reactions.count == 1)
        #expect(reactions.first?.date.millisecondsSince1970 == expectedReactionCreatedAt)
        #expect(reactions.first?.creator?.identity == expectedReactionCreatorIdentity)
        #expect(reactions.first?.reaction == expectedReactionEmoji)
        let historyEntries = try #require(textMessageEntity.historyEntries)
        #expect(historyEntries.count == 1)
        #expect(historyEntries.first?.editDate.millisecondsSince1970 == expectedRevisionCreateAt)
        #expect(historyEntries.first?.text == expectedText)
        #expect(textMessageEntity.text == expectedRevisionText)
    }

    // MARK: Test addMessages batch behaviour

    @Test func `addMessages with empty messages array does nothing`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        // Act & Assert: must not throw and must not perform any changes
        try conversationProvider.addMessages(messages: [])

        let noConversations = testDatabase.entityManager.performAndWait {
            testDatabase.entityManager.entityFetcher.conversationEntities()?.isEmpty ?? true
        }
        #expect(noConversations)
    }

    @Test func `addMessages adds multiple messages in a single call`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let firstMessage = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            body: .text(TextMessageState(original: MessageText(text: "First"), revisions: []))
        )
        let secondMessage = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            body: .text(TextMessageState(original: MessageText(text: "Second"), revisions: []))
        )

        // Act

        try conversationProvider.addMessages(messages: [firstMessage, secondMessage])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedSender)
        )
        let firstEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: firstMessage.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        let secondEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: secondMessage.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(firstEntity.text == "First")
        #expect(secondEntity.text == "Second")
    }

    @Test func `addMessages rolls back all messages when one fails`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        // First message is valid; the second references a contact that does not exist and throws.
        let validMessage = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            body: .text(TextMessageState(original: MessageText(text: "Valid"), revisions: []))
        )
        let failingMessage = try libthreemaMessageState(
            conversationID: .contact("NOEXIST0"),
            creatorIdentity: "NOEXIST0"
        )

        // Act & Assert

        #expect(throws: ProviderError.ContractViolation("Contact not found")) {
            try conversationProvider.addMessages(messages: [validMessage, failingMessage])
        }

        // The valid message must have been rolled back together with the failing one.
        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedSender)
        )
        #expect(testDatabase.entityManager.entityFetcher.message(
            // swiftformat:disable:next acronyms
            with: validMessage.messageId.littleEndianData,
            in: conversationEntity
        ) == nil)
    }

    // MARK: Test addMessages with duplicate message id

    @Test func `addMessages with duplicate message id throws`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender
        )

        // First insertion succeeds.
        try conversationProvider.addMessages(messages: [messageState])

        // Act & Assert: second insertion with the same message id throws.

        #expect(throws: ProviderError.ContractViolation("Message already in the conversation")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    // MARK: Test addMessages for distribution list messages

    @Test func `addMessages skips distribution list messages`() throws {
        let (conversationProvider, _, _) = makeSUT()

        let messageState = try libthreemaMessageState(
            conversationID: .distributionList(1),
            creatorIdentity: "ECHOECHO"
        )

        // Act & Assert: distribution lists are unsupported on iOS and are silently skipped
        try conversationProvider.addMessages(messages: [messageState])
    }

    // MARK: Test addMessages incoming message from local user

    @Test func `addMessages incoming one to one message from local user has no sender`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedContact: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedContact)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedContact),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .incoming(
                IncomingMessageDirection(
                    receivedAt: Date().millisecondsSince1970,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            )
        )

        // Act

        #expect(
            throws: ProviderError.ContractViolation(
                "The sender \(myIdentityStoreMock.identity!) of the message not found"
            )
        ) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    // MARK: Test addMessages outgoing message date combinations

    @Test func `addMessages outgoing one to one message without sent date`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isOwnMessage == true)
        #expect(textMessageEntity.sent.boolValue == false)
        #expect(textMessageEntity.remoteSentDate == nil)
        #expect(textMessageEntity.delivered == false)
        #expect(textMessageEntity.deliveryDate == nil)
    }

    @Test func `addMessages outgoing one to one message sent but not delivered`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedSentAt = Date().addingTimeInterval(-10).millisecondsSince1970

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: expectedSentAt, deliveredAt: nil))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.sent.boolValue == true)
        #expect(textMessageEntity.remoteSentDate?.millisecondsSince1970 == expectedSentAt)
        #expect(textMessageEntity.delivered == false)
        #expect(textMessageEntity.deliveryDate == nil)
    }

    // MARK: Test addMessages incoming message with read date

    @Test func `addMessages incoming one to one message with read date`() throws {
        let (conversationProvider, _, testDatabase) = makeSUT()

        let expectedSender: LibthreemaThreemaID = "ECHOECHO"
        let expectedReadAt = Date().addingTimeInterval(-5).millisecondsSince1970

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedSender)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedSender),
            creatorIdentity: expectedSender,
            readAt: expectedReadAt
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedSender)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.read == true)
        #expect(textMessageEntity.readDate?.millisecondsSince1970 == expectedReadAt)
    }

    // MARK: Test addMessages for message body variants

    @Test func `addMessages outgoing one to one location message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedLatitude = 47.366_667
        let expectedLongitude = 8.55
        let expectedAccuracy = 12.5
        let expectedName = "Zürich"
        let expectedAddress = "Bahnhofstrasse 1"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .location(LocationMessageState(
                latitude: expectedLatitude,
                longitude: expectedLongitude,
                accuracyM: expectedAccuracy,
                name: expectedName,
                address: expectedAddress
            ))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let locationMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? LocationMessageEntity
        )
        #expect(locationMessageEntity.latitude.doubleValue == expectedLatitude)
        #expect(locationMessageEntity.longitude.doubleValue == expectedLongitude)
        #expect(locationMessageEntity.accuracy?.doubleValue == expectedAccuracy)
        #expect(locationMessageEntity.poiName == expectedName)
        #expect(locationMessageEntity.poiAddress == expectedAddress)
        #expect(locationMessageEntity.deletedAt == nil)
    }

    @Test func `addMessages outgoing one to one poll open message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedPollID: LibthreemaPollID = 42

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedReceiver)
            let conversation = testDatabase.preparer.createConversation(contactEntity: contactEntity)
            testDatabase.preparer.createBallot(
                conversation: conversation,
                // swiftformat:disable:next acronyms
                ballotID: expectedPollID.littleEndianData
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .pollOpen(PollOpen(id: expectedPollID))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let ballotMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? BallotMessageEntity
        )
        #expect(ballotMessageEntity.ballot != nil)
        #expect(ballotMessageEntity.ballotState?.intValue == BallotEntity.BallotState.open.rawValue)
        #expect(ballotMessageEntity.deletedAt == nil)
    }

    @Test func `addMessages outgoing one to one poll close message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedPollID: LibthreemaPollID = 43

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedReceiver)
            let conversation = testDatabase.preparer.createConversation(contactEntity: contactEntity)
            testDatabase.preparer.createBallot(
                conversation: conversation,
                // swiftformat:disable:next acronyms
                ballotID: expectedPollID.littleEndianData
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .pollClose(PollClose(id: expectedPollID))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let ballotMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? BallotMessageEntity
        )
        #expect(ballotMessageEntity.ballot != nil)
        #expect(ballotMessageEntity.ballotState?.intValue == BallotEntity.BallotState.closed.rawValue)
        #expect(ballotMessageEntity.deletedAt == nil)
    }

    @Test func `addMessages poll message with missing ballot throws`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            let contactEntity = testDatabase.preparer.createContact(identity: expectedReceiver)
            testDatabase.preparer.createConversation(contactEntity: contactEntity)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .pollOpen(PollOpen(id: 999))
        )

        // Act & Assert

        #expect(throws: ThreemaFramework.ConversationProvider.ConversationProviderError.ballotIsMissing) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages deleted location message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedDeletedAt = Date().millisecondsSince1970

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .deleted(.init(previousMessageType: .location, deletedAt: expectedDeletedAt))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let locationMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? LocationMessageEntity
        )
        #expect(locationMessageEntity.deletedAt?.millisecondsSince1970 == expectedDeletedAt)
        #expect(locationMessageEntity.latitude.doubleValue == 0)
        #expect(locationMessageEntity.longitude.doubleValue == 0)
    }

    @Test func `addMessages deleted poll message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedDeletedAt = Date().millisecondsSince1970

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        // A deleted poll does not fetch the ballot, so no ballot fixture is required.
        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .deleted(.init(previousMessageType: .pollOpen, deletedAt: expectedDeletedAt))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let ballotMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? BallotMessageEntity
        )
        #expect(ballotMessageEntity.deletedAt?.millisecondsSince1970 == expectedDeletedAt)
    }

    @Test func `addMessages deleted message with deleted subtype`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedDeletedAt = Date().millisecondsSince1970

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .deleted(.init(previousMessageType: .deleted, deletedAt: expectedDeletedAt))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.deletedAt?.millisecondsSince1970 == expectedDeletedAt)
        #expect(textMessageEntity.text == String.empty)
    }

    // MARK: Test addMessages reactions

    @Test func `addMessages message with own reaction has no creator`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedReactionEmoji = "👍"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            reactions: [
                MessageReaction(
                    createdAt: Date().millisecondsSince1970,
                    creatorIdentity: myIdentityStoreMock.identity,
                    emoji: EmojiReaction(codepoint: expectedReactionEmoji)
                ),
            ]
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        let reactions = try #require(textMessageEntity.reactions)
        #expect(reactions.count == 1)
        #expect(reactions.first?.creator == nil)
        #expect(reactions.first?.reaction == expectedReactionEmoji)
    }

    @Test(.disabled("Rollback issue of unsaved entities"))
    func `addMessages message with reaction from unknown contact throws`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            reactions: [
                MessageReaction(
                    createdAt: Date().millisecondsSince1970,
                    creatorIdentity: "NOEXIST0",
                    emoji: EmojiReaction(codepoint: "👍")
                ),
            ]
        )

        // Act & Assert

        #expect(throws: ThreemaFramework.ConversationProvider.ConversationProviderError.messageSenderIsMissing) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages message with multiple reactions`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let firstEmoji = "👍"
        let secondEmoji = "🎉"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            reactions: [
                MessageReaction(
                    createdAt: Date().addingTimeInterval(-10).millisecondsSince1970,
                    creatorIdentity: expectedReceiver,
                    emoji: EmojiReaction(codepoint: firstEmoji)
                ),
                MessageReaction(
                    createdAt: Date().addingTimeInterval(-5).millisecondsSince1970,
                    creatorIdentity: expectedReceiver,
                    emoji: EmojiReaction(codepoint: secondEmoji)
                ),
            ]
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        let reactions = try #require(textMessageEntity.reactions)
        #expect(reactions.count == 2)
        #expect(Set(reactions.map(\.reaction)) == Set([firstEmoji, secondEmoji]))
    }

    // MARK: Test addMessages text revisions

    @Test func `addMessages text message with multiple revisions`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedReceiver: LibthreemaThreemaID = "ECHOECHO"
        let expectedCreateAt = Date().addingTimeInterval(-50).millisecondsSince1970
        let expectedText = "original text"
        let expectedFirstRevisionDate = Date().addingTimeInterval(-30).millisecondsSince1970
        let expectedFirstRevisionText = "first revision"
        let expectedLastRevisionDate = Date().addingTimeInterval(-10).millisecondsSince1970
        let expectedLastRevisionText = "last revision"

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedReceiver)
        }

        let messageState = try libthreemaMessageState(
            conversationID: .contact(expectedReceiver),
            creatorIdentity: myIdentityStoreMock.identity,
            createdAt: expectedCreateAt,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .text(TextMessageState(
                original: MessageText(text: expectedText),
                revisions: [
                    MessageTextRevision(
                        createdAt: expectedFirstRevisionDate,
                        message: MessageText(text: expectedFirstRevisionText)
                    ),
                    MessageTextRevision(
                        createdAt: expectedLastRevisionDate,
                        message: MessageText(text: expectedLastRevisionText)
                    ),
                ]
            ))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(for: expectedReceiver)
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        let historyEntries = try #require(textMessageEntity.historyEntries)
        #expect(historyEntries.count == 2)
        #expect(
            historyEntries.contains(
                where: { $0.text == expectedText && $0.editDate.millisecondsSince1970 == expectedFirstRevisionDate }
            )
        )
        #expect(
            historyEntries.contains(
                where: { $0.text == expectedFirstRevisionText && $0.editDate.millisecondsSince1970 == expectedFirstRevisionDate }
            )
        )
        #expect(textMessageEntity.date?.millisecondsSince1970 == expectedCreateAt)
        #expect(textMessageEntity.lastEditedAt?.millisecondsSince1970 == expectedLastRevisionDate)
        #expect(textMessageEntity.text == expectedLastRevisionText)
    }

    // MARK: Test addMessages group edge cases

    @Test func `addMessages incoming group message sender is missing`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = ThreemaEssentials.GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creatorID: myIdentityStoreMock.identity
        )
        let expectedCreator = "NONMEMB0"

        try testDatabase.preparer.save {
            try testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: ["MEMBER01"],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        // The sender is not a known contact.
        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: expectedCreator,
            direction: .incoming(
                IncomingMessageDirection(
                    receivedAt: Date().millisecondsSince1970,
                    overrides: MessageOverrides(deliveryReceiptPolicy: .default)
                )
            )
        )

        // Act & Assert

        #expect(throws: ProviderError.ContractViolation("The sender \(expectedCreator) of the message not found")) {
            try conversationProvider.addMessages(messages: [messageState])
        }
    }

    @Test func `addMessages outgoing group deleted message`() throws {
        let (conversationProvider, myIdentityStoreMock, testDatabase) = makeSUT()

        let expectedGroupIdentity = GroupIdentity(
            id: BytesUtility.generateGroupID(),
            creator: ThreemaIdentity(myIdentityStoreMock.identity)
        )

        try testDatabase.preparer.save {
            try testDatabase.preparer.createGroup(
                groupID: expectedGroupIdentity.id,
                groupCreatorIdentity: expectedGroupIdentity.creator.rawValue,
                members: ["MEMBER01"],
                myIdentityStoreMock: myIdentityStoreMock
            )
        }

        let messageState = try libthreemaMessageState(
            conversationID: .group(LibthreemaGroupIdentity(groupIdentity: expectedGroupIdentity)),
            creatorIdentity: myIdentityStoreMock.identity,
            direction: .outgoing(OutgoingMessageDirection(sentAt: nil, deliveredAt: nil)),
            body: .deleted(.init(previousMessageType: .text, deletedAt: Date().millisecondsSince1970))
        )

        // Act

        try conversationProvider.addMessages(messages: [messageState])

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher.conversationEntity(
                for: expectedGroupIdentity,
                myIdentity: myIdentityStoreMock.identity
            )
        )
        let textMessageEntity = try #require(
            testDatabase.entityManager.entityFetcher.message(
                // swiftformat:disable:next acronyms
                with: messageState.messageId.littleEndianData,
                in: conversationEntity
            ) as? TextMessageEntity
        )
        #expect(textMessageEntity.isGroupMessage == true)
        #expect(textMessageEntity.isOwnMessage == true)
        #expect(textMessageEntity.deletedAt != nil)
        #expect(textMessageEntity.text == String.empty)
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

    private func libthreemaMessageState(
        conversationID: LibthreemaConversationID,
        creatorIdentity: LibthreemaThreemaID,
        messageID: LibthreemaMessageID? = nil,
        createdAt: UInt64 = Date().millisecondsSince1970,
        direction: MessageDirection = .incoming(
            IncomingMessageDirection(
                receivedAt: Date().millisecondsSince1970,
                overrides: MessageOverrides(deliveryReceiptPolicy: .default) // TODO: Implement overrides!
            )
        ),
        readAt: UInt64? = nil,
        starMarker: MessageStarMarker = .none,
        reactions: [MessageReaction] = [],
        body: MessageStateBody = .text(TextMessageState(original: MessageText(text: "bla"), revisions: []))
    ) throws -> MessageState {
        try MessageState(
            // swiftformat:disable:next acronyms
            conversationId: conversationID,
            creatorIdentity: creatorIdentity,
            // swiftformat:disable:next acronyms
            messageId: messageID ?? BytesUtility.generateMessageID().littleEndian(),
            createdAt: createdAt,
            direction: direction,
            readAt: readAt,
            starMarker: starMarker,
            reactions: reactions,
            body: body
        )
    }
}
