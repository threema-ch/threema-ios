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

import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ChatBarEditedMessageViewDelegate: AnyObject {
    /// Handle dismissal of the edit message view. The edit message view will not remove itself from the view hierarchy.
    func editedMessageDismissed()
    /// The text inset from the left edge of the screen to allow alignment of accessory views
    var editedMessageTextBeginningInset: CGFloat { get }
}

final class ChatBarEditedMessageView: UIView {
    // MARK: - Nested Types

    private typealias Config = ChatViewConfiguration.ChatBar.QuoteView
    
    // MARK: - Private Properties

    private let editedMessage: EditedMessage
    private weak var delegate: ChatBarEditedMessageViewDelegate?

    private lazy var editedMessageView: MessageEditedMessageStackView = {
        let messageEditedMessageView = MessageEditedMessageStackView()
        messageEditedMessageView.editedMessage = editedMessage
        messageEditedMessageView.thumbnailDistribution = .spaced
        
        messageEditedMessageView.translatesAutoresizingMaskIntoConstraints = false
        messageEditedMessageView.isAccessibilityElement = true
        
        return messageEditedMessageView
    }()
    
    private lazy var closeEditMessageButton: ChatBarButton = {
        let button = ChatBarButton(
            sfSymbolName: "xmark.circle.fill",
            accessibilityLabel: #localize("accessibility_chatbar_close_edited_message_button_label"),
            defaultColor: { Colors.backgroundButton },
            action: { [weak self] _ in
                self?.delegate?.editedMessageDismissed()
            }
        )
        button.accessibilityHint = #localize(
            "accessibility_chatbar_close_edited_message_button_hint"
        )

        return button
    }()

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [editedMessageView, closeEditMessageButton])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = Config.stackViewSpacing
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var leadingConstraint: NSLayoutConstraint = {
        let leftInset = delegate?.editedMessageTextBeginningInset ?? Config.leadingTrailingInset
        return leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -leftInset)
    }()
    
    // MARK: - Lifecycle

    init(editedMessage: EditedMessage, delegate: ChatBarEditedMessageViewDelegate) {
        self.editedMessage = editedMessage
        self.delegate = delegate
        
        super.init(frame: .zero)
        
        configureLayout()
        updateColors()
        updateAccessibility()
        
        self.contentMode = .redraw
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration Functions

    private func updateColors() {
        editedMessageView.updateColors()
        backgroundColor = .clear
    }
    
    private func configureLayout() {
        addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: contentStackView.topAnchor, constant: -Config.topBottomInset),
            leadingConstraint,
            bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: Config.topBottomInset),
            safeAreaLayoutGuide.trailingAnchor.constraint(
                equalTo: contentStackView.trailingAnchor,
                constant: Config.leadingTrailingInset
            ),
        ])
    }
    
    private func updateAccessibility() {
        guard let message = editedMessage as? MessageAccessibility else {
            return
        }
        editedMessageView.accessibilityLabel = String.localizedStringWithFormat(
            #localize("accessibility_chatbar_edited_message_label"),
            message.accessibilitySenderAndMessageTypeText
        )
    }
    
    // MARK: - Update Functions

    private func reconfigureLayout() {
        leadingConstraint.constant = -(delegate?.editedMessageTextBeginningInset ?? Config.leadingTrailingInset)
    }
    
    // MARK: - Overrides

    override func layoutSubviews() {
        super.layoutSubviews()
        reconfigureLayout()
    }
}
