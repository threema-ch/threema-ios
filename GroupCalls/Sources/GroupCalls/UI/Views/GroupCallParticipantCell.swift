//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
    
    var participantID: ParticipantID?
    
    var participant: ViewModelParticipant? {
        didSet {
            updateView()
        }
    }
    
    override var frame: CGRect {
        didSet {
            videoRendererView.setSize(frame.size)
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
        return label
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let avatarImageView = UIImageView()
        avatarImageView.image = UIImage(
            systemName: "person.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40 * UIScreen.main.scale)
        )
        avatarImageView.tintColor = .white
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        return avatarImageView
    }()
    
    private lazy var statusSymbolView: UIImageView = {
        let statusSymbolView = UIImageView(
            image: UIImage(systemName: "mic.slash")?
                .withConfiguration(cellConfig.stateImageConfig)
        )
        statusSymbolView.tintColor = .white
        statusSymbolView.translatesAutoresizingMaskIntoConstraints = false
        return statusSymbolView
    }()
    
    private lazy var blurBackground = GradientBlurBackgroundView()
    
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
        
        return stackView
    }()
    
    // MARK: - Private Properties
    
    private lazy var videoRendererConstrains: [NSLayoutConstraint] = {
        [
            videoRendererView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoRendererView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoRendererView.topAnchor.constraint(equalTo: contentView.topAnchor),
            videoRendererView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ]
    }()
    
    private lazy var blurBackgroundConstrains: [NSLayoutConstraint] = {
        [
            blurBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            blurBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurBackground.topAnchor.constraint(equalTo: participantInfoStackView.topAnchor),
        ]
    }()
    
    private lazy var participantInfoStackViewConstrains: [NSLayoutConstraint] = {
        [
            participantInfoStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            participantInfoStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            participantInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor),
        ]
    }()
    
    private lazy var avatarImageViewConstrains: [NSLayoutConstraint] = {
        [
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6),
        ]
    }()
    
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
        backgroundColor = .systemTeal

        contentView.addSubview(videoRendererView)
        contentView.addSubview(participantInfoStackView)
        contentView.insertSubview(avatarImageView, at: 0)
        contentView.insertSubview(blurBackground, belowSubview: participantInfoStackView)
        
        NSLayoutConstraint.activate(
            videoRendererConstrains + blurBackgroundConstrains + participantInfoStackViewConstrains +
                avatarImageViewConstrains
        )
    }
    
    private func updateView() {
        guard let participant else {
            return
        }
        
        backgroundColor = participant.idColor

        // Text Label
        nameLabel.text = participant.name
        
        // Image
        avatarImageView.image = participant.avatar ?? UIImage(
            systemName: "person.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 40 * UIScreen.main.scale)
        )
        
        // Audio
        switch participant.audioMuteState {
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
        
        // Video
        switch participant.videoMuteState {
        case .muted:
            videoRendererView.removeFromSuperview()
            blurBackground.removeFromSuperview()
            NSLayoutConstraint.deactivate(blurBackgroundConstrains + videoRendererConstrains)
            nameLabel.textColor = .white
            statusSymbolView.tintColor = .white
            
        case .unmuted:
            contentView.insertSubview(blurBackground, at: 1)
            contentView.insertSubview(videoRendererView, at: 1)
            NSLayoutConstraint.activate(blurBackgroundConstrains + videoRendererConstrains)
            nameLabel.textColor = participant.idColor
            statusSymbolView.tintColor = participant.idColor
        }
    }
}
