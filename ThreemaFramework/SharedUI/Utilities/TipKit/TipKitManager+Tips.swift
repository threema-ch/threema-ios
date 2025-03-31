//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import TipKit

@available(iOSApplicationExtension 17.0, *)
extension TipKitManager {
    
    /// Tip shown when type icon is show for first time
    public struct ThreemaTypeTip: Tip {
        public var title: Text {
            if TargetManager.isBusinessApp {
                Text(#localize("contact_threema_title"))
            }
            else {
                Text(#localize("contact_threema_work_title"))
            }
        }

        public var message: Text? {
            if TargetManager.isBusinessApp {
                Text(#localize("contact_threema_info"))
            }
            else {
                Text(#localize("contact_threema_work_info"))
            }
        }

        public var image: Image? {
            Image(uiImage: ThreemaUtility.otherThreemaTypeIcon)
        }

        public init() { }
    }
    
    /// Tip shown for users using TestFlight
    public struct ThreemaBetaFeedbackTip: Tip {
        public var title: Text {
            Text(#localize("testflight_feedback_title"))
        }

        public var message: Text? {
            Text(#localize("testflight_feedback_description"))
        }

        public var image: Image? {
            Image(systemName: "ant.fill")
        }

        public init() { }
    }
    
    /// Tip shown when first receive a reaction
    public struct ThreemaReactionLongPressInfoTip: Tip {
        public var title: Text {
            Text(#localize("emoji_reaction_tipkit_title"))
        }

        public var message: Text? {
            Text(#localize("emoji_reaction_tipkit_description"))
        }

        public var image: Image? {
            Image(systemName: "hand.tap")
        }
        
        public var options: [any Option] {
            MaxDisplayCount(2)
        }
        
        public init() { }
    }
}
