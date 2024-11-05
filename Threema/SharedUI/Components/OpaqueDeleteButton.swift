//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

import ThreemaMacros
import UIKit

/// Typical circle with x mark icon, but the x mark is not transparent
final class OpaqueDeleteButton: ThemedCodeButton {
    
    private lazy var deleteImageView: UIImageView = {
        
        let imageView = UIImageView(
            image: UIImage(systemName: "xmark.circle.fill")?
                .applying(symbolWeight: .heavy, symbolScale: .large)
        )
        
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
        
        return imageView
    }()
    
    /// Background to make x opaque
    private lazy var xMarkBackgroundView: UIView = {
        let view = UIView()
        // Needed such that button gets UIEvents
        view.isUserInteractionEnabled = false
        return view
    }()
    
    override func configureButton() {
        super.configureButton()

        // Add and layout subviews
        
        addSubview(xMarkBackgroundView)
        addSubview(deleteImageView)

        xMarkBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        deleteImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Inset x mark background to make it not appear outside of the circle
        let xMarkBackgroundInset: CGFloat = 8
        
        NSLayoutConstraint.activate([
            xMarkBackgroundView.topAnchor.constraint(
                equalTo: deleteImageView.topAnchor,
                constant: xMarkBackgroundInset
            ),
            xMarkBackgroundView.leadingAnchor.constraint(
                equalTo: deleteImageView.leadingAnchor,
                constant: xMarkBackgroundInset
            ),
            xMarkBackgroundView.bottomAnchor.constraint(
                equalTo: deleteImageView.bottomAnchor,
                constant: -xMarkBackgroundInset
            ),
            xMarkBackgroundView.trailingAnchor.constraint(
                equalTo: deleteImageView.trailingAnchor,
                constant: -xMarkBackgroundInset
            ),
            
            // Add image to center of button
            deleteImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            deleteImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
        accessibilityLabel = #localize("delete")
        
        updateColors()
    }
    
    override func updateColors() {
        super.updateColors()
        
        tintColor = Colors.textVeryLight
        xMarkBackgroundView.backgroundColor = Colors.backgroundQuickActionButton
    }
}
