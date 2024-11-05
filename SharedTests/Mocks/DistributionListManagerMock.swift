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

import Foundation
import ThreemaFramework

class DistributionListManagerMock: NSObject, DistributionListManagerProtocol {
    func createDistributionList(
        conversation: ConversationEntity,
        name: String,
        imageData: Data?,
        recipients: Set<Contact>
    ) throws {
        // No-op
    }
    
    func distributionList(for conversation: ConversationEntity) -> DistributionList? {
        nil
    }

    func setProfilePicture(of distributionList: ThreemaFramework.DistributionList, to profilePicture: Data?) {
        // No-op
    }
    
    func setName(of distributionList: ThreemaFramework.DistributionList, to name: String) {
        // No-op
    }
    
    func setRecipients(of distributionList: ThreemaFramework.DistributionList, to recipients: Set<Contact>) {
        // No-op
    }
}
