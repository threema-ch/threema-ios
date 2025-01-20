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
import GroupCalls
import ThreemaMacros

@objc public class NavigationBarPromptHandler: NSObject {
    
    @objc public static var isWebActive = false {
        didSet {
            guard isWebActive != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var isCallActiveInBackground = false {
        didSet {
            guard isCallActiveInBackground != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var isGroupCallActive = false {
        didSet {
            guard isGroupCallActive != oldValue else {
                return
            }
            postChangeNotifications()
        }
    }
    
    @objc public static var name: String? = nil
        
    @objc public static func getCurrentPrompt(duration: NSNumber?) -> String? {
        
        if isCallActiveInBackground {
            if let duration {
                return String.localizedStringWithFormat(
                    "%@ - %@",
                    DateFormatter.timeFormatted(duration.intValue),
                    name ?? ""
                )
            }
            else {
                return name
            }
        }
        
        if isGroupCallActive {
            if let name {
                return "\(#localize("group_call_title")): \(name)"
            }
            else {
                return #localize("group_call_title")
            }
        }
        
        if isWebActive {
            return "🖥 " + #localize("settings_threema_web_connected")
        }
        
        return nil
    }
    
    public static func shouldShowPrompt() -> Bool {
        isWebActive || isGroupCallActive || isCallActiveInBackground
    }
    
    private static func postChangeNotifications() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationBarColorShouldChange),
                object: nil
            )
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationNavigationItemPromptShouldChange),
                object: nil
            )
        }
    }
}
