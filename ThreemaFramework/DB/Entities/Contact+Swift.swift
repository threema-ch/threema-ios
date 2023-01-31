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
import Intents

public extension Contact {
    /// Is this contact blocked?
    var isBlocked: Bool {
        // User settings should only be used for fast access to this settings. Use `SettingsStore`
        // otherwise to automatically synchronize the setting when multi-device is enabled.
        UserSettings.shared().blacklist.contains(identity as Any)
    }
    
    /// INPerson used for Intents
    var inPerson: INPerson {
        var handles = handles
        let mainHandle = handles.remove(at: 0)
        
        let avatar: INImage?
        if let imageData = contactImage?.data {
            avatar = INImage(imageData: imageData)
        }
        else if let imageData = imageData {
            avatar = INImage(imageData: imageData)
        }
        else {
            if let imageData = AvatarMaker().avatar(for: self, size: 50, masked: true, scaled: true)
                .jpegData(compressionQuality: 0.75) {
                avatar = INImage(imageData: imageData)
            }
            else {
                DDLogError("Could not create avatar for contact")
                avatar = nil
            }
        }
        
        let inPersonName = BusinessInjector().userSettings.pushShowNickname ? (publicNickname ?? identity) : displayName
        
        return INPerson(
            personHandle: mainHandle.handle,
            nameComponents: nil,
            displayName: inPersonName,
            image: avatar,
            contactIdentifier: cnContactID,
            customIdentifier: "3ma-\(identity)",
            aliases: handles.map(\.handle),
            suggestionType: mainHandle.suggestionType
        )
    }
    
    private var handles: [(handle: INPersonHandle, suggestionType: INPersonSuggestionType)] {
        var h = [(INPersonHandle, INPersonSuggestionType)]()
        
        if let verifiedMobileNo = verifiedMobileNo, !verifiedMobileNo.isEmpty {
            let handle = INPersonHandle(value: verifiedMobileNo, type: .phoneNumber)
            let suggestionType: INPersonSuggestionType = .none
            h.append((handle, suggestionType))
        }
        if let verifiedEmail = verifiedEmail, !verifiedEmail.isEmpty {
            let handle = INPersonHandle(value: verifiedEmail, type: .emailAddress)
            let suggestionType: INPersonSuggestionType = .none
            h.append((handle, suggestionType))
        }
        
        let handle = INPersonHandle(value: identity, type: .unknown)
        let suggestionType: INPersonSuggestionType = .instantMessageAddress
        h.append((handle, suggestionType))
        
        return h
    }
}
