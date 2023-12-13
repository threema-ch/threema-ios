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

import CocoaLumberjackSwift
import DSWaveformImage
import Foundation
import ThreemaFramework
import UIKit

protocol MessageVoiceMessageWaveformViewDelegate: AnyObject {
    func updateProgress(to progress: CGFloat)
}

/// Creates a waveform and shows the play progress as indicated by `delegate`
/// Should be used in an UIStackView because otherwise the `intrinsicContentSize` might not make sense.
/// Does *not* handle cleanup of created temporary files. Cleanup *must* be handled by the initializer.
///
/// This view is a bit weird in that it lies about its intrinsicContentSize to grow as large as possible in the first
/// layout pass.
/// But then uses an image slightly smaller than its actual size to avoid triggering further layout passes that happen
/// when this is embedded in a UIStackView with other views which are slightly larger than their intrinsicContentSize.
/// An alternative approach to this problem is to assure that all other views in the UIStackView are exactly the size of
/// their intrinsicContentSize.
final class MessageVoiceMessageWaveformView: UIView, UIGestureRecognizerDelegate {
    typealias config = ChatViewConfiguration.VoiceMessage.WaveformView
    
    // MARK: - Internal Properties

    /// `VoiceMessage` for which the waveform and playback should be calculated
    weak var voiceMessage: VoiceMessage? {
        willSet {
            defer { lastBlobState = newValue?.blobDisplayState }
            
            guard let newValue else {
                updateView(with: nil)
                return
            }

            guard newValue.objectID == voiceMessage?.objectID else {
                updateView(with: newValue)
                return
            }
            
            switch newValue.blobDisplayState {
            case .remote, .processed, .pending, .uploading, .uploaded, .dataDeleted, .fileNotFound, .sendingError:
                guard newValue.blobDisplayState == lastBlobState else {
                    updateView(with: newValue)
                    return
                }
            case .downloading:
                break
            }
        }
    }
    
    weak var delegate: ChatViewTableViewVoiceMessageCellDelegateProtocol? {
        didSet {
            guard let voiceMessage else {
                return
            }
            
            guard let delegate else {
                return
            }
            
            updateProgressWaveform(delegate.getProgress(for: voiceMessage))
        }
    }
    
    // MARK: - UIView Overrides
    
    /// This does not return the real `intrinsicContentSize` but a value which works well in self-sizing cells /
    /// UIStackViews
    override var intrinsicContentSize: CGSize {
        /// We do not return our real intrinsic content size here to avoid shrinking the message cell beyond the maximum
        /// width.
        CGSize(width: UIScreen.main.bounds.width, height: config.waveformRenderHeight)
    }
    
    // MARK: - Private Properties

    private var lastBlobState: BlobDisplayState?
    private weak var waveformDelegate: MessageVoiceMessageWaveformViewDelegate?
    private var previousBoundsSize: CGSize?
    
    // MARK: - Views
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var progressImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    // MARK: - Lifecycle
    
    init(waveformDelegate: MessageVoiceMessageWaveformViewDelegate? = nil) {
        self.waveformDelegate = waveformDelegate
        
        super.init(frame: .zero)
        
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        let gestureRecognizer = UITapGestureRecognizer()
        gestureRecognizer.delegate = self
        gestureRecognizer.addTarget(self, action: #selector(handleTap(sender:)))
        addGestureRecognizer(gestureRecognizer)
        
        let swipeGestureRecognizer = UIPanGestureRecognizer()
        swipeGestureRecognizer.delegate = self
        swipeGestureRecognizer.addTarget(self, action: #selector(handleSwipe(sender:)))
        addGestureRecognizer(swipeGestureRecognizer)
        
        addSubview(imageView)
        addSubview(progressImageView)
        
        /// `imageView` and `progressImageView` should always have the same constraints.
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: config.waveformImageInset),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.waveformImageInset),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.waveformImageInset),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.waveformImageInset),
            
            progressImageView.topAnchor.constraint(equalTo: topAnchor, constant: config.waveformImageInset),
            progressImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.waveformImageInset),
            progressImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.waveformImageInset),
            progressImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.waveformImageInset),
        ])
    }
    
    // MARK: - Update Functions
    
    func updateColor() {
        updateView(with: voiceMessage)
    }
    
    private func updateView(with voiceMessage: VoiceMessage?) {
        guard
            voiceMessage?.objectID != self.voiceMessage?.objectID else {
            return
        }
        
        guard let audioURL = blobDataURL(for: voiceMessage) else {
            let msg = "URL for blobdata was unexpectedly nil"
            DDLogError(msg)
            assertionFailure(msg)
            return
        }
        
        Task {
            await updateWaveformImageViews(with: audioURL, and: voiceMessage?.objectID)
        }
    }
   
    private func updateWaveformImageViews(with audioURL: URL, and identifier: NSManagedObjectID?) async {
        guard let identifier else {
            return
        }
        
        /// WaveformImageDrawer returns a generic error if the width used in `Waveform.Configuration` is zero.
        let viewSize = imageView.frame.size
        let viewWidth = viewSize.width
        guard viewWidth > 0 else {
            return
        }
        
        let start = CACurrentMediaTime()
        
        let configuredSize = targetImageSize(from: imageView)
        let completeWaveformConfig = waveformConfig(size: configuredSize, color: Colors.textLight)
        let progressConfig = waveformConfig(size: configuredSize, color: .primary)
        let analyzer = WaveformAnalyzer(audioAssetURL: audioURL)
        let sampleCount = Int(completeWaveformConfig.size.width * completeWaveformConfig.scale)
        let waveformDrawer = DSWaveformImage.WaveformImageDrawer()
        let waveformRenderer = LinearWaveformRenderer()
        let samples = await (try? analyzer?.samples(count: sampleCount)) ?? []
        let image = waveformDrawer.waveformImage(
            from: samples,
            with: completeWaveformConfig,
            renderer: waveformRenderer
        )
        let progressImage = waveformDrawer.waveformImage(
            from: samples,
            with: progressConfig,
            renderer: waveformRenderer
        )
        
        guard let image, let progressImage else {
            let msg = "Could not create waveform from url"
            assertionFailure(msg)
            DDLogError(msg)
            return
        }
        
        let renderedEnd = CACurrentMediaTime()
        DDLogVerbose("Rendered Waveform in \(renderedEnd - start)s")
        
        DispatchQueue.main.async {
            self.imageView.image = image
            self.progressImageView.image = progressImage
        }
    }
    
    /// Adjusts progress indication
    /// Should only be called after the view was successfully laid out
    /// - Parameter progress: progress between `0.0` and `1.0`
    @MainActor func updateProgressWaveform(_ progress: Double) {
        let fullRect = imageView.frame
        let newWidth = Double(fullRect.size.width) * progress

        let maskLayer = CAShapeLayer()
        let maskRect = CGRect(x: 0.0, y: 0.0, width: newWidth, height: Double(fullRect.size.height))

        let path = CGPath(rect: maskRect, transform: nil)
        maskLayer.path = path

        progressImageView.layer.mask = maskLayer
    }
    
    // MARK: - Action Functions
    
    /// Update current playback progress (even when the message was paused or never played) when tap ends
    @objc func handleTap(sender: UITapGestureRecognizer) {
        updateProgress(from: sender)
    }
    
    @objc func handleSwipe(sender: UIPanGestureRecognizer) {
        updateProgress(from: sender)
    }
    
    private func updateProgress(from sender: UIGestureRecognizer) {
        let location = sender.location(in: imageView)
        let progress = location.x / imageView.frame.width
        
        updateProgressWaveform(progress)
        waveformDelegate?.updateProgress(to: progress)
    }
    
    // MARK: - Helper Functions
    
    private func blobDataURL(for voiceMessage: VoiceMessage?) -> URL? {
        guard let silentAudioURL = BundleUtil.url(forResource: "silent", withExtension: "mp3") else {
            let msg = "URL for silent audio file was unexpectedly nil"
            DDLogError(msg)
            assertionFailure(msg)
            return nil
        }
        
        guard let voiceMessage else {
            imageView.image = nil
            return silentAudioURL
        }
        
        /// We can only play successfully processed messages or messages that were created by us
        guard voiceMessage.blobDisplayState == .processed || voiceMessage.isOwnMessage else {
            return silentAudioURL
        }

        /// If we do not have access to the blob we do nothing else and return
        guard let audioURL = voiceMessage.temporaryBlobDataURL() else {
            return silentAudioURL
        }
        
        return audioURL
    }
    
    private func targetImageSize(from view: UIView) -> CGSize {
        let viewSize = view.frame.size
        let viewWidth = viewSize.width
        
        let mod = config.singleBarWidth + config.barSpacing
        /// We use the next lower multiple of the sum of the bar width and the spacing between two bars to avoid cutting
        /// off bars in our view.
        /// Rounding up caused a weird behaviour where the imageview would increase in steps of the size of the
        /// difference
        /// between original value and rounded up value until auto-layout found a new layout again. We thus round down.
        let targetWidth = viewWidth - mod + (viewWidth.truncatingRemainder(dividingBy: mod))
        return CGSize(width: targetWidth, height: viewSize.height)
    }
    
    private func waveformConfig(size: CGSize, color: UIColor) -> Waveform.Configuration {
        let singleBarWidth = config.singleBarWidth
        let spacing = config.barSpacing
        
        return Waveform.Configuration(
            size: size,
            style: .striped(.init(color: color, width: singleBarWidth, spacing: spacing)),
            verticalScalingFactor: 0.8,
            shouldAntialias: true
        )
    }
    
    // MARK: - UIView Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let previousBoundsSize else {
            return
        }

        /// If our bounds change we rerender the waveform
        guard previousBoundsSize != bounds.size else {
            return
        }
        defer { self.previousBoundsSize = bounds.size }
        
        DDLogVerbose("Rendering waveform for size \(bounds.size)")
        
        updateView(with: voiceMessage)
    }
}
