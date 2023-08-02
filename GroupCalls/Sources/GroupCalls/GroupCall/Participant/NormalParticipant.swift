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

// TODO: IOS-3728 Clean this up if not needed in the end
class NormalParticipant: Participant, NormalParticipantDescription, Sendable {
    let contactModel: ContactModel
    let identity: String
    let nickname: String
    
    init(id: ParticipantID, contactModel: ContactModel, threemaID: ThreemaID) {
        self.contactModel = contactModel
        // TODO: Implement
//        self.identity = contactModel.identity
//        self.nickname = contactModel.publicNickName ?? contactModel.identity
        self.identity = threemaID.id
        self.nickname = threemaID.id
        super.init(id: id)
    }
    
    override var name: String {
        ""
    }
}
