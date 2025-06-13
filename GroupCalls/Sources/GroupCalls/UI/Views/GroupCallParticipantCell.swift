//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import Combine
import Foundation
import UIKit
import WebRTC

class GroupCallParticipantCell: UICollectionViewCell {
    
    typealias cellConfig = GroupCallUIConfiguration.ParticipantCell

    // MARK: - Public / Internal Properties

    static let reuseIdentifier = "GroupCallParticipantCell"
        
    var participant: ViewModelParticipant? {
        didSet {
            updateView()
        }
    }
    
    // We do a round-trip here since the accessibilityLabel getter below does not support concurrency.
    var computedAccessibilityLabel = ""
    
    override var frame: CGRect {
        didSet {
            videoRendererView.setSize(frame.size)
            clip()
        }
    }
    
    override public var bounds: CGRect {
        didSet {
            Task { @MainActor in
                clip()
            }
        }
    }
    
    // MARK: - Subviews

    lazy var videoRendererView: RTCMTLVideoView = {
        let view = RTCMTLVideoView(frame: .zero)
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: cellConfig.nameTextStyle)
        label.textColor = .white
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        return label
    }()
    
    private lazy var profilePictureView: UIImageView = {
        let profilePictureView = UIImageView()
        profilePictureView.image = UIImage(
            systemName: "person.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40 * UIScreen.main.scale)
        )
        profilePictureView.tintColor = .white
        profilePictureView.contentMode = .scaleAspectFit
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        return profilePictureView
    }()
    
    private lazy var statusSymbolView: UIImageView = {
        let statusSymbolView = UIImageView(
            image: UIImage(systemName: "mic.slash")
        )
        
        statusSymbolView.preferredSymbolConfiguration = cellConfig.stateImageConfig
        statusSymbolView.tintColor = .white
        statusSymbolView.translatesAutoresizingMaskIntoConstraints = false
        statusSymbolView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return statusSymbolView
    }()
    
    private lazy var blurBackground = {
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        return visualEffectView
    }()
    
    private lazy var participantInfoStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [statusSymbolView, nameLabel])
        stackView.alignment = .leading

        stackView.layoutMargins = UIEdgeInsets(
            top: cellConfig.cellInset,
            left: cellConfig.cellInset,
            bottom: cellConfig.cellInset,
            right: cellConfig.cellInset
        )
        
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.insetsLayoutMarginsFromSafeArea = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.spacing = 4
        
        return stackView
    }()
    
    // MARK: - Private Properties
        
    private lazy var blurBackgroundConstrains: [NSLayoutConstraint] = [
        blurBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        blurBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        blurBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        blurBackground.topAnchor.constraint(equalTo: participantInfoStackView.topAnchor),
    ]
    
    private lazy var participantInfoStackViewConstrains: [NSLayoutConstraint] = [
        participantInfoStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        participantInfoStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        participantInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
    ]
    
    private lazy var profilePictureViewConstrains: [NSLayoutConstraint] = [
        profilePictureView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        profilePictureView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
    ]
    
    private lazy var profilePictureViewWidthConstraint: [NSLayoutConstraint] = [
        profilePictureView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4),
        profilePictureView.widthAnchor.constraint(equalTo: profilePictureView.heightAnchor),
    ]
    
    // Used when running for screenshots
    private lazy var profilePictureViewWidthConstraintScreenshots: [NSLayoutConstraint] = [
        profilePictureView.widthAnchor.constraint(equalTo: contentView.widthAnchor),
    ]
    
    // Used when running for screenshots
    private lazy var profilePictureViewHeightConstraintScreenshots: [NSLayoutConstraint] = [
        profilePictureView.heightAnchor.constraint(equalTo: contentView.heightAnchor),
    ]
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureCell()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    private func configureCell() {
        layer.cornerRadius = 5
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        
        backgroundColor = .systemTeal

        contentView.addSubview(videoRendererView)
        contentView.addSubview(participantInfoStackView)
        contentView.insertSubview(profilePictureView, at: 0)
        contentView.insertSubview(blurBackground, belowSubview: participantInfoStackView)
        
        NSLayoutConstraint.activate(
            videoRendererViewConstraints() + blurBackgroundConstrains + participantInfoStackViewConstrains +
                profilePictureViewConstrains + profilePictureViewWidthConstraint
        )
        
        isAccessibilityElement = true
    }
    
    // MARK: - Public functions

    public func hideRenderer() {
        videoRendererView.removeFromSuperview()
        blurBackground.removeFromSuperview()
        NSLayoutConstraint.deactivate(blurBackgroundConstrains + videoRendererViewConstraints())
        nameLabel.textColor = .white
        statusSymbolView.tintColor = .white
    }
    
    public func showRenderer() {
        contentView.insertSubview(blurBackground, at: 1)
        contentView.insertSubview(videoRendererView, at: 1)
        NSLayoutConstraint.activate(blurBackgroundConstrains + videoRendererViewConstraints())
        nameLabel.textColor = participant?.idColor ?? .black
        statusSymbolView.tintColor = participant?.idColor ?? .black
    }
    
    public func resetRendererView() {
        // Remove
        videoRendererView.removeFromSuperview()
        NSLayoutConstraint.deactivate(videoRendererViewConstraints())
        
        // Create
        let view = RTCMTLVideoView(frame: .zero)
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        videoRendererView = view
        
        // Add
        contentView.addSubview(videoRendererView)
        NSLayoutConstraint.activate(videoRendererViewConstraints())
    }
    
    // MARK: - Private functions

    private func updateView() {
        
        guard let participant else {
            return
        }
        
        Task {
            // Gather information
            let idColor = participant.idColor
            let displayName = participant.displayName
            let profilePicture = participant.profilePicture
            let audioMuteState = await participant.audioMuteState
            let isRunningForScreenshots = participant.dependencies.isRunningForScreenshots
            
            computedAccessibilityLabel = await participant.cellAccessibilityLabel()
            
            var localActiveCameraPosition: CameraPosition?
            if let localParticipant = participant as? LocalParticipant {
                localActiveCameraPosition = await localParticipant.activeCameraPosition
            }
            
            // Apply information
            Task { @MainActor in
                backgroundColor = idColor
                
                // Text
                nameLabel.text = displayName
                
                if isRunningForScreenshots {
                    nameLabel.textColor = idColor
                }
                
                // Image
                profilePictureView.image = profilePicture
                
                if isRunningForScreenshots {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        NSLayoutConstraint.activate(profilePictureViewHeightConstraintScreenshots)

                        switch participant.threemaIdentity.string {
                        case "H3BK2FVH", "VK55MZ3W", "OOOBNWYK", "OOO8U3TJ":
                            profilePictureView.contentMode = .scaleAspectFit
                        default:
                            profilePictureView.contentMode = .scaleAspectFill
                        }
                    }
                    else {
                        NSLayoutConstraint.activate(profilePictureViewWidthConstraintScreenshots)
                        
                        participant.threemaIdentity
                        
                        switch participant.threemaIdentity.string {
                        case "H3BK2FVH":
                            if participant.displayName == "Peter Schreiner" {
                                profilePictureView.contentMode = .scaleAspectFit
                            }
                            else {
                                profilePictureView.contentMode = .scaleAspectFill
                            }
                        case "OOOBNWYK":
                            profilePictureView.contentMode = .scaleAspectFit
                        default:
                            profilePictureView.contentMode = .scaleAspectFill
                        }
                    }
                    
                    NSLayoutConstraint.deactivate(profilePictureViewWidthConstraint)
                    NSLayoutConstraint.activate(blurBackgroundConstrains)
                    contentView.insertSubview(blurBackground, at: 1)
                    clip()
                }
                else {
                    clip()
                }
                
                // Audio
                if isRunningForScreenshots {
                    if participant.participantID.id != 3 {
                        participantInfoStackView.removeArrangedSubview(statusSymbolView)
                        statusSymbolView.removeFromSuperview()
                    }
                    statusSymbolView.tintColor = idColor
                }
                else {
                    switch audioMuteState {
                    case .muted:
                        UIView.animate(withDuration: 0.2) {
                            self.participantInfoStackView.insertArrangedSubview(self.statusSymbolView, at: 0)
                        }
                    case .unmuted:
                        UIView.animate(withDuration: 0.2) {
                            self.participantInfoStackView.removeArrangedSubview(self.statusSymbolView)
                            self.statusSymbolView.removeFromSuperview()
                        }
                    }
                }
                
                // Video mirroring
                if let localActiveCameraPosition,
                   localActiveCameraPosition == .front {
                    videoRendererView.transform = CGAffineTransformMakeScale(-1, 1)
                }
                else {
                    videoRendererView.transform = CGAffineTransformMakeScale(1, 1)
                }
            }
        }
    }
    
    private func clip() {
        
        guard let participant,
              !participant.dependencies.isRunningForScreenshots else {
            return
        }
        
        profilePictureView.layer.masksToBounds = true
        profilePictureView.clipsToBounds = true
        profilePictureView.layer.cornerRadius = profilePictureView.frame.width / 2
    }
    
    private func videoRendererViewConstraints() -> [NSLayoutConstraint] {
        [
            videoRendererView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoRendererView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoRendererView.topAnchor.constraint(equalTo: contentView.topAnchor),
            videoRendererView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ]
    }
    
    override public var accessibilityLabel: String? {
        
        get {
            computedAccessibilityLabel
        }
        
        set {
            // No-op
        }
    }
}
