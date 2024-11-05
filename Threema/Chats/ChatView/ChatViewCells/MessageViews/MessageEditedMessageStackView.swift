//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

/// Edit message content stack
final class MessageEditedMessageStackView: UIStackView {

    enum ThumbnailDistribution {
        case fill
        case spaced
    }
    
    /// Message to edit
    ///
    /// Reset it when the message had any changes to update the displayed edit message preview
    var editedMessage: EditedMessage? {
        didSet {
            guard let editedMessage else {
                return
            }
            
            updateEditMessage(editMessage: editedMessage)
        }
    }
    
    /// If set to `.spaced` the `MessageEditMessageStackView` will use the maximum allowed width for space between name
    /// / text
    /// and thumbnail for this cell
    /// Don't use this if there is no thumbnail.
    /// Defaults to no spacing.
    var thumbnailDistribution: ThumbnailDistribution = .fill {
        didSet {
            switch thumbnailDistribution {
            case .fill:
                removeArrangedSubview(spacerView)
            case .spaced:
                if !arrangedSubviews.contains(where: { $0 == spacerView }) {
                    insertArrangedSubview(spacerView, at: 1)
                }
            }
        }
    }
    
    // MARK: - Private properties
    
    private lazy var titleLabel: RTLAligningLabel = {
        let titleLabel = RTLAligningLabel()
        titleLabel.font = ChatViewConfiguration.EditedMessage.nameFont
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
      
        return titleLabel
    }()
    
    private lazy var editMessageLabel: RTLAligningLabel = {
        let editMessageLabel = RTLAligningLabel()
        editMessageLabel.adjustsFontForContentSizeCategory = true
        editMessageLabel.numberOfLines = ChatViewConfiguration.EditedMessage.maxLines

        return editMessageLabel
    }()
    
    private lazy var titleAndEditMessageStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, editMessageLabel])

        stackView.axis = .vertical

        return stackView
    }()
    
    private lazy var spacerView: UIView = {
        let spacerView = UIView()
        
        let spacerViewWidthConstraint = spacerView.widthAnchor.constraint(equalToConstant: .greatestFiniteMagnitude)
        spacerViewWidthConstraint.priority = .defaultLow
        spacerViewWidthConstraint.isActive = true
        
        return spacerView
    }()
    
    private lazy var editThumbnailView: UIImageView = {
        let thumbnailView = UIImageView(image: nil)

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true

        thumbnailView.layer.cornerRadius = ChatViewConfiguration.EditedMessage.thumbnailCornerRadius
        thumbnailView.layer.cornerCurve = .continuous

        thumbnailView.heightAnchor.constraint(lessThanOrEqualToConstant: scaledSize).isActive = true
        thumbnailView.widthAnchor.constraint(equalTo: thumbnailView.heightAnchor).isActive = true
        thumbnailView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        thumbnailView.accessibilityIgnoresInvertColors = true
        
        return thumbnailView
    }()
    
    private lazy var playButtonView = BlurCircleView(sfSymbolName: "play.fill", configuration: .thumbnail)
    
    private lazy var playButtonViewConstraints = [
        playButtonView.centerXAnchor.constraint(equalTo: editThumbnailView.centerXAnchor),
        playButtonView.centerYAnchor.constraint(equalTo: editThumbnailView.centerYAnchor),
    ]
    
    private var scaledSize: CGFloat {
        let defaultSize: CGFloat = ChatViewConfiguration.EditedMessage.thumbnailDefaultSize
        return UIFontMetrics(forTextStyle: .footnote).scaledValue(for: defaultSize)
    }
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureStackView()

        updateContent()
        updateLayout()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Configuration
    
    private func configureStackView() {
        axis = .horizontal
        spacing = ChatViewConfiguration.EditedMessage.barTextDistance
        alignment = .top
        
        isLayoutMarginsRelativeArrangement = true

        // Add subviews
        addArrangedSubview(titleAndEditMessageStackView)
        addArrangedSubview(editThumbnailView)
    }
    
    // MARK: - Updates

    private func updateEditMessage(editMessage: BaseMessage) {
        // Assign Values & configure layout
        titleLabel.text = #localize("edit")

        updateContent()
        updateLayout()
    }
    
    func updateColors() {
        // The image in the edit message only gets updated if we set it new again
        updateContent()
        
        Colors.setTextColor(Colors.textLight, label: titleLabel)
        Colors.setTextColor(Colors.textLight, label: editMessageLabel)
    }
    
    private func updateContent() {
        
        guard let editedMessage else {
            return
        }
        
        if titleLabel.text != nil {
            titleAndEditMessageStackView.spacing = ChatViewConfiguration.EditedMessage.nameTextDistance
        }
        else {
            titleAndEditMessageStackView.spacing = 0
        }
        
        editMessageLabel.attributedText = editedMessage.previewAttributedText(for: .default)

        // We need to set the font explicitly to make the label set its height correctly
        editMessageLabel.font = PreviewableMessageConfiguration.default.font

        if let (thumbnail, _) = editedMessage.mediaPreview {
            editThumbnailView.image = thumbnail
        }
    }
    
    private func updateLayout() {
        
        // Don't show thumbnail with accessibility fonts
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            playButtonView.removeFromSuperview()
            editThumbnailView.image = nil
            editThumbnailView.isHidden = true
            return
        }
        
        if let (_, isPlayable) = editedMessage?.mediaPreview {

            editThumbnailView.isHidden = false

            if isPlayable {
                playButtonView.translatesAutoresizingMaskIntoConstraints = false
                editThumbnailView.addSubview(playButtonView)
                NSLayoutConstraint.activate(playButtonViewConstraints)
            }
            else {
                playButtonView.removeFromSuperview()
            }
        }
        else {
            // Reset everything concerning the thumbnail
            playButtonView.removeFromSuperview()
            editThumbnailView.image = nil
            editThumbnailView.isHidden = true
        }
    }
}
