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

enum AppSetupStepsError: Error {
    /// A request timed out
    case timeout
    /// An empty error was returned
    case unknownError
}

/// Implementation of the Threema Protocols _Application Setup Steps_
///
/// These steps must be run and successfully complete when a new Threema ID has been created or when application state
/// has been restored from a backup.
public struct AppSetupSteps: Sendable {

    private let backgroundBusinessInjector: FrameworkInjectorProtocol
    // TODO: (IOS-4567) Remove
    private let taskManager: TaskManagerProtocol
    private let featureMask: FeatureMaskProtocol.Type
    private let contactPhotoSender: ContactPhotoSenderProtocol.Type
    
    public init() {
        let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)
        self.init(
            backgroundBusinessInjector: backgroundBusinessInjector,
            taskManger: TaskManager(
                backgroundEntityManager: backgroundBusinessInjector.entityManager,
                serverConnector: backgroundBusinessInjector.serverConnector
            ),
            featureMask: FeatureMask.self,
            contactPhotoSender: ContactPhotoSender.self
        )
    }
    
    init(
        backgroundBusinessInjector: FrameworkInjectorProtocol,
        taskManger: TaskManagerProtocol,
        featureMask: FeatureMaskProtocol.Type,
        contactPhotoSender: ContactPhotoSenderProtocol.Type
    ) {
        self.backgroundBusinessInjector = backgroundBusinessInjector
        self.taskManager = taskManger
        self.featureMask = featureMask
        self.contactPhotoSender = contactPhotoSender
    }
    
    /// Run _Application Setup Steps_ as defined by Threema Protocols
    public func run() async throws {
        DDLogNotice("Start App Setup Steps")
        defer { DDLogNotice("Exit App Setup Steps") }
        
        // The following steps are defined as _Application Setup Steps_ and must be run
        // when a new Threema ID has been created or when application state has been
        // restored from a backup:
        
        // 2. If application state has not been set up by the _Device Join Protocol_
        //    (meaning that multi-device is deactivated):
        guard !backgroundBusinessInjector.settingsStore.isMultiDeviceRegistered else {
            DDLogNotice("App Setup Steps called with multi-device registered")
            return
        }
        
        // 2.  Update the user's feature mask on the directory server.
        DDLogNotice("Update own feature mask")
        try await featureMask.updateLocal()
        
        // 3.  Let `contacts` be the list of all contacts, including those with an
        //     acquaintance level different than `DIRECT`.
        // 4.  Refresh the state, type and feature mask of all `contacts` from the
        //     directory server and make any changes persistent.
        
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
            if let error {
                throw error
            }
            else {
                throw AppSetupStepsError.unknownError
            }
        case .timeout:
            DDLogWarn("Contact status update time out")
            assertionFailure()
            // We just continue if this happens for now. Because `ContactStore` is heavily based on completion and error
            // closures and we don't have a full guarantee that this will ever resume.
        }

        // 5.  Let `solicited-contacts` be a copy of `contacts` [...]
        DDLogNotice("Fetch solicited contacts")
        let solicitedContactIdentities = await backgroundBusinessInjector.entityManager.perform {
            backgroundBusinessInjector.entityManager.entityFetcher.allSolicitedContactIdentities()
        }
        
        DDLogNotice("Fetched \(solicitedContactIdentities.count) solicited contacts")
        
        // 6.  If FS is supported by the client, run the _FS Refresh Steps_ with
        //     `solicited-contacts`.
        // In general FS should always be supported
        if ThreemaEnvironment.supportsForwardSecurity, !solicitedContactIdentities.isEmpty {
            DDLogNotice("Run FS refresh steps...")
            await ForwardSecurityRefreshSteps(
                backgroundBusinessInjector: backgroundBusinessInjector,
                taskManager: taskManager
            ).run(for: solicitedContactIdentities.map {
                ThreemaIdentity($0)
            })
        }
        
        // 7.  Send a `contact-request-profile-picture` message to each
        //     contact of `solicited-contacts`.
        // TODO: (IOS-4567) This was disabled to prevent a task creation explosion when there are many contacts.
        // TODO: Reenable this when we improve the task persistence (IOS-4567).
        // TODO: In the meantime we only schedule profile picture requests when Safe was used to restore the ID.
        // DDLogNotice("Send contact request profile picture messages")
        // for solicitedContactIdentity in solicitedContactIdentities {
        //     contactPhotoSender.sendProfilePictureRequest(solicitedContactIdentity)
        // }
        
        // 8.  For each group not marked as _left_:
        //     1. If the user is the creator of the group, trigger a _group sync_
        //        for that group.
        //     2. If the user is not the creator of the group, send a
        //        [`group-sync-request`](ref:e2e.group-sync-request) message to the
        //        creator of the group.
        let allActiveGroups = await backgroundBusinessInjector.groupManager.getAllActiveGroups()
        DDLogNotice("Refresh \(allActiveGroups.count) active groups")
        for group in allActiveGroups {
            if group.isOwnGroup {
                Task {
                    do {
                        try await backgroundBusinessInjector.groupManager.sync(group: group)
                    }
                    catch {
                        DDLogError("Failed so sync group (\(group.groupIdentity): \(error). Continue...")
                    }
                }
            }
            else {
                // Sync is not force if there was another request sent recently. We don't expect this to be the case,
                // because this is run at the end of a setup.
                backgroundBusinessInjector.groupManager.sendSyncRequest(for: group.groupIdentity)
            }
        }
        
        // 3. Commit the application state and exit the setup phase.
    }
}
