//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

/// Destinations to be shown from anywhere in the app.
/// - Important: Destinations that are scoped to a `Coordinator` should be referenced in the respective implementation.
public enum Destination: Equatable {
    case app(AppDestination)
    
    /// Each case represents one of our tabs
    public enum AppDestination: Equatable {
        case contacts
        case conversations
        case profile
        case settings
        
        public enum ProfileDestination: Equatable {
            case todo
        }
        
        public enum SettingsDestination: Equatable {
            case todo
        }
    }
}

/// Style describing how a view controller should be shown
public indirect enum CordinatorNavigationStyle {
    case show
    case modal(stlye: UIModalPresentationStyle = .automatic, transition: UIModalTransitionStyle = .coverVertical)
    case passcode(style: CordinatorNavigationStyle)
}
