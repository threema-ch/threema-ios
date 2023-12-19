//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import UIKit

public protocol GroupCallParticipantInfoFetcherProtocol {
    /// Fetches data needed to create a `ViewModelParticipant` for a given Threema-ID-String
    /// - Parameters:
    ///   - id: ThreemaID-String
    /// - Returns: Optional display name, optional avatar and IDColor
    func fetchInfo(id: String) -> (displayName: String?, avatar: UIImage?, color: UIColor)
    
    /// Fetches data needed to create a `ViewModelParticipant` for the local Threema-ID
    /// - Parameters:
    /// - Returns: Optional avatar and IDColor
    func fetchInfoForLocalIdentity() -> (avatar: UIImage?, color: UIColor)
}
