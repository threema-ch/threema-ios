//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension SystemMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.localizedMessage
        case let .systemMessage(type: systemType):
            systemType.localizedMessage
        case let .workConsumerInfo(type: workConsumerInfo):
            workConsumerInfo.localizedMessage
        }
    }
    
    public var previewSymbolName: String? {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.symbolName
        default:
            nil
        }
    }
        
    public var previewSymbolTintColor: UIColor? {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.tintColor
        default:
            nil
        }
    }
}
