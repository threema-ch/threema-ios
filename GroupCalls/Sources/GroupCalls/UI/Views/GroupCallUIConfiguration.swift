//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

internal enum GroupCallUIConfiguration {

    enum NavigationBar {
        static let dismissButtonSymbolConfiguration = UIImage.SymbolConfiguration(
            font: UIFont.preferredFont(forTextStyle: .headline),
            scale: .large
        )
        
        // Based on .headline but slightly bigger
        static let headerTextStyle: UIFont.TextStyle = .title3
        static let headerFontWeight: UIFont.Weight = .semibold
        
        static let smallerTextStyle: UIFont.TextStyle = .subheadline
        static let smallerSymbolConfiguration = UIImage.SymbolConfiguration(
            font: UIFont.preferredFont(forTextStyle: smallerTextStyle),
            scale: .small
        )
    }
    
    enum Toolbar {
        static let horizontalInset = 16.0
        static let verticalInset = 16.0
    }
    
    enum ToolbarButton {
        static let smallerButtonWidth = 45.0
        static let smallerButtonCornerRadius = smallerButtonWidth / 2
        static let smallerButtonImageConfig: UIImage.Configuration = UIImage.SymbolConfiguration(pointSize: 15)
        static let smallerButtonOffset = 5.0
        static let smallerButtonTint: UIColor = .white
        static let smallerButtonBackground: UIColor = .black.withAlphaComponent(0.2)

        static let biggerButtonWidth = 60.0
        static let biggerButtonCornerRadius = biggerButtonWidth / 2
        static let biggerButtonImageConfig: UIImage.Configuration = UIImage.SymbolConfiguration(pointSize: 20)
        static let biggerButtonTint: UIColor = .black
        static let biggerButtonBackground: UIColor = .white.withAlphaComponent(0.6)
    }
    
    enum ParticipantCell {
        static let cellInset = 8.0
        static let nameTextStyle: UIFont.TextStyle = .body
        static let stateImageConfig = UIImage
            .SymbolConfiguration(font: UIFont.preferredFont(forTextStyle: nameTextStyle), scale: .small)
    }
    
    enum General {
        static let initialGradientOpacity = 0.7
    }
}
