//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import Foundation

enum WizardState: Int {
    case terms = 0
    case information
    case preparation
    case identity
    case code
    case success
}

class MultiDeviceWizardViewModel: ObservableObject {
    
    @Published var wizardState: WizardState = .terms {
        didSet {
            stateDidChange(newValue: wizardState)
        }
    }

    @Published var linkingCode = [String]()
    @Published var shouldDismiss = false
    @Published var didTimeout = false
    @Published var didDisconnect = false

    let businessInjector = BusinessInjector()
    let deviceLinker: DeviceLinking
    
    private var prepareLinkingTask: Task<Void, Never>?
    private var linkingTask: Task<Void, Never>?
    var isAdditionalLinking = false

    init() {
        self.deviceLinker = DeviceLinking(businessInjector: businessInjector)
    }
    
    // MARK: - Public Functions

    @MainActor
    public func advanceState(_ state: WizardState) {
        if wizardState != state {
            wizardState = state
        }
    }
    
    public func cancelLinking() {
        Task { @MainActor in
            resetLinking()
        }
    }
    
    // MARK: - Private Functions

    private func stateDidChange(newValue: WizardState) {
        switch newValue {
        case .preparation:
            prepareLinking()
        case .identity:
            if linkingCode.isEmpty {
                shouldDismiss = true
                resetLinking()
            }
        case .code:
            startLinking()
        default:
            return
        }
    }
    
    private func prepareLinking() {

        guard prepareLinkingTask == nil,
              linkingTask == nil else {
            fatalError()
        }
        
        // Create task and assign it
        prepareLinkingTask = Task {
            
            await deviceLinker.blockCommunicationAndDisconnect()
            do {
                if !isAdditionalLinking {
                    // Generate new DGK
                    try deviceLinker.generateDeviceGroupKey()
                }

                // Upload Threema Safe backup
                try await deviceLinker.uploadThreemaSafeBackup()
                
                guard let createdCode = deviceLinker.threemaSafePassword else {
                    fatalError()
                }
                
                // Set values and reset Task
                await setLinkingCode(createdCode.components(withLength: 4))

                await self.advanceState(.identity)
            }
            catch {
                Task { @MainActor in
                    self.cancelLinking()
                    shouldDismiss = true
                }
            }
        }
    }
    
    func startLinking() {

        guard wizardState == .code else {
            return
        }
        
        // This might occur when we go back to identity and forward to code again
        if linkingTask != nil {
            return
        }
        
        linkingTask = Task {
            do {
                try await deviceLinker.connectWaitDoNotUnblockIncomingMessages()

                var linkedDevicesCount: Int?
                if isAdditionalLinking || businessInjector.userSettings.allowSeveralLinkedDevices {
                    linkedDevicesCount = try await deviceLinker.currentLinkedDevicesCount()
                }

                try await deviceLinker.waitForLinkedDevice(currentLinkedDevicesCount: linkedDevicesCount)
                linkingSucceeded()
            }
            catch {
                Task { @MainActor in
                    if case DeviceLinking.DeviceLinkingError.timeout = error {
                        didTimeout = true
                    }
                    else if case DeviceLinking.DeviceLinkingError.couldNotConnect = error {
                        didDisconnect = true
                    }
                    else {
                        prepareLinkingTask = nil
                        linkingTask = nil

                        shouldDismiss = true
                    }
                }
            }
        }
    }
    
    var hasPFSEnabledContacts: Bool {
        !pfsEnabledContacts().isEmpty
    }
    
    func terminateAllPFSSessions() {
        Task {
            do {
                try disablePFS(for: pfsEnabledContacts())
            }
            catch {
                DDLogError("Could not terminate all PFS sessions: \(error)")
            }
        }
    }
    
    private func pfsEnabledContacts() -> [ContactEntity] {
        var pfsEnabledContacts = [ContactEntity]()
        businessInjector.entityManager.performBlockAndWait {
            guard let allContacts = self.businessInjector.entityManager.entityFetcher.allContacts() as? [ContactEntity]
            else {
                return
            }
            
            pfsEnabledContacts.append(contentsOf: allContacts.filter(\.forwardSecurityEnabled.boolValue))
        }
        return pfsEnabledContacts
    }
                                      
    private func disablePFS(for contacts: [ContactEntity]) throws {
        let sessionTerminator = try ForwardSecuritySessionTerminator(businessInjector: businessInjector)
        
        businessInjector.entityManager.performSyncBlockAndSafe {
            for contact in contacts {
                // Disable PFS
                contact.forwardSecurityEnabled = false
                
                // Post system message
                guard let conversation = self.businessInjector.entityManager.entityFetcher
                    .conversation(forIdentity: contact.identity) else {
                    // If we don't have a conversation don't post a system message
                    continue
                }
                guard let systemMessage = self.businessInjector.entityManager.entityCreator
                    .systemMessage(for: conversation) else {
                    DDLogNotice("Unable to create system message for changing PFS state")
                    continue
                }
                systemMessage.type = NSNumber(value: kSystemMessageFsDisabledOutgoing)
                conversation.lastMessage = systemMessage
                conversation.lastUpdate = Date()
                
                // Terminate existing session
                do {
                    try sessionTerminator.terminateAllSessions(with: contact)
                }
                catch {
                    DDLogError("An error occurred while terminating session with \(contact.identity): \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func setLinkingCode(_ code: [String]) async {
        linkingCode = code
    }
    
    private func resetLinking() {
        
        // Reset Settings
        if !isAdditionalLinking {
            businessInjector.serverConnector.deactivateMultiDevice()
        }

        wizardState = .terms
        
        // Local clean-up
        prepareLinkingTask?.cancel()
        prepareLinkingTask = nil
        
        linkingTask?.cancel()
        linkingTask = nil

        Task {
            await setLinkingCode([])
        }
        
        // Linking clean-up
        deviceLinker.deleteThreemaSafeBackup()
        reconnect()
    }
    
    private func linkingSucceeded() {
        
        Task { @MainActor in
            advanceState(.success)
        }
        
        // Local clean-up
        prepareLinkingTask?.cancel()
        prepareLinkingTask = nil
        
        linkingTask?.cancel()
        linkingTask = nil

        Task {
            await setLinkingCode([])
        }

        // Linking clean-up
        deviceLinker.deleteThreemaSafeBackup()
        reconnect()
        
        // Update feature mask to disable forward secrecy
        FeatureMask.updateMask {
            // Terminate all existing sessions
            // Contacts will react by fetching new feature mask
            self.terminateAllPFSSessions()
        }
    }
    
    // Unblocks and reconnects to appropriate server
    private func reconnect() {
        Task { @MainActor in
            await deviceLinker.disconnect()
            deviceLinker.unblockCommunication()
            try? await deviceLinker.connectWait()

            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationMultiDeviceWizardDidUpdate),
                object: nil
            )
        }
    }
}

extension String {
    fileprivate func components(withLength length: Int) -> [String] {
        stride(from: 0, to: count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }
}
