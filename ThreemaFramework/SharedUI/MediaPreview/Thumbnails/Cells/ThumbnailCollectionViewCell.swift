//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class ThumbnailCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var identifier: IndexPath?
    
    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }
    
    func updateSelectionState() {
        layer.borderColor = isSelected ? UIColor.primary.cgColor : Colors.backgroundTableViewCell.cgColor
    }
    
    override func prepareForReuse() {
        imageView.image = nil
        startLoading()
        isSelected = false
        updateSelectionState()
    }
    
    func setColors() {
        backgroundColor = Colors.backgroundTableViewCell
        layer.borderWidth = 2
        layer.cornerRadius = 5
        if isSelected {
            layer.borderColor = UIColor.primary.cgColor
        }
        else {
            layer.borderColor = Colors.backgroundView.cgColor
        }
    }
    
    func startLoading() {
        setColors()

        activityIndicator.startAnimating()
        
        imageView.isHidden = true
        activityIndicator.isHidden = false
    }
    
    func loadImage(image: UIImage) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        imageView.image = image
        activityIndicator.stopAnimating()
        
        imageView.isHidden = false
        activityIndicator.isHidden = true
    }
    
    override var isAccessibilityElement: Bool {
        set { }
        get {
            false
        }
    }
}
