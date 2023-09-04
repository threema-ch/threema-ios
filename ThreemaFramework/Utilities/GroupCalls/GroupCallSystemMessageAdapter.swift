//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import GroupCalls
import ThreemaProtocols

/// Allows the Group Calls module to post system messages
final class GroupCallSystemMessageAdapter<BusinessInjectorImpl: BusinessInjectorProtocol>: Sendable {
    // MARK: - Private Properties
    
    // `BusinessInjectorProtocol` is not explicitly sendable. We accept this limitation.
    private let businessInjector: BusinessInjectorImpl
    
    // MARK: - Lifecycle
    
    init(businessInjector: BusinessInjectorImpl) {
        self.businessInjector = businessInjector
    }
}

// MARK: - GroupCallSystemMessageAdapterProtocol

extension GroupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol {
    func post(_ systemMessage: GroupCallsSystemMessage, in groupModel: GroupCallsThreemaGroupModel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.businessInjector.backgroundEntityManager.performAsyncBlockAndSafe {
                guard let conversation = self.businessInjector.backgroundEntityManager.entityFetcher.conversation(
                    for: groupModel.groupID,
                    creator: groupModel.creator.id
                ) else {
                    continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                    return
                }
                
                switch systemMessage {
                case let .groupCallStartedBy(threemaID):
                    guard let contact = self.businessInjector.backgroundEntityManager.entityFetcher
                        .contact(for: threemaID.id) else {
                        continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                        return
                    }
                    
                    guard let dbSystemMessage = self.businessInjector.backgroundEntityManager.entityCreator
                        .systemMessage(for: conversation) else {
                        continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                        return
                    }
                    
                    dbSystemMessage.type = NSNumber(value: kSystemMessageGroupCallStartedBy)
                    dbSystemMessage.arg = contact.displayName.data(using: .utf8)
                    
                    conversation.lastMessage = dbSystemMessage
                    conversation.lastUpdate = Date.now
                case .groupCallEnded:
                    guard let dbSystemMessage = self.businessInjector.backgroundEntityManager.entityCreator
                        .systemMessage(for: conversation) else {
                        continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                        return
                    }
                    
                    dbSystemMessage.type = NSNumber(value: kSystemMessageGroupCallEnded)
                    
                    conversation.lastMessage = dbSystemMessage
                case .groupCallStarted:
                    guard let dbSystemMessage = self.businessInjector.backgroundEntityManager.entityCreator
                        .systemMessage(for: conversation) else {
                        continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                        return
                    }
                    
                    dbSystemMessage.type = NSNumber(value: kSystemMessageGroupCallStarted)
                    
                    conversation.lastMessage = dbSystemMessage
                    conversation.lastUpdate = Date.now
                }
                
                continuation.resume()
            }
        }
    }
}
