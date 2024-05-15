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

extension Colors {
    
    public class var backgroundChatLines: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray500.color
        case .dark:
            return Asset.SharedColors.gray450.color
        }
    }
    
    public class func backgroundChatLines(colorTheme: Theme) -> UIColor {
        switch colorTheme {
        case .light, .undefined:
            return Asset.SharedColors.gray500.color
        case .dark:
            return Asset.SharedColors.gray450.color
        }
    }
    
    public class var chatBubbleReceived: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray250.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    public class var chatBubbleReceivedSelected: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray350.color
        case .dark:
            return Asset.SharedColors.gray550.color
        }
    }
    
    public class var backgroundChatBar: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray100.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    public class var chatBarInput: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray1000.color
        }
    }
        
    public class var thumbUp: UIColor {
        Colors.green
    }
    
    public class var thumbDown: UIColor {
        Asset.SharedColors.orange.color
    }
    
    public class var messageFailed: UIColor {
        .systemRed
    }
    
    @objc public class var backgroundAudioPlayer: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray100.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    @objc public class var backgroundAudioPlayerButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc public class var backgroundSpeedButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray300.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc public class var fillMicrophoneButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray600.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc public class var ballotHighestVote: UIColor {
        .primary
    }
    
    @objc public class var ballotRowLight: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc public class var ballotRowDark: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray300.color
        case .dark:
            return Asset.SharedColors.gray800.color
        }
    }
    
    public class var backgroundPinChat: UIColor {
        Asset.SharedColors.pin.color
    }
    
    public class var backgroundThumbnailCollectionView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    public class var backgroundPreviewCollectionViewCell: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    public class var systemMessageBackground: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray150.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }

    public class var thumbnailProgressViewColor: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray30.color
        case .dark:
            return Asset.SharedColors.gray850.color
        }
    }
}
