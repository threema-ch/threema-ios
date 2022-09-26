//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@objc class TaskDefinitionSendLocationMessage: TaskDefinitionSendBaseMessage {
    override var description: String {
        "<\(type(of: self))>"
    }
    
    @objc var poiAddress: String?
    
    private enum CodingKeys: String, CodingKey {
        case poiAddress
    }
    
    @objc init(poiAddress: String?, message: BaseMessage, sendContactProfilePicture: Bool) {
        self.poiAddress = poiAddress
        super.init(message: message, group: nil, sendContactProfilePicture: sendContactProfilePicture)
    }

    @objc init(poiAddress: String?, message: BaseMessage, group: Group?, sendContactProfilePicture: Bool) {
        self.poiAddress = poiAddress
        super.init(message: message, group: group, sendContactProfilePicture: sendContactProfilePicture)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)

        self.poiAddress = try? container.decode(String.self, forKey: .poiAddress)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(poiAddress, forKey: .poiAddress)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
