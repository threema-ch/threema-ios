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
    private let featureMask: FeatureMaskProtocol.Type

    public init() {
        self.init(
            backgroundBusinessInjector: BusinessInjector(forBackgroundProcess: true),
            featureMask: FeatureMask.self
        )
    }
    
    init(backgroundBusinessInjector: FrameworkInjectorProtocol, featureMask: FeatureMaskProtocol.Type) {
        self.backgroundBusinessInjector = backgroundBusinessInjector
        self.featureMask = featureMask
    }
    
    /// Run _Application Update Steps_ as defined by Threema Protocols
    public func run() async throws {
        // TODO: (IOS-4425) This _might_ also be integrated in a new `ContactStore` providing a new `runApplicationUpdateSteps()` function
        DDLogNotice("Start App Update Steps")
        defer { DDLogNotice("Exit App Update Steps") }
        
        // The following steps are defined as _Application Update Steps_ and must be
        // run as a persistent task when the application has just been updated to a new
        // version or downgraded to a previous version:
        
        // 2. Update the user's feature mask on the directory server.
        try await featureMask.updateLocal()
        
        // 3. Let `contacts` be the list of all contacts (regardless of the acquaintance level).
        // 4. Refresh the state, type and feature mask of all `contacts` from the
        //    directory server and make any changes persistent.
        
        do {
            DDLogNotice("Contact status update start")
            
            let updateTask: Task<Void, Error> = Task {
                try await backgroundBusinessInjector.contactStore.updateStatusForAllContacts(ignoreInterval: true)
            }
            
            // The request time out is 30s thus we wait for 40s for it to complete
            switch try await Task.timeout(updateTask, 40) {
            case .result:
                break
            case let .error(error):
                DDLogError("Contact status update error: \(error ?? "nil")")
            case .timeout:
                DDLogWarn("Contact status update time out")
            }
        }
        catch {
            // We should still try the next steps if this fails and don't report this error back to the caller
            DDLogWarn("Contact status update error: \(error)")
        }
        
        // 5. For each `contact` of `contacts`:
        //    1. If an associated FS session with `contact` exists and any of the FS
        //       states is unknown or any of the stored FS versions (local or remote)
        //       is unknown, terminate the FS session by sending a
        //       `csp-e2e-fs.Terminate` message with cause `RESET`.
        
        let terminator = try ForwardSecuritySessionTerminator(
            businessInjector: backgroundBusinessInjector,
            store: backgroundBusinessInjector.dhSessionStore
        )
        
        let allContactIdentities = await backgroundBusinessInjector.entityManager.perform {
            backgroundBusinessInjector.entityManager.entityFetcher.allContactIdentities()
        }
        
        for contactIdentity in allContactIdentities {
            await validateSessionsAndTerminateIfNeeded(with: contactIdentity, using: terminator)
        }
    }
    
    // MARK: - Private helper
    
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
        await backgroundBusinessInjector.entityManager.performSave {
            if let conversation = backgroundBusinessInjector.entityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: false,
                setLastUpdate: false
            ) {
                let systemMessage = backgroundBusinessInjector.entityManager.entityCreator.systemMessageEntity(
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
