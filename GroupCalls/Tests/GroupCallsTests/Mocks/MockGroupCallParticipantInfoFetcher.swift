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
@testable import GroupCalls

final class MockGroupCallParticipantInfoFetcher { }

// MARK: - GroupCallParticipantInfoFetcherProtocol

extension MockGroupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol {
    func fetchProfilePicture(for id: ThreemaEssentials.ThreemaIdentity) -> UIImage {
        UIImage(systemName: "person.fill")!
    }
    
    func fetchDisplayName(for id: ThreemaEssentials.ThreemaIdentity) -> String {
        id.string
    }
    
    func fetchIDColor(for id: ThreemaEssentials.ThreemaIdentity) -> UIColor {
        UIColor.red
    }
    
    func isIdentity(_ identity: ThreemaIdentity, memberOfGroupWith groupID: GroupIdentity) -> Bool {
        true
    }
}
