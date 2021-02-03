//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var identifier : IndexPath?
    
    override var isSelected: Bool {
        didSet {
            self.updateSelectionState()
        }
    }
    
    func updateSelectionState() {
        self.layer.borderColor = isSelected ? Colors.main()?.cgColor : Colors.backgroundInverted()?.cgColor
    }
    
    override func prepareForReuse() {
        self.imageView.image = nil
        self.startLoading()
        self.isSelected = false
        self.updateSelectionState()
    }
    
    func setColors() {
        self.backgroundColor = .clear
        self.layer.borderColor = self.isSelected ? Colors.main()?.cgColor : Colors.backgroundInverted()?.cgColor
        
        self.layer.borderWidth = 2
        self.layer.cornerRadius = 5
        self.activityIndicator.color = Colors.fontNormal()
    }
    
    func startLoading() {
        self.setColors()

        self.activityIndicator.startAnimating()
        
        self.imageView.isHidden = true
        self.activityIndicator.isHidden = false
    }
    
    func loadImage(image : UIImage) {
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFill
        
        self.imageView.image = image
        self.activityIndicator.stopAnimating()
        
        self.imageView.isHidden = false
        self.activityIndicator.isHidden = true
    }
}
