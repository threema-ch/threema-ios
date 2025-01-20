//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

class WebCreateGroupRequest: WebAbstractMessage {
    
    let members: [String]
    let name: String?
    let avatar: Data?
    
    override init(message: WebAbstractMessage) {
        let data = message.data as! [AnyHashable: Any?]
        self.members = data["members"] as! [String]
        self.name = data["name"] as? String
        self.avatar = data["avatar"] as? Data
        super.init(message: message)
    }
}
