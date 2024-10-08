//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaEssentials

/// This implements the Threema Protocols _FS Refresh Steps_
///
/// Our implementation differs from the Protocol in the following ways:
/// - If an existing session was not committed so far we send an `Init` again (instead of an encapsulated `empty`
/// message)
/// - The session's own ratchets are immediately updated when the message is created
/// - Instead of running the steps here they are currently executed in `TaskDefinitionRunForwardSecurityRefreshSteps`
/// (IOS-4567)
struct ForwardSecurityRefreshSteps {
    
    private let backgroundBusinessInjector: FrameworkInjectorProtocol
    // TODO: (IOS-4567) Remove
    private let taskManager: TaskManagerProtocol
    
    public init() {
        let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)
        self.init(
            backgroundBusinessInjector: backgroundBusinessInjector,
            taskManager: TaskManager(
                backgroundEntityManager: backgroundBusinessInjector.entityManager,
                serverConnector: backgroundBusinessInjector.serverConnector
            )
        )
    }
    
    init(
        backgroundBusinessInjector: FrameworkInjectorProtocol,
        taskManager: TaskManagerProtocol
    ) {
        self.backgroundBusinessInjector = backgroundBusinessInjector
        self.taskManager = taskManager
    }
    
    /// Run _FS Refresh Steps_
    /// - Parameter contactIdentities: Threema identities to run refresh steps for. They should exist as contacts.
    public func run(for contactIdentities: [ThreemaIdentity]) async {
        DDLogNotice("[ForwardSecurity] Start FS Refresh Steps")
        defer { DDLogNotice("[ForwardSecurity] Exit FS Refresh Steps") }
                
        guard !backgroundBusinessInjector.settingsStore.isMultiDeviceRegistered else {
            DDLogError(
                "[ForwardSecurity] It is illegal to run the FS Refresh Steps (before FS 2.0) when MD is registered"
            )
            return
        }
        
        // TODO: (IOS-4567) Remove task creation and run `runFutureSteps` again
        
        taskManager.add(
            taskDefinition: TaskDefinitionRunForwardSecurityRefreshSteps(with: contactIdentities)
        )
        
        // await runFutureSteps(for: contactIdentities)
    }
    
    private func runFutureSteps(for contactIdentities: [ThreemaIdentity]) async {
        // 1. Let `contacts` be the provided list of contacts.
        // 2. For each `contact` of `contacts`:
        await backgroundBusinessInjector.entityManager.perform {
            for contactIdentity in contactIdentities {
                guard let contactEntity = backgroundBusinessInjector.entityManager.entityFetcher.contact(
                    for: contactIdentity.string
                ) else {
                    DDLogError("[ForwardSecurity] Unable to load contact entity for \(contactIdentity)")
                    continue
                }
                
                // We don't want to cancel any other refresh if one fails
                do {
                    try runSteps(with: contactEntity)
                }
                catch {
                    DDLogWarn("[ForwardSecurity] Refresh steps failed for \(contactIdentity): \(error)")
                }
            }
        }
    }
    
    // This should be called inside a perform block
    private func runSteps(with contactEntity: ContactEntity) throws {
        //    1. If the `contact` does not support FS, abort these sub-steps.
        guard contactEntity.isForwardSecurityAvailable() else {
            return
        }
    
        //    2. Lookup a session with `contact` and let `session` be the result.
        let message: ForwardSecurityEnvelopeMessage
        if let session = try? backgroundBusinessInjector.dhSessionStore.bestDHSession(
            myIdentity: backgroundBusinessInjector.myIdentityStore.identity,
            peerIdentity: contactEntity.identity
        ) {
            //    4. If `session` is not a newly created session, create an `Encapsulated`
            //       message using `session` from inner type `0xfc` (_empty_) and set
            //       `message` to the encrypted and encoded result with type `0xa0`.

            if session.newSessionCommitted {
                message = try backgroundBusinessInjector.fsmp.makeEmptyMessage(for: session)
            }
            else {
                // If we didn't commit the session so far we send an `Init` again
                message = try backgroundBusinessInjector.fsmp.makeInitMessage(for: session)
            }
        }
        else {
            //    3. If `session` is undefined, initiate a new `L20` session and set
            //       `session` to the newly created session. Set `message` to the `Init`
            //       message for `session` with type `0xa0`.
            let contact = ForwardSecurityContact(identity: contactEntity.identity, publicKey: contactEntity.publicKey)
            message = try backgroundBusinessInjector.fsmp.makeNewSession(with: contact)
        }
        
        //    5. Send `message` to `contact` and wait for acknowledgement.
        //    6. Set `session`'s _updated_ mark to the current timestamp and commit the
        //       `session` changes to storage.
        
        // 5. - 7. will all happen in the send abstract message task created here
        backgroundBusinessInjector.messageSender.sendMessage(abstractMessage: message)
    }
}
