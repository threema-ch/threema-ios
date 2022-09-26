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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

protocol ChatBarQuoteViewDelegate: AnyObject {
    /// Handle dismissal of the quote view. The quote view will not remove itself from the view hierarchy.
    func quoteDismissed()
    /// The text inset from the left edge of the screen to allow alignment of accessory views
    var textBeginningInset: CGFloat { get }
}

final class ChatBarQuoteView: UIView {
    // MARK: - Nested Types

    private typealias Config = ChatViewConfiguration.ChatBar.QuoteView
    
    // MARK: - Private Properties

    private let quotedMessage: QuoteMessage
    private weak var delegate: ChatBarQuoteViewDelegate?
    
    private lazy var quoteView: MessageQuoteStackView = {
        let messageQuoteView = MessageQuoteStackView()
        messageQuoteView.quoteMessage = quotedMessage
        
        messageQuoteView.translatesAutoresizingMaskIntoConstraints = false
        
        return messageQuoteView
    }()
    
    private lazy var closeQuoteButton = ChatBarButton(
        sfSymbolName: "xmark.circle.fill",
        accessibilityLabel: BundleUtil.localizedString(forKey: "chat_bar_quote_close_button"),
        defaultColor: { Colors.backgroundButton },
        action: { [weak self] _ in
            self?.delegate?.quoteDismissed()
        }
    )

    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [quoteView, closeQuoteButton])
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = Config.stackViewSpacing
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var leadingConstraint: NSLayoutConstraint = {
        let leftInset = delegate?.textBeginningInset ?? Config.leadingTrailingInset
        return leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -leftInset)
    }()
    
    // MARK: - Lifecycle

    init(quotedMessage: QuoteMessage, delegate: ChatBarQuoteViewDelegate) {
        self.quotedMessage = quotedMessage
        self.delegate = delegate
        
        super.init(frame: .zero)
        
        configureLayout()
        updateColors()
        
        self.contentMode = .redraw
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration Functions

    private func updateColors() {
        quoteView.updateColors()
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
    
    // MARK: - Update Functions

    private func reconfigureLayout() {
        leadingConstraint.constant = -(delegate?.textBeginningInset ?? Config.leadingTrailingInset)
    }
    
    // MARK: - Overrides

    override func layoutSubviews() {
        super.layoutSubviews()
        reconfigureLayout()
    }
}
