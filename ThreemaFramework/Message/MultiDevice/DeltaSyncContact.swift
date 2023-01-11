//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

struct DeltaSyncContact: Codable {
    init(syncContact: Sync_Contact, syncAction: SyncAction) {
        self.syncContact = syncContact
        self.syncAction = syncAction
    }

    enum SyncAction: Codable {
        case create, update
    }

    var syncContact: Sync_Contact
    var profilePicture: DeltaUpdateType = .unchanged
    var image: Data?
    var contactProfilePicture: DeltaUpdateType = .unchanged
    var contactImage: Data?
    var syncAction: SyncAction

    private enum CodingKeys: String, CodingKey {
        case syncContact
        case syncAction
        case profilePicture
        case image
        case contactProfilePicture
        case contactImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dataSyncContact = try container.decode(Data.self, forKey: .syncContact)

        self.syncContact = try Sync_Contact(contiguousBytes: dataSyncContact)
        self.syncAction = try container.decode(SyncAction.self, forKey: .syncAction)
        self.profilePicture = try container.decode(DeltaUpdateType.self, forKey: .profilePicture)
        self.image = try? container.decode(Data.self, forKey: .image)
        self.contactProfilePicture = try container.decode(DeltaUpdateType.self, forKey: .contactProfilePicture)
        self.contactImage = try? container.decode(Data.self, forKey: .contactImage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let dataSyncContact = try syncContact.serializedData()

        try container.encode(dataSyncContact, forKey: .syncContact)
        try container.encode(syncAction, forKey: .syncAction)
        try container.encode(profilePicture, forKey: .profilePicture)
        try container.encode(image, forKey: .image)
        try container.encode(contactProfilePicture, forKey: .contactProfilePicture)
        try container.encode(contactImage, forKey: .contactImage)
    }
}
