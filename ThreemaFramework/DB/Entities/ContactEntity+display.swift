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

extension ContactEntity {
    
    /// ID Color for this contact
    ///
    /// The color looks similar on all devices for the same ID.
    public var idColor: UIColor {
        IDColor.forData(Data(identity.utf8))
    }
    
    /// Shorter version of `displayName` if available
    public var shortDisplayName: String {
        // This is an "op-in" feature
        guard ThreemaApp.current == .threema || ThreemaApp.current == .green else {
            return displayName
        }
        
        if let firstName, !firstName.isEmpty {
            return firstName
        }
        
        return displayName
    }
    
    /// Could an other-Threema-type-icon be shown next to this contact?
    ///
    /// Most of the time it's most appropriate to show or hide an `OtherThreemaTypeImageView`.
    @objc public var showOtherThreemaTypeIcon: Bool {
        if isEchoEcho() || isGatewayID() || ThreemaApp.current == .onPrem {
            return false
        }
        
        if ThreemaApp.current == .work || ThreemaApp.current == .blue {
            return !UserSettings.shared().workIdentities.contains(identity)
        }
        else {
            return UserSettings.shared().workIdentities.contains(identity)
        }
    }
}
