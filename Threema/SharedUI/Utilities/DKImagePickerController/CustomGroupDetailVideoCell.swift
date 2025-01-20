//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2025 Threema GmbH
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

class CustomGroupDetailVideoCell: CustomGroupDetailImageCell {
    
    override class func cellReuseIdentifier() -> String {
        "CustomVideoAssetIdentifier"
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.insertSubview(videoInfoView, belowSubview: checkView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let height: CGFloat = 30
        videoInfoView.frame = CGRect(
            x: 0,
            y: contentView.bounds.height - height,
            width: contentView.bounds.width,
            height: height
        )
    }
    
    override weak var asset: DKAsset? {
        didSet {
            if let asset {
                let videoDurationLabel = videoInfoView.viewWithTag(-1) as! UILabel
                let minutes = Int(asset.duration!) / 60
                let seconds = Int(round(asset.duration!)) % 60
                videoDurationLabel.text = String(format: "\(minutes):%02d", seconds)
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            videoInfoView.backgroundColor = UIColor(white: 0.0, alpha: 0.7)
            let videoDurationLabel = videoInfoView.viewWithTag(-1) as! UILabel

//            videoDurationLabel.isHidden =  super.isSelected
            if super.isSelected {
                videoDurationLabel.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: videoInfoView.bounds.width - 27,
                    height: videoInfoView.bounds.height
                )
            }
            else {
                videoDurationLabel.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: videoInfoView.bounds.width - 7,
                    height: videoInfoView.bounds.height
                )
            }
        }
    }
    
    fileprivate lazy var videoInfoView: UIView = {
        let videoInfoView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 0))
        
        let videoImageView = UIImageView(image: DKImageResource.videoCameraIcon())
        videoInfoView.addSubview(videoImageView)
        videoImageView.center = CGPoint(x: videoImageView.bounds.width / 2 + 7, y: videoInfoView.bounds.height / 2)
        videoImageView.autoresizingMask = [.flexibleBottomMargin, .flexibleTopMargin]
        
        let videoDurationLabel = UILabel()
        videoDurationLabel.tag = -1
        videoDurationLabel.textAlignment = .right
        videoDurationLabel.font = UIFont.systemFont(ofSize: 12)
        videoDurationLabel.textColor = UIColor.white
        videoInfoView.addSubview(videoDurationLabel)
        videoDurationLabel.frame = CGRect(
            x: 0,
            y: 0,
            width: videoInfoView.bounds.width - 7,
            height: videoInfoView.bounds.height
        )
        videoDurationLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return videoInfoView
    }()
}
