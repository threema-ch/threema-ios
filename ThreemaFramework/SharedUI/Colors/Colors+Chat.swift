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
import UIKit

extension Colors {
    
    public class var backgroundChatLines: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray450)
        }
    }
    
    public class func backgroundChatLines(colorTheme: Theme) -> UIColor {
        switch colorTheme {
        case .light, .undefined:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray450)
        }
    }
            
    public class var backgroundChatBar: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray100)
        case .dark:
            UIColor(resource: .gray900)
        }
    }
    
    public class var chatBarInput: UIColor {
        switch theme {
        case .light, .undefined:
            .white
        case .dark:
            UIColor(resource: .gray1000)
        }
    }
    
    public class var messageFailed: UIColor {
        .systemRed
    }
    
    @objc public class var fillMicrophoneButton: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray600)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var ballotHighestVote: UIColor {
        .primary
    }
    
    @objc public class var ballotRowLight: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray200)
        case .dark:
            UIColor(resource: .gray700)
        }
    }
    
    @objc public class var ballotRowDark: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray300)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
        
    public class var backgroundThumbnailCollectionView: UIColor {
        switch theme {
        case .light, .undefined:
            .white
        case .dark:
            UIColor(resource: .gray900)
        }
    }
    
    public class var backgroundPreviewCollectionViewCell: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray200)
        case .dark:
            .black
        }
    }

    public class var thumbnailProgressViewColor: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray30)
        case .dark:
            UIColor(resource: .gray850)
        }
    }
    
    public class var chatReactionBubble: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray300)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    public class var chatReactionBubbleSelected: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray550)
        }
    }

    public class var chatReactionBubbleHighlighted: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray350)
        case .dark:
            UIColor(resource: .gray500)
        }
    }
    
    public class var chatReactionBubbleTextColor: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray750)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    public class var chatReactionBubbleBorder: UIColor {
        UIColor.systemBackground
    }
}
