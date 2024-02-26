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

/// Implementation of the Threema Protocols _Application Update Steps_
public struct AppUpdateSteps {
    
    private let backgroundBusinessInjector: FrameworkInjectorProtocol
    
    public init() {
        self.init(backgroundBusinessInjector: BusinessInjector())
    }
    
    init(backgroundBusinessInjector: FrameworkInjectorProtocol) {
        self.backgroundBusinessInjector = backgroundBusinessInjector
    }
    
    /// Run _Application Update Steps_ as defined by Threema Protocols
    public func run(completion: @escaping () -> Void) {
        // TODO: (IOS-4425) This _might_ also be integrated in a new `ContactStore` providing a new `runApplicationUpdateSteps()` function
        
        // The following steps are defined as _Application Update Steps_ and must be
        // run as a persistent task when the application has just been updated to a new
        // version or downgraded to a previous version:
        
        // 2. Let `contacts` be the list of all contacts (regardless of the acquaintance level).
        // 3. Refresh the state, type and feature mask of all `contacts` from the
        //    directory server and make any changes persistent.
        backgroundBusinessInjector.contactStore.synchronizeAddressBook(
            forceFullSync: false,
            ignoreMinimumInterval: true
        ) { _ in
            runFourthStep(completion: completion)
        } onError: { error in
            DDLogWarn("Address book sync failed: \(error ?? NSError())")
            // We should still try the next step if this fails
            runFourthStep(completion: completion)
        }
    }
    
    // MARK: - Private helper
    
    private func runFourthStep(completion: @escaping () -> Void) {
        // 4. For each `contact` of `contacts`:
        //    1. If an associated FS session with `contact` exists and any of the FS
        //       states is unknown or any of the stored FS versions (local or remote)
        //       is unknown, terminate the FS session by sending a
        //       `csp-e2e-fs.Terminate` message.
        Task {
            do {
                let terminator = try ForwardSecuritySessionTerminator(
                    businessInjector: backgroundBusinessInjector,
                    store: backgroundBusinessInjector.dhSessionStore
                )
                
                let allContactIdentities = await backgroundBusinessInjector.backgroundEntityManager.perform {
                    backgroundBusinessInjector.backgroundEntityManager.entityFetcher.allContactIdentities()
                }
                
                for contactIdentity in allContactIdentities {
                    await validateSessionsAndTerminateIfNeeded(with: contactIdentity, using: terminator)
                }
                
                completion()
            }
            catch {
                DDLogError("[ForwardSecurity] Failed to run fourth step")
                completion()
            }
        }
    }
    
    private func validateSessionsAndTerminateIfNeeded(
        with contactIdentity: String,
        using terminator: ForwardSecuritySessionTerminator
    ) async {
        do {
            if try backgroundBusinessInjector.dhSessionStore.hasInvalidDHSessions(
                myIdentity: backgroundBusinessInjector.myIdentityStore.identity,
                peerIdentity: contactIdentity
            ) {
                DDLogNotice("[ForwardSecurity] Terminate sessions with \(contactIdentity)")
                
                try terminator.terminateAllSessions(with: contactIdentity, cause: .reset)
                
                await postSystemMessage(for: contactIdentity)
            }
        }
        catch {
            DDLogWarn("[ForwardSecurity] Unable to get validity of sessions with \(contactIdentity): \(error)")
        }
    }
    
    private func postSystemMessage(for contactIdentity: String) async {
        await backgroundBusinessInjector.backgroundEntityManager.performSave {
            if let conversation = backgroundBusinessInjector.backgroundEntityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: false,
                setLastUpdate: false
            ) {
                let systemMessage = backgroundBusinessInjector.backgroundEntityManager.entityCreator.systemMessage(
                    for: conversation
                )
                systemMessage?.type = NSNumber(value: kSystemMessageFsIllegalSessionState)
                systemMessage?.remoteSentDate = Date()
                if systemMessage?.isAllowedAsLastMessage ?? false {
                    conversation.lastMessage = systemMessage
                }
            }
            else {
                DDLogNotice("[ForwardSecurity] Can't add status message because conversation is nil")
            }
        }
    }
}
