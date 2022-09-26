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

public extension Colors {
    private class var backgroundMention: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray500.color
        }
    }
    
    private class var backgroundMentionOwnMessage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray600.color
        }
    }
    
    private class var backgroundMentionOverviewMessage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray500.color
        }
    }
    
    @objc class var backgroundMentionMe: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray600.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc class var backgroundMentionMeOwnMessage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray600.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc class var backgroundMentionMeOverviewMessage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray600.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc class func backgroundMention(messageInfo: TextStyleUtilsMessageInfo) -> UIColor {
        switch messageInfo {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return backgroundMention
        case TextStyleUtilsMessageInfoOwnMessage:
            return backgroundMentionOwnMessage
        case TextStyleUtilsMessageInfoOverview:
            return backgroundMentionOverviewMessage
        default:
            return backgroundMention
        }
    }
    
    @objc class func backgroundMentionMe(messageInfo: TextStyleUtilsMessageInfo) -> UIColor {
        switch messageInfo {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return backgroundMentionMe
        case TextStyleUtilsMessageInfoOwnMessage:
            return backgroundMentionMeOwnMessage
        case TextStyleUtilsMessageInfoOverview:
            return backgroundMentionMeOverviewMessage
        default:
            return backgroundMentionMe
        }
    }
    
    @objc class func textMentionMe(messageInfo: TextStyleUtilsMessageInfo) -> UIColor {
        switch messageInfo {
        case TextStyleUtilsMessageInfoReceivedMessage:
            return textMentionMe
        case TextStyleUtilsMessageInfoOwnMessage:
            return textMentionMeOwnMessage
        case TextStyleUtilsMessageInfoOverview:
            return textMentionMeOverviewMessage
        default:
            return textMentionMe
        }
    }
}
