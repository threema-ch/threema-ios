//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import CocoaLumberjackSwift

class ImagePreviewCollectionViewCell: ScreenWidthSizedCell, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var gifContainerView: UIView!
    @IBOutlet weak var gifPlayImageView: UIImageView!
    @IBOutlet weak var gifContentVIew: UIView!
    
    @IBOutlet weak var loadingText: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingView: UIView!
    
    var indexPath : IndexPath?
    var isPlaying : Bool = false
    var animatedImageView : FLAnimatedImageView?
    var imageSize : CGSize?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(self, selector: #selector(self.pauseVideo), name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
    }
    
    func addAccessibilityLabels() {
        self.imageView.accessibilityLabel = BundleUtil.localizedString(forKey:"image")
        self.loadingView.accessibilityLabel = BundleUtil.localizedString(forKey:"loading_image")
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        self.imageView
    }
    
    @objc func tapTwice(gesture: UIGestureRecognizer) {
        if self.scrollView.zoomScale > self.scrollView.minimumZoomScale {
            self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: true)
        } else {
            self.scrollView.setZoomScale(self.scrollView.maximumZoomScale / 2, animated: true)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.animatedImageView?.animatedImage = nil
        
        self.showLoadingScreen()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.animatedImageView?.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        
        // This checks if the displayed media type is a static image
        // It could be made more robust.
        guard let size = self.imageSize else {
            return
        }
        self.setupZooming(size)
        self.centerImage()
    }
    
    func setColors() {
        self.gifPlayImageView.tintColor = .white
        self.activityIndicator.color = Colors.fontNormal()
        self.gifContentVIew.backgroundColor = Colors.backgroundDark()
        self.gifContainerView.backgroundColor = Colors.backgroundDark()
        
        self.loadingText.textColor = Colors.fontNormal()
        self.loadingView.backgroundColor = Colors.backgroundDark()
        self.backgroundColor = Colors.backgroundDark()
        
        self.gifPlayImageView.image = self.gifPlayImageView.image?.draw(withTintColor: .white)
    }
    
    func showLoadingScreen() {
        self.setColors()
        
        self.imageView.isHidden = true
        
        UIView.animate(withDuration: 0.1, animations: {
            self.gifContainerView.isHidden = true
            self.gifPlayImageView.isHidden = true
            
            self.activityIndicator.startAnimating()
            
            self.loadingText.text = BundleUtil.localizedString(forKey:"loading_image")
            
            self.activityIndicator.isHidden = false
            self.loadingView.isHidden = false
            self.loadingText.isHidden = false
        })
        
        self.scrollView.gestureRecognizers?.removeAll()
    }
    
    func updateImageTo(data : Data) {
        //Setup gif image view
        guard let image = FLAnimatedImage(animatedGIFData: data) else {
            DDLogError("Could not create gif from data")
            self.loadingText.text = BundleUtil.localizedString(forKey: "load_error")
            self.activityIndicator.stopAnimating()
            return
        }
        let animImageView = FLAnimatedImageView()
        
        animImageView.animatedImage = image
        animImageView.contentMode = .scaleAspectFit
        animImageView.frame = self.bounds
        
        // Add gif image view and bring the play button to the foreground
        self.gifContainerView.addSubview(animImageView)
        self.gifContainerView.bringSubviewToFront(self.gifPlayImageView)
        
        // Store a reference to the image view to be able to relayout it when layoutSubviews is called
        self.animatedImageView = animImageView
        
        // FLAnimatedImageView starts animating immediately by default
        animatedImageView?.stopAnimating()
        
        // Hide loading screen and unhide gif image view
        self.gifPlayImageView.isHidden = false
        self.gifContainerView.isHidden = false
        self.loadingView.isHidden = true
        self.loadingText.isHidden = true
        self.scrollView.isHidden = true
        self.activityIndicator.stopAnimating()
        
        let imageFrame = AVMakeRect(aspectRatio: image.size, insideRect: animImageView.frame)
        
        let tapView = UIView(frame: imageFrame)
        
        self.gifContainerView.addSubview(tapView)
        self.gifContainerView.bringSubviewToFront(tapView)
        
        // Add a tap gesture recognizer for play pause
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(ImagePreviewCollectionViewCell.handleTap(_:)))
        tapGR.delegate = self
        tapGR.numberOfTapsRequired = 1
        self.animatedImageView!.isUserInteractionEnabled = true
        tapView.addGestureRecognizer(tapGR)
    }
    
    func updateImageTo(image : UIImage) {
        self.imageView.image = image
        //
        // Setup imageview
        self.imageView.contentMode = .scaleAspectFit
        
        // Show imageview and hide loading view
        self.imageView.isHidden = false
        self.scrollView.isHidden = false
        self.loadingView.isHidden = true
        self.activityIndicator.stopAnimating()
        self.loadingText.isHidden = true
        
        self.imageSize = image.size
        self.setupZooming(image.size)
        
        self.centerImage()
    }
    
    private func setupZooming(_ imageSize: CGSize) {
        let minZoom = min(self.bounds.size.width / imageSize.width, self.bounds.size.height / imageSize.height);
        
        self.imageView.isUserInteractionEnabled = true
        self.imageView.isMultipleTouchEnabled = true
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tapTwice))
        doubleTapGesture.numberOfTapsRequired = 2;
        self.scrollView.gestureRecognizers?.append(doubleTapGesture)
        
        
        self.scrollView.contentSize = self.imageView.frame.size
        self.scrollView.delegate = self
        self.scrollView.isScrollEnabled = false
        
        self.scrollView.minimumZoomScale = minZoom
        self.scrollView.setZoomScale(minZoom, animated: false)
        self.scrollView.maximumZoomScale = 6
        
        // Set the image frame size after scaling down
        let imageWidth = imageSize.width * minZoom
        let imageHeight = imageSize.height * minZoom
        let newImageFrame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        self.imageView.frame = newImageFrame
    }
    
    private func centerImage() {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = self.frame.size
        let verticalPadding = imageViewSize.height < scrollViewSize.height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize.width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0
        
        self.scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            self.togglePlaying()
        }
    }
    
    func togglePlaying() {
        if self.isPlaying {
            self.pauseVideo()
        } else {
            self.playVideo()
        }
        self.isPlaying = !self.isPlaying
    }
    
    @objc func pauseVideo() {
        self.animatedImageView?.stopAnimating()
        self.gifPlayImageView.isHidden = false
    }
    
    func playVideo() {
        self.animatedImageView?.startAnimating()
        self.gifPlayImageView.isHidden = true
    }
}
