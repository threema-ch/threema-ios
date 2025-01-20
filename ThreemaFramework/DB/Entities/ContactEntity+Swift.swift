//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
    /// Is this contact blocked?
    public var isBlocked: Bool {
        // User settings should only be used for fast access to this settings. Use `SettingsStore`
        // otherwise to automatically synchronize the setting when multi-device is enabled.
        UserSettings.shared().blacklist.contains(identity as Any)
    }
    
    /// INPerson used for Intents
    public var inPerson: INPerson {
        var handles = handles
        let mainHandle = handles.remove(at: 0)
        
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
            aliases: handles.map(\.handle),
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
    
    @objc func updateSortInitial() {
        if isGatewayID() {
            sortInitial = .broadcasts
            sortIndex = NSNumber(value: ThreemaLocalizedIndexedCollation.sectionTitles.count - 1)
        }
        else {
            // find the first keyPath where the length is greater than 0, fallback to identity
            let str = ([\ContactEntity.firstName, \.lastName].then {
                UserSettings.shared().sortOrderFirstName ? { }() : $0.reverse()
            } + [\.publicNickname, \.identity]).first {
                ((self[keyPath: $0] as? String)?.count ?? 0) > 0
            }.map {
                self[keyPath: $0] as? String
            }
            
            guard case let str?? = str else {
                return
            }
            
            let idx = ThreemaLocalizedIndexedCollation.section(for: str)
            let sortInitial = ThreemaLocalizedIndexedCollation.sectionTitles[idx]
            let sortIndex = NSNumber(value: idx)
            
            if self.sortInitial != sortInitial {
                self.sortInitial = sortInitial
            }
            if self.sortIndex != sortIndex {
                self.sortIndex = sortIndex
            }
        }
    }
}
