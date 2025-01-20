//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros

extension SystemMessageEntity: MessageAccessibility {
    
    public var privateCustomAccessibilityLabel: String {
        
        switch systemMessageType {
        case let .callMessage(type: call):
            var localizedLabel = call.localizedMessage
            
            if let duration = callDuration() {
                let durationString = String.localizedStringWithFormat(
                    #localize("call_duration"),
                    duration
                )
                localizedLabel.append(durationString)
            }
            
            return "\(localizedLabel)."
            
        case let .workConsumerInfo(type: wcInfo):
            return String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_systemMessage"),
                wcInfo.localizedMessage
            )
            
        case let .systemMessage(type: infoType):
            return String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_systemMessage"),
                infoType.localizedMessage
            )
        }
    }
    
    public var customAccessibilityHint: String? {
        switch systemMessageType {
        case .callMessage:
            #localize("accessibility_systemCallMessage_hint")
        case .workConsumerInfo, .systemMessage:
            nil
        }
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        switch systemMessageType {
        case .callMessage:
            [.button, .staticText]
            
        case .workConsumerInfo, .systemMessage:
            [.staticText, .notEnabled]
        }
    }
    
    public var accessibilityMessageTypeDescription: String {
        // The other system message types do not need a description
        guard case .callMessage = systemMessageType else {
            return ""
        }
        
        return #localize("accessibility_systemCallMessage_description")
    }
}
