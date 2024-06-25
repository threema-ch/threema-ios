//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import ThreemaEssentials
import UIKit

public protocol GroupCallParticipantInfoFetcherProtocol {
    
    /// Fetches the avatar image of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: Avatar image if it exists
    func fetchAvatar(for id: ThreemaIdentity) -> UIImage?
    
    /// Fetches the display name of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: Display name (might also be the ID-string)
    func fetchDisplayName(for id: ThreemaIdentity) -> String
    
    /// Fetches the ID Color of a contact for the given ThreemaIdentity
    /// - Parameter id: ThreemaIdentity
    /// - Returns: ID Color or primary color
    func fetchIDColor(for id: ThreemaIdentity) -> UIColor
}
