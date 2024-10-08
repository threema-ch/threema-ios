//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import UIKit

/// Shows icon for other Threema type
///
/// Use in combination with `Contact.showOtherThreemaTypeIcon`.
///
/// If you overlay it on the profile picture it should appear at the leading bottom and be 35 % of its size.
public class OtherThreemaTypeImageView: UIImageView {
    
    public init() {
        super.init(image: ThreemaUtility.otherThreemaTypeIcon)
        
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        widthAnchor.constraint(equalTo: heightAnchor).isActive = true
        
        accessibilityIgnoresInvertColors = true
        
        accessibilityLabel = ThreemaUtility.otherThreemaTypeAccessibilityLabel
    }
}
