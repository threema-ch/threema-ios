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

import CocoaLumberjackSwift
import PromiseKit
import ThreemaEssentials

// TODO: (IOS-4567) Remove workaround. See `TaskDefinitionRunForwardSecurityRefreshSteps` for details

final class TaskExecutionRunForwardSecurityRefreshSteps: TaskExecution, TaskExecutionProtocol {

    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionRunForwardSecurityRefreshSteps else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard !frameworkInjector.userSettings.enableMultiDevice else {
            DDLogWarn("[ForwardSecurity] FS Refresh Steps can only be run if MD is disabled")
            return Promise(error: TaskExecutionError.multiDeviceNotSupported)
        }
        
        let leftIdentities = task.contactIdentities.filter {
            // Remove already send, own identity and blocked identities
            if task.messageAlreadySentTo.keys.contains($0.string) {
                return false
            }
            else if self.frameworkInjector.myIdentityStore.identity == $0.string {
                return false
            }
            else if self.frameworkInjector.userSettings.blacklist.contains($0.string) {
                return false
            }
            
            return true
        }

        return firstly { () -> Promise<[ForwardSecurityEnvelopeMessage]> in
            // Generate nonces and messages
            
            try self.generateMessageNonces(for: taskDefinition)
            
            return Promise {
                $0.fulfill(getMessages(for: leftIdentities))
            }
        }
        .then { messages -> Promise<[Promise<AbstractMessage?>]> in
            // Prepare sending for each message
            
            Promise { seal in
                self.frameworkInjector.entityManager.performBlock {
                    let sendMessagePromises = messages.map {
                        self.sendMessage(
                            message: $0,
                            ltSend: self.taskContext.logSendMessageToChat,
                            ltAck: self.taskContext.logReceiveMessageAckFromChat
                        )
                    }
                    
                    seal.fulfill(sendMessagePromises)
                }
            }
        }
        .then { sendMessagePromises in
            // Send all messages
            when(fulfilled: sendMessagePromises).done { _ in
                DDLogVerbose("[ForwardSecurity] Successfully sent all FS Refresh Steps messages")
            }
        }
    }
    
    // Adapted from `ForwardSecurityRefreshSteps.runFutureSteps(for:)`
    private func getMessages(for leftIdentities: [ThreemaIdentity]) -> [ForwardSecurityEnvelopeMessage] {
        // 1. Let `contacts` be the provided list of contacts.
        // 2. For each `contact` of `contacts`:
        frameworkInjector.entityManager.performAndWait {
            var messages = [ForwardSecurityEnvelopeMessage]()
            
            for contactIdentity in leftIdentities {
                guard let contactEntity = self.frameworkInjector.entityManager.entityFetcher.contact(
                    for: contactIdentity.string
                ) else {
                    DDLogError("[ForwardSecurity] Unable to load contact entity for \(contactIdentity)")
                    continue
                }
                
                //    1. If the `contact` does not support FS, abort these sub-steps.
                guard contactEntity.isForwardSecurityAvailable else {
                    continue
                }
                
                // We don't want to cancel any other refresh if one fails
                do {
                    try messages.append(
                        self.runSteps(with: contactEntity)
                    )
                }
                catch {
                    DDLogWarn("[ForwardSecurity] Refresh steps failed for \(contactIdentity): \(error)")
                }
            }
            
            return messages
        }
    }
    
    // Adapted from `ForwardSecurityRefreshSteps.runSteps(with:)`
    // This should be called inside a perform block
    private func runSteps(with contactEntity: ContactEntity) throws -> ForwardSecurityEnvelopeMessage {
    
        //    2. Lookup a session with `contact` and let `session` be the result.
        let message: ForwardSecurityEnvelopeMessage
        if let session = try? frameworkInjector.dhSessionStore.bestDHSession(
            myIdentity: frameworkInjector.myIdentityStore.identity,
            peerIdentity: contactEntity.identity
        ) {
            //    4. If `session` is not a newly created session, create an `Encapsulated`
            //       message using `session` from inner type `0xfc` (_empty_) and set
            //       `message` to the encrypted and encoded result with type `0xa0`.

            if session.newSessionCommitted {
                message = try frameworkInjector.fsmp.makeEmptyMessage(for: session)
            }
            else {
                // If we didn't commit the session so far we send an `Init` again
                message = try frameworkInjector.fsmp.makeInitMessage(for: session)
            }
        }
        else {
            //    3. If `session` is undefined, initiate a new `L20` session and set
            //       `session` to the newly created session. Set `message` to the `Init`
            //       message for `session` with type `0xa0`.
            let contact = ForwardSecurityContact(identity: contactEntity.identity, publicKey: contactEntity.publicKey)
            message = try frameworkInjector.fsmp.makeNewSession(with: contact)
        }
        
        //    5. Send `message` to `contact` and wait for acknowledgement.
        //    6. Set `session`'s _updated_ mark to the current timestamp and commit the
        //       `session` changes to storage.
        
        // 5. - 7. will all happen in the message sending done above
        return message
    }
}
