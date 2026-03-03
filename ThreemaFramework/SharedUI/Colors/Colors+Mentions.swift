//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

extension Colors {
    private class var backgroundMention: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    private class var backgroundMentionOwnMessage: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray600)
        }
    }
    
    private class var backgroundMentionOverviewMessage: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    @objc public class var backgroundMentionMe: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundMentionMeOwnMessage: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundMentionMeOverviewMessage: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
}
