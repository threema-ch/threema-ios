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
import UIKit

public extension Colors {
    @objc class var backgroundChat: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundChatLines: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray500.color
        case .dark:
            return Asset.SharedColors.gray450.color
        }
    }
    
    @objc class var chatBubbleReceived: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray250.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    @objc class var chatBubbleReceivedSelected: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray350.color
        case .dark:
            return Asset.SharedColors.gray550.color
        }
    }
    
    @objc class var backgroundChatBar: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray100.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc class var chatBarInput: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray1000.color
        }
    }
        
    @objc class var thumbUp: UIColor {
        Colors.green
    }
    
    @objc class var thumbDown: UIColor {
        Asset.SharedColors.orange.color
    }
    
    class var messageFailed: UIColor {
        .systemRed
    }
    
    @objc class var backgroundChatSectionHeaderView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray80.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundAudioPlayer: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray100.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    @objc class var backgroundAudioPlayerButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc class var backgroundSpeedButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray300.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc class var backgroundPopupMenu: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.black.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc class var popupMenuHighlight: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray750.color
        case .dark:
            return Asset.SharedColors.gray500.color
        }
    }
    
    @objc class var ballotHighestVote: UIColor {
        .primary
    }
    
    @objc class var ballotRowLight: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc class var ballotRowDark: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray300.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    @objc class var backgroundQuoteBar: UIColor {
        .primary
    }
    
    @objc class var backgroundPinChat: UIColor {
        Asset.SharedColors.pin.color
    }
    
    @objc class var backgroundThumbnailCollectionView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc class var backgroundPreviewCollectionViewCell: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundSystemMessage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray300.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc class var newSystemMessageBackground: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray150.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }

    class var thumbnailProgressViewColor: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray30.color
        case .dark:
            return Asset.SharedColors.gray850.color
        }
    }
}
