//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros
import UIKit

/// Animated media view with a tap gesture recognizer that overlays associated state and metadata information
final class MessageAnimatedMediaTapView: UIView {
    
    /// Blob message with a (potential) thumbnail to show
    var thumbnailDisplayMessage: ThumbnailDisplayMessage? {
        didSet {
            updateView(with: thumbnailDisplayMessage)
            
            // We only auto sync when the message actually changes
            // to improve performance and remove infinite loops
            if thumbnailDisplayMessage?.objectID != oldValue?.objectID {
                autoSyncBlobs(with: thumbnailDisplayMessage)
            }
        }
    }
    
    // MARK: - Private properties

    private lazy var fileSizeFormatter = ByteCountFormatter()
    
    private lazy var progressFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    private var tapAction: () -> Void
    
    // MARK: - Views & constraints
    
    private lazy var centerStateBlurView: BlurCircleView = {
        let blurCircleView = BlurCircleView(sfSymbolName: "person.fill.turn.down")
        return blurCircleView
    }()
    
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        
        // Trying to make it look like a blurry overlay
        progressView.trackTintColor = .clear
        progressView.alpha = 0.75
        
        return progressView
    }()
    
    private lazy var metadataView = MessageSymbolMetadataVibrancyView()
    private lazy var metadataBlurBackgroundContainerView = MessageMetadataBlurBackgroundView(
        rootView: metadataView.vibrancyAffectedView,
        nonVibrantRootView: metadataView.vibrancyUnaffectedView
    )
    
    private lazy var dateAndStateView = MessageDateAndStateVibrancyView()
    private lazy var dateAndStateBlurBackgroundContainerView = MessageMetadataBlurBackgroundView(
        rootView: dateAndStateView.vibrancyAffectedView,
        nonVibrantRootView: dateAndStateView.vibrancyUnaffectedView
    )
    
    private lazy var animatedMediaView: FLAnimatedImageView = {
        let animatedMediaView = FLAnimatedImageView()
        // As animated images cannot be expanded we cannot cut off parts of it if it doesn't fit the aspect ratio
        // requirements.
        animatedMediaView.contentMode = .scaleAspectFit
        
        return animatedMediaView
    }()
    
    private lazy var thumbnailMaxHeightConstraint = {
        let maxHeightConstraint = animatedMediaView.heightAnchor.constraint(
            lessThanOrEqualToConstant: ChatViewConfiguration.Thumbnail.maxHeight
        )
        
        // This needs to be one higher than the priority of `thumbnailHeightConstraint`, but not required otherwise it
        // will lead to breaking constraints.
        maxHeightConstraint.priority = .defaultHigh + 1
        
        return maxHeightConstraint
    }()

    private lazy var thumbnailHeightConstraint = thumbnailHeightConstraint(
        for: ChatViewConfiguration.Thumbnail.defaultAspectRatio
    )
    
    // MARK: - Configuration

    init(tapAction: @escaping () -> Void) {
        self.tapAction = tapAction
        
        super.init(frame: .zero)
        
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.minimumPressDuration = 0.0
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
        
        clipsToBounds = true
        layer.cornerRadius = ChatViewConfiguration.Thumbnail.cornerRadius
        layer.cornerCurve = .continuous
        
        registerObservers()
        configureLayout()
        updateColors()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func didReceiveMemoryWarning() {
        if animatedMediaView.isAnimating {
            stopMediaAnimation()
        }
    }
    
    private func configureLayout() {
        // Add subviews in reverse order as the they are added on top of each other
        addSubview(animatedMediaView)
        addSubview(dateAndStateBlurBackgroundContainerView)
        addSubview(metadataBlurBackgroundContainerView)
        addSubview(progressView)
        addSubview(centerStateBlurView)
        
        centerStateBlurView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        metadataBlurBackgroundContainerView.translatesAutoresizingMaskIntoConstraints = false
        dateAndStateBlurBackgroundContainerView.translatesAutoresizingMaskIntoConstraints = false
        animatedMediaView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            centerStateBlurView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStateBlurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // It should fit inside small pictures
            
            progressView.topAnchor.constraint(
                equalTo: centerStateBlurView.bottomAnchor,
                constant: ChatViewConfiguration.Thumbnail.defaultStateAndProgressSpace
            ),
            progressView.leadingAnchor.constraint(equalTo: centerStateBlurView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: centerStateBlurView.trailingAnchor),
            
            metadataBlurBackgroundContainerView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: ChatViewConfiguration.MetadataBackground.defaultMargin
            ),
            metadataBlurBackgroundContainerView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.defaultMargin
            ),
            
            dateAndStateBlurBackgroundContainerView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.defaultMargin
            ),
            dateAndStateBlurBackgroundContainerView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -ChatViewConfiguration.MetadataBackground.defaultMargin
            ),
            
            animatedMediaView.topAnchor.constraint(equalTo: topAnchor),
            animatedMediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animatedMediaView.bottomAnchor.constraint(equalTo: bottomAnchor),
            animatedMediaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            thumbnailMaxHeightConstraint,
            thumbnailHeightConstraint,
        ])
        
        // Some constraints to improve layout, but they are not strictly necessary
        
        let notRequiredConstraints = [
            // It should fit inside small pictures
            centerStateBlurView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            centerStateBlurView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            centerStateBlurView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            metadataBlurBackgroundContainerView.topAnchor.constraint(
                greaterThanOrEqualTo: progressView.bottomAnchor,
                constant: ChatViewConfiguration.Thumbnail.defaultStateAndProgressSpace
            ),
            dateAndStateBlurBackgroundContainerView.topAnchor.constraint(
                greaterThanOrEqualTo: progressView.bottomAnchor,
                constant: ChatViewConfiguration.Thumbnail.defaultStateAndProgressSpace
            ),
        ]
        
        for notRequiredConstraint in notRequiredConstraints {
            notRequiredConstraint.priority = .defaultHigh
        }
        
        NSLayoutConstraint.activate(notRequiredConstraints)
        
        // Set inset for media view
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Thumbnail.defaultMargin,
            leading: -ChatViewConfiguration.Thumbnail.defaultMargin,
            bottom: -ChatViewConfiguration.Thumbnail.defaultMargin,
            trailing: -ChatViewConfiguration.Thumbnail.defaultMargin
        )
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            tapAction()
        }
    }
        
    // MARK: - Update
    
    private func updateView(with thumbnailDisplayMessage: ThumbnailDisplayMessage?) {
        let currentBlobDisplayState = thumbnailDisplayMessage?.blobDisplayState ?? .fileNotFound
        animatedMediaView.animatedImage = nil
        animatedMediaView.image = nil
        
        // Center state view
        switch currentBlobDisplayState {
        case .remote, .downloading, .fileNotFound:
            if let symbolName = currentBlobDisplayState.symbolName {
                showCenterStateBlurView(with: symbolName)
            }
            else {
                hideCenterStateBlurView()
            }

        case .processed, .pending, .uploading, .uploaded, .sendingError:
            hideCenterStateBlurView()
            
        case .dataDeleted:
            hideCenterStateBlurView()
        }
        
        // Progress view
        if case let .downloading(progress: progress) = currentBlobDisplayState {
            showProgressView()
            progressView.setProgress(progress, animated: true)
        }
        else {
            hideProgressView()
        }
        
        // Metadata view
        switch currentBlobDisplayState {
        case .remote, .pending:
            metadataView.symbolName = thumbnailDisplayMessage?.fileMessageType.symbolName
            metadataView.metadataString = fileSizeFormatter
                .string(for: thumbnailDisplayMessage?.dataBlobFileSize)
            metadataBlurBackgroundContainerView.isHidden = false
            
        case let .uploading(progress: progress), let .downloading(progress: progress):
            
            metadataView.symbolName = thumbnailDisplayMessage?.fileMessageType.symbolName

            metadataBlurBackgroundContainerView.isHidden = false
            if let progressString = progressFormatter.string(from: Double(progress) as NSNumber) {
                metadataView.metadataString = """
                    \(fileSizeFormatter.string(for: thumbnailDisplayMessage?.dataBlobFileSize) ?? "") \
                    (\(progressString))
                    """
            }
            else {
                metadataView.metadataString = fileSizeFormatter.string(for: thumbnailDisplayMessage?.dataBlobFileSize)
            }
            
        case .fileNotFound:
            metadataView.symbolName = nil
            metadataView.metadataString = #localize("file_not_found_title")
            metadataBlurBackgroundContainerView.isHidden = false
            
        case .dataDeleted:
            metadataView.symbolName = currentBlobDisplayState.symbolName
            metadataView.metadataString = nil
            metadataBlurBackgroundContainerView.isHidden = false
            
        case .processed, .uploaded, .sendingError:
            metadataBlurBackgroundContainerView.isHidden = true
        }

        // Date and state view
        if thumbnailDisplayMessage?.showDateAndStateInline ?? false {
            dateAndStateBlurBackgroundContainerView.isHidden = false
            dateAndStateView.message = thumbnailDisplayMessage
        }
        else {
            dateAndStateBlurBackgroundContainerView.isHidden = true
        }
        
        // We directly start animating if media is ready
        if let animatedMediaData = thumbnailDisplayMessage?.blobData {
            switch currentBlobDisplayState {
            case .pending, .uploading, .uploaded, .processed, .sendingError:
                
                animatedMediaView.animatedImage = FLAnimatedImage(animatedGIFData: animatedMediaData)
                
                if !UIAccessibility.isReduceMotionEnabled,
                   UIAccessibility.isVideoAutoplayEnabled {
                    animatedMediaView.startAnimating()
                }
                else {
                    animatedMediaView.stopAnimating()
                    
                    if let defaultSymbol = self.thumbnailDisplayMessage?.fileMessageType
                        .defaultInteractionSymbolName {
                        showCenterStateBlurView(with: defaultSymbol)
                    }
                }
            case .remote, .downloading, .dataDeleted, .fileNotFound:
                break
            }
        }
        else if let thumbnailData = thumbnailDisplayMessage?.blobThumbnail,
                let image = UIImage(data: thumbnailData) {
            animatedMediaView.image = image
        }
        
        updateImageAspectRatio(
            to: thumbnailDisplayMessage?.heightToWidthAspectRatio ?? ChatViewConfiguration.Thumbnail.defaultAspectRatio
        )
    }
    
    private func updateImageAspectRatio(to heightToWidthAspectRatio: CGFloat) {
        let clampedRatio = min(
            max(heightToWidthAspectRatio, ChatViewConfiguration.Thumbnail.minAspectRatio),
            ChatViewConfiguration.Thumbnail.maxAspectRatio
        )
        
        // Only reset constraint if it changed
        guard clampedRatio != thumbnailHeightConstraint.multiplier else {
            return
        }
        
        thumbnailHeightConstraint.isActive = false
        thumbnailHeightConstraint = thumbnailHeightConstraint(for: clampedRatio)
        thumbnailHeightConstraint.isActive = true
    }
    
    private func thumbnailHeightConstraint(for heightToWidthAspectRatio: CGFloat) -> NSLayoutConstraint {
        let constraint = animatedMediaView.heightAnchor.constraint(
            equalTo: animatedMediaView.widthAnchor,
            multiplier: heightToWidthAspectRatio
        )
        
        // We would like to get a ratio close to that.
        // If we require exactly this aspect ratio we get unsatisfiable constraints.
        constraint.priority = .defaultHigh
        
        return constraint
    }
    
    func updateColors() {
        progressView.progressTintColor = Colors.thumbnailProgressViewColor
        metadataBlurBackgroundContainerView.updateColors()
        dateAndStateBlurBackgroundContainerView.updateColors()
        dateAndStateView.updateColors()
        metadataView.updateColors()
    }
    
    func highlight(_ highlight: Bool) {
        centerStateBlurView.highlight(
            highlight,
            highlightingDuration: ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightedDurationTap,
            highlightingAlpha: ChatViewConfiguration.Thumbnail.highlightingAlpha
        )

        UIView.animate(withDuration: ChatViewConfiguration.ChatBubble.HighlightedAnimation.highlightedDurationTap) {
            self.animatedMediaView.alpha = highlight ? ChatViewConfiguration.Thumbnail.highlightingAlpha : 1
        }
    }
    
    func toggleMediaAnimation() {
        if animatedMediaView.isAnimating {
            stopMediaAnimation()
        }
        else {
            startMediaAnimation()
        }
    }
    
    func startMediaAnimation() {
        hideCenterStateBlurView()
        animatedMediaView.startAnimating()
    }
    
    func stopMediaAnimation() {
        animatedMediaView.stopAnimating()
        
        if let defaultSymbol = thumbnailDisplayMessage?.fileMessageType
            .defaultInteractionSymbolName {
            showCenterStateBlurView(with: defaultSymbol)
        }
    }
    
    private func autoSyncBlobs(with message: ThumbnailDisplayMessage?) {
        guard let objectID = message?.objectID else {
            return
        }
        
        Task {
            await BlobManager.shared.autoSyncBlobs(for: objectID)
        }
    }
    
    // MARK: - Show and hide
    
    private func showCenterStateBlurView(with symbolName: String) {
        centerStateBlurView.updateSymbol(to: symbolName)

        guard centerStateBlurView.isHidden else {
            return
        }

        centerStateBlurView.isHidden = false
    }
    
    private func hideCenterStateBlurView() {
        guard !centerStateBlurView.isHidden else {
            return
        }
        
        UIView.animate(withDuration: 0.5) {
            self.centerStateBlurView.isHidden = true
        }
        
        // We don't need to deactivate any constraints as they are independent of the position of any other view.
    }
    
    private func showProgressView() {
        guard progressView.isHidden else {
            return
        }
        
        progressView.progress = 0
        progressView.isHidden = false
    }
    
    private func hideProgressView() {
        guard !progressView.isHidden else {
            return
        }
        
        progressView.progress = 0
        progressView.isHidden = true
    }
}

// MARK: - UIGestureRecognizerDelegate

// This resolves an issue where the gesture recognizer would infer with scrolling interactions
extension MessageAnimatedMediaTapView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
