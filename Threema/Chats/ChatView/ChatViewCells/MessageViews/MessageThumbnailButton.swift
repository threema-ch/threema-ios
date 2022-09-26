//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

/// Thumbnail button view that overlays associated state and metadata information
final class MessageThumbnailButton: ThemedCodeButton {
    
    /// Blob message with a (potential) thumbnail to show
    var thumbnailDisplayMessage: ThumbnailDisplayMessage? {
        didSet {
            updateView(with: thumbnailDisplayMessage)
        }
    }
    
    // MARK: - Private properties
    
    private lazy var fileSizeFormatter = ByteCountFormatter()
    
    // MARK: - Views & constraints
    
    private lazy var centerStateBlurView = BlurCircleView(sfSymbolName: "person.fill.turn.down")
    
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        
        // Trying to make it look like a blurry overlay
        progressView.trackTintColor = .clear
        progressView.alpha = 0.75
        
        return progressView
    }()
    
    private lazy var metadataView = MessageSymbolMetadataView()
    private lazy var metadataBlurBackgroundContainerView = MessageMetadataBlurBackgroundView(rootView: metadataView)
    
    private lazy var dateAndStateView = MessageDateAndStateView()
    private lazy var dateAndStateBlurBackgroundContainerView = MessageMetadataBlurBackgroundView(
        rootView: dateAndStateView
    )
    
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        
        return imageView
    }()
    
    private lazy var thumbnailHeightConstraint = thumbnailHeightConstraint(
        for: ChatViewConfiguration.Thumbnail.defaultAspectRatio
    )
    
    // MARK: - Configuration
    
    override func configureButton() {
        super.configureButton()

        configureLayout()
        
        clipsToBounds = true
        layer.cornerRadius = ChatViewConfiguration.Thumbnail.cornerRadius
        layer.cornerCurve = .continuous
        
        updateColors()
    }
    
    private func configureLayout() {
        // Add subviews in reverse order as the they are added on top of each other
        addSubview(thumbnailImageView)
        addSubview(dateAndStateBlurBackgroundContainerView)
        addSubview(metadataBlurBackgroundContainerView)
        addSubview(progressView)
        addSubview(centerStateBlurView)
        
        centerStateBlurView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        metadataBlurBackgroundContainerView.translatesAutoresizingMaskIntoConstraints = false
        dateAndStateBlurBackgroundContainerView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            thumbnailImageView.topAnchor.constraint(equalTo: topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
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
        
        notRequiredConstraints.forEach {
            $0.priority = .defaultHigh
        }
        
        NSLayoutConstraint.activate(notRequiredConstraints)
        
        // Set inset for thumbnail view
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: -ChatViewConfiguration.Thumbnail.defaultMargin,
            leading: -ChatViewConfiguration.Thumbnail.defaultMargin,
            bottom: -ChatViewConfiguration.Thumbnail.defaultMargin,
            trailing: -ChatViewConfiguration.Thumbnail.defaultMargin
        )
    }
        
    // MARK: - Update
    
    private func updateView(with thumbnailDisplayMessage: ThumbnailDisplayMessage?) {
        let currentBlobDisplayState = thumbnailDisplayMessage?.blobDisplayState ?? .fileNotFound
        
        // Center state view
        switch currentBlobDisplayState {
        case .remote, .downloading, .pending, .uploading, .fileNotFound:
            if let symbolName = currentBlobDisplayState.symbolName {
                showCenterStateBlurView(with: symbolName)
            }
            else {
                hideCenterStateBlurView()
            }
        case .processed, .uploaded, .dataDeleted:
            hideCenterStateBlurView()
        }
        
        // Progress view
        if case let .downloading(progress: progress) = currentBlobDisplayState {
            showProgressView()
            progressView.setProgress(progress, animated: true)
        }
        else if case let .uploading(progress: progress) = currentBlobDisplayState {
            showProgressView()
            progressView.setProgress(progress, animated: true)
        }
        else {
            hideProgressView()
        }
        
        // Metadata view
        switch currentBlobDisplayState {
        case .remote, .downloading, .pending, .uploading:
            metadataView.symbolName = thumbnailDisplayMessage?.fileMessageType.symbolName
            metadataView.metadataString = fileSizeFormatter
                .string(for: thumbnailDisplayMessage?.dataBlobFileSize)
            metadataBlurBackgroundContainerView.isHidden = false
        case .fileNotFound:
            metadataView.symbolName = nil
            metadataView.metadataString = BundleUtil.localizedString(forKey: "file_not_found_title")
            metadataBlurBackgroundContainerView.isHidden = false
        case .dataDeleted:
            metadataView.symbolName = currentBlobDisplayState.symbolName
            metadataView.metadataString = nil
            metadataBlurBackgroundContainerView.isHidden = false
        case .processed, .uploaded:
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
        
        if let thumbnailImage = thumbnailDisplayMessage?.thumbnailImage {
            thumbnailImageView.image = thumbnailImage
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
        let constraint = thumbnailImageView.heightAnchor.constraint(
            equalTo: thumbnailImageView.widthAnchor,
            multiplier: heightToWidthAspectRatio
        )
        
        // We would like to get a ratio close to that.
        // If we require exactly this aspect ratio we get unsatisfiable constraints.
        constraint.priority = .defaultHigh
        
        return constraint
    }
    
    override func updateColors() {
        super.updateColors()
        
        progressView.progressTintColor = Colors.thumbnailProgressViewColor
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
