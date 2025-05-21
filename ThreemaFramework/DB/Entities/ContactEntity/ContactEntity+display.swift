//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaMacros

extension ContactEntity {
    
    /// ID Color for this contact
    ///
    /// The color looks similar on all devices for the same ID.
    public var idColor: UIColor {
        IDColor.forData(Data(identity.utf8))
    }
    
    @objc public var displayName: String {
        guard var displayName = ContactUtil.name(fromFirstname: firstName, lastname: lastName) as? String else {
            return #localize("(unknown)")
        }
        
        if displayName.isEmpty, let publicNickname, !publicNickname.isEmpty, publicNickname != identity {
            displayName = "~\(publicNickname)"
        }
        
        if displayName.isEmpty {
            displayName = identity
        }
        
        switch contactState {
            
        case .active:
            break
        case .inactive:
            displayName = "\(displayName) (\(#localize("inactive")))"
        case .invalid:
            displayName = "\(displayName) (\(#localize("invalid")))"
        }
        
        return displayName
    }
    
    /// Shorter version of `displayName` if available
    public var shortDisplayName: String {
        // This is an "op-in" feature
        guard !TargetManager.isBusinessApp else {
            return displayName
        }
        
        if let firstName, !firstName.isEmpty {
            return firstName
        }
        
        return displayName
    }
    
    @objc public var attributedDisplayName: NSAttributedString {
        var attributedNameString = NSMutableAttributedString(string: displayName)
        
        // Check style for the title
        if contactState == .invalid {
            // Contact is invalid
            attributedNameString.addAttribute(
                .strikethroughStyle,
                value: 2,
                range: NSMakeRange(0, attributedNameString.length)
            )
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.secondaryLabel,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        else if contactState == .inactive {
            // Contact is inactive
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.secondaryLabel,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        else {
            attributedNameString.addAttribute(
                .foregroundColor,
                value: UIColor.label,
                range: NSMakeRange(0, attributedNameString.length)
            )
        }
        
        if UserSettings.shared().blacklist.contains(identity) {
            // Contact is blacklisted
            attributedNameString = NSMutableAttributedString(string: "🚫 " + attributedNameString.string)
        }

        return attributedNameString
    }
    
    @objc public var mentionName: String {
        guard var mentionName = ContactUtil.name(fromFirstname: firstName, lastname: lastName) as? String else {
            return identity
        }
        
        if mentionName.isEmpty, let publicNickname, !publicNickname.isEmpty, publicNickname != identity {
            mentionName = "~\(publicNickname)"
        }
        
        if mentionName.isEmpty {
            mentionName = identity
        }
        
        if mentionName.count > 24 {
            mentionName = String(mentionName.prefix(24))
        }
        
        return mentionName
    }
    
    /// Could an other-Threema-type-icon be shown next to this contact?
    ///
    /// Most of the time it's most appropriate to show or hide an `OtherThreemaTypeImageView`.
    @objc public var showOtherThreemaTypeIcon: Bool {
        if isEchoEcho || isGatewayID || TargetManager.isOnPrem {
            return false
        }
        
        if TargetManager.isWork {
            return !UserSettings.shared().workIdentities.contains(identity)
        }
        else {
            return UserSettings.shared().workIdentities.contains(identity)
        }
    }
}
