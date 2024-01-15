//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2024 Threema GmbH
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

import ThreemaFramework
import UIKit

class CustomGroupDetailImageCell: DKAssetGroupDetailBaseCell {
    
    override class func cellReuseIdentifier() -> String {
        "CustomGroupDetailImageCell"
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        thumbnailImageView.frame = bounds
        thumbnailImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(thumbnailImageView)
        
        checkView.frame = bounds
        checkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        checkView.checkImageView.tintColor = nil
        checkView.checkLabel.font = UIFont.boldSystemFont(ofSize: 14)
        checkView.checkLabel.textColor = UIColor.white
        contentView.addSubview(checkView)
        
        self.isAccessibilityElement = true
               
        thumbnailImageView.accessibilityIgnoresInvertColors = true
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class DKImageCheckView: UIView {
        
        private class func stretchImgFromMiddle(_ image: UIImage) -> UIImage {
            let centerX = image.size.width / 2
            let centerY = image.size.height / 2
            return image
                .resizableImage(withCapInsets: UIEdgeInsets(
                    top: centerY,
                    left: centerX,
                    bottom: centerY,
                    right: centerX
                ))
        }
        
        internal lazy var checkImageView: UIImageView = {
            let imageView = UIImageView(
                image: CustomGroupDetailImageCell.DKImageCheckView
                    .stretchImgFromMiddle(StyleKit.checkedBackground)
            )
            return imageView
        }()
        
        internal lazy var checkLabel: UILabel = {
            let label = UILabel()
            label.textAlignment = .right
            
            return label
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(checkImageView)
            addSubview(checkLabel)
        }
        
        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            checkImageView.frame = bounds
            checkLabel.frame = CGRect(x: 0, y: 5, width: bounds.width - 5, height: 20)
        }
    } // DKImageCheckView
    
    override var thumbnailImage: UIImage? {
        didSet {
            self.thumbnailImageView.image = self.thumbnailImage
        }
    }

    override var index: Int {
        didSet {
            checkView.checkLabel.text = "\(index + 1)"
        }
    }
    
    fileprivate lazy var thumbnailImageView: UIImageView = {
        let thumbnailImageView = UIImageView()
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        
        return thumbnailImageView
    }()
    
    internal let checkView = DKImageCheckView()
    
    override var isSelected: Bool {
        didSet {
            checkView.isHidden = !super.isSelected
        }
    }
} // DKAssetGroupDetailCell
