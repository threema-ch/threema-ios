//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import Intents
import IntentsUI

import ThreemaEssentials

extension ContactEntity {
    
    /// This only means it's a verified contact from the admin (in the same work package)
    /// To check if this contact is a work ID, use the workidentities list in usersettings
    /// bad naming because of the history...
    public var isWorkContact: Bool {
        workContact?.boolValue ?? false
    }
    
    @objc public var isActive: Bool {
        contactState == .active
    }
    
    @objc public var isValid: Bool {
        contactState != .invalid
    }
    
    public var isForwardSecurityAvailable: Bool {
        (Int(truncating: featureMask) & Int(FEATURE_MASK_FORWARD_SECURITY)) != 0
    }
    
    /// Is this contact blocked?
    public var isBlocked: Bool {
        // User settings should only be used for fast access to this settings. Use `SettingsStore`
        // otherwise to automatically synchronize the setting when multi-device is enabled.
        UserSettings.shared().blacklist.contains(identity as Any)
    }
    
    /// INPerson used for Intents
    public var inPerson: INPerson {
        var localHandles = handles
        let mainHandle = localHandles.remove(at: 0)
        
        let contact = Contact(contactEntity: self)
        let image: UIImage = ProfilePictureGenerator.addBackground(to: contact.profilePicture)
        let inImage = INImage(uiImage: image)
                
        return INPerson(
            personHandle: mainHandle.handle,
            nameComponents: nil,
            displayName: displayName,
            image: inImage,
            contactIdentifier: cnContactID,
            customIdentifier: nil,
            aliases: localHandles.map(\.handle),
            suggestionType: mainHandle.suggestionType
        )
    }
    
    private var handles: [(handle: INPersonHandle, suggestionType: INPersonSuggestionType)] {
        var h = [(INPersonHandle, INPersonSuggestionType)]()
        
        let handle = INPersonHandle(value: identity, type: .unknown)
        let suggestionType: INPersonSuggestionType = .instantMessageAddress
        h.append((handle, suggestionType))
        
        return h
    }
    
    public var threemaIdentity: ThreemaIdentity {
        ThreemaIdentity(identity)
    }
    
    @objc public func setFeatureMask(to mask: Int) {
        // If the new feature mask doesn't support FS anymore terminate all sessions with this contact (& post
        // system message if needed). This prevents that old sessions get never deleted if a contact stops
        // supporting FS, but a terminate is never received. This also prevents a race conditions where we
        // try to establish a session with a contact that doesn't support FS anymore, but the feature mask
        // wasn't locally updated in the meantime. This new session might not be rejected or
        // terminated, because only `Encapsulated` (i.e. data) FS messages are rejected when FS is disabled.
        if !isForwardSecurityAvailable {
            // Check if we actually used a FS session with this contact. If not we still terminate all sessions,
            // but won't post a system message
            let bi = BusinessInjector()
            let fsContact = ForwardSecurityContact(identity: identity, publicKey: publicKey)
            let hasUsedForwardSecurity = bi.fsmp.hasContactUsedForwardSecurity(contact: fsContact)
    
            // Terminate sessions
            // If the contact really disabled FS it won't process the terminate, but we send it anyway just to be sure
            do {
                let deletedAnySession = try ForwardSecuritySessionTerminator().terminateAllSessions(
                    with: self,
                    cause: .disabledByRemote
                )
    
                // Post system message
                if hasUsedForwardSecurity, deletedAnySession, conversations?.count ?? 0 > 0 {
                    let em = BusinessInjector.ui.entityManager
                    em.performAndWaitSave {
                        guard let conversation = em.entityFetcher.conversationEntity(for: self.identity) else {
                            return
                        }
                        let sysMessage = em.entityCreator.systemMessageEntity(
                            for: .fsNotSupportedAnymore,
                            in: conversation
                        )
                        sysMessage.remoteSentDate = .now
                    }
                }
            }
            catch {
                DDLogError("Failed to terminate sessions on downgraded feature mask: \(error)")
            }
            // We will continue even if termination hasn't completed...
        }
    
        // Only update feature mask if actually changed. This prevents that the CD-entity is updated even though the
        // value
        // didn't change.
    
        guard featureMask.intValue != mask else {
            return
        }
    
        featureMask = NSNumber(value: mask)
    }
}
