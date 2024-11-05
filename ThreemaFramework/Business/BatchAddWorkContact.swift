//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

class BatchAddWorkContact: NSObject {
    let identity: String
    let publicKey: Data?
    let firstName: String?
    let lastName: String?
    let csi: String?
    let jobTitle: String?
    let department: String?
    
    @objc required init(
        identity: String,
        publicKey: Data?,
        firstName: String?,
        lastName: String?,
        csi: String?,
        jobTitle: String?,
        department: String?
    ) {
        self.identity = identity
        self.publicKey = publicKey
        self.firstName = firstName
        self.lastName = lastName
        self.csi = csi
        self.jobTitle = jobTitle
        self.department = department
    }
    
    override var description: String {
        "\(identity): \(firstName ?? "no firstname set") \(lastName ?? "no lastname set"), \(csi ?? "no csi set"), \(jobTitle ?? "no job title set"), \(department ?? "no department set")"
    }
}
