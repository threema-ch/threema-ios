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

import CocoaLumberjackSwift
import UIKit

class ImagePreviewCollectionViewCell: ScreenWidthSizedCell, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var imageView: UIImageView!
    
    @IBOutlet var gifContainerView: UIView!
    @IBOutlet var gifPlayImageView: UIImageView!
    @IBOutlet var gifContentView: UIView!
    
    @IBOutlet var loadingText: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var loadingView: UIView!
    
    var indexPath: IndexPath?
    var isPlaying = false
    var animatedImageView: FLAnimatedImageView?
    var imageSize: CGSize?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseVideo),
            name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo),
            object: nil
        )
    }
    
    func addAccessibilityLabels() {
        imageView.accessibilityLabel = BundleUtil.localizedString(forKey: "image")
        loadingView.accessibilityLabel = BundleUtil.localizedString(forKey: "loading_image")
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
    @objc func tapTwice(gesture: UIGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
        else {
            scrollView.setZoomScale(scrollView.maximumZoomScale / 2, animated: true)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        animatedImageView?.animatedImage = nil
        
        showLoadingScreen()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        animatedImageView?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        
        // This checks if the displayed media type is a static image
        // It could be made more robust.
        guard let size = imageSize else {
            return
        }
        setupZooming(size)
        centerImage()
    }
    
    func setColors() {
        gifPlayImageView.tintColor = .white
        gifContentView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
        gifContainerView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
        
        loadingView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
        backgroundColor = Colors.backgroundPreviewCollectionViewCell
        
        gifPlayImageView.image = gifPlayImageView.image?.draw(withTintColor: .white)
    }
    
    func showLoadingScreen() {
        setColors()
        
        imageView.isHidden = true
        
        UIView.animate(withDuration: 0.1, animations: {
            self.gifContainerView.isHidden = true
            self.gifPlayImageView.isHidden = true
            
            self.activityIndicator.startAnimating()
            
            self.loadingText.text = BundleUtil.localizedString(forKey: "loading_image")
            
            self.activityIndicator.isHidden = false
            self.loadingView.isHidden = false
            self.loadingText.isHidden = false
        })
        
        scrollView.gestureRecognizers?.removeAll()
    }
    
    func updateImageTo(data: Data) {
        // Setup gif image view
        guard let image = FLAnimatedImage(animatedGIFData: data) else {
            DDLogError("Could not create gif from data")
            handleError()
            return
        }
        let animImageView = FLAnimatedImageView()
        
        animImageView.animatedImage = image
        animImageView.contentMode = .scaleAspectFit
        animImageView.frame = bounds
        
        // Add gif image view and bring the play button to the foreground
        gifContainerView.addSubview(animImageView)
        gifContainerView.bringSubviewToFront(gifPlayImageView)
        
        // Store a reference to the image view to be able to relayout it when layoutSubviews is called
        animatedImageView = animImageView
        
        // FLAnimatedImageView starts animating immediately by default
        animatedImageView?.stopAnimating()
        
        // Hide loading screen and unhide gif image view
        gifPlayImageView.isHidden = false
        gifContainerView.isHidden = false
        loadingView.isHidden = true
        loadingText.isHidden = true
        scrollView.isHidden = true
        activityIndicator.stopAnimating()
        
        let imageFrame = AVMakeRect(aspectRatio: image.size, insideRect: animImageView.frame)
        
        let tapView = UIView(frame: imageFrame)
        
        gifContainerView.addSubview(tapView)
        gifContainerView.bringSubviewToFront(tapView)
        
        // Add a tap gesture recognizer for play pause
        let tapGR = UITapGestureRecognizer(
            target: self,
            action: #selector(ImagePreviewCollectionViewCell.handleTap(_:))
        )
        tapGR.delegate = self
        tapGR.numberOfTapsRequired = 1
        animatedImageView!.isUserInteractionEnabled = true
        tapView.addGestureRecognizer(tapGR)
    }
    
    func updateImageTo(image: UIImage) {
        imageView.image = image
        //
        // Setup imageview
        imageView.contentMode = .scaleAspectFit
        
        // Show imageview and hide loading view
        imageView.isHidden = false
        scrollView.isHidden = false
        loadingView.isHidden = true
        activityIndicator.stopAnimating()
        loadingText.isHidden = true
        
        gifPlayImageView.image = nil
        
        imageSize = image.size
        setupZooming(image.size)
        
        centerImage()
    }
    
    private func setupZooming(_ imageSize: CGSize) {
        let minZoom = min(bounds.size.width / imageSize.width, bounds.size.height / imageSize.height)
        
        imageView.isUserInteractionEnabled = true
        imageView.isMultipleTouchEnabled = true
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(tapTwice))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.gestureRecognizers?.append(doubleTapGesture)
        
        scrollView.contentSize = imageView.frame.size
        scrollView.delegate = self
        scrollView.isScrollEnabled = false
        
        scrollView.minimumZoomScale = minZoom
        scrollView.setZoomScale(minZoom, animated: false)
        scrollView.maximumZoomScale = 6
        
        // Set the image frame size after scaling down
        let imageWidth = imageSize.width * minZoom
        let imageHeight = imageSize.height * minZoom
        let newImageFrame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        imageView.frame = newImageFrame
    }
    
    private func centerImage() {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = frame.size
        let verticalPadding = imageViewSize.height < scrollViewSize
            .height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize
            .width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0
        
        scrollView.contentInset = UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            self.togglePlaying()
        }
    }
    
    func cannotPreview() {
        loadingText.text = BundleUtil.localizedString(forKey: "image_preview_cell_cannot_preview")
        activityIndicator.stopAnimating()
    }
    
    func handleError() {
        loadingText.text = BundleUtil.localizedString(forKey: "load_error")
        activityIndicator.stopAnimating()
    }
    
    func togglePlaying() {
        if isPlaying {
            pauseVideo()
        }
        else {
            playVideo()
        }
        isPlaying = !isPlaying
    }
    
    @objc func pauseVideo() {
        animatedImageView?.stopAnimating()
        gifPlayImageView.isHidden = false
    }
    
    func playVideo() {
        animatedImageView?.startAnimating()
        gifPlayImageView.isHidden = true
    }
}
