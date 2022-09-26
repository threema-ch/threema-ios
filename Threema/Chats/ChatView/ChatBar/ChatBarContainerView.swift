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

/// Contains the chatbar and any accessory views related to the chatbar
final class ChatBarContainerView: UIView {
    
    // MARK: - Private properties
    
    private weak var chatBarView: ChatBarView?
    
    private weak var quoteView: ChatBarQuoteView?
    private weak var mentionsTableView: MentionsTableViewController?
    
    private lazy var accessoryView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [topHairlineView])
        stackView.axis = .vertical
        
        return stackView
    }()
    
    private lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        return blurEffectView
    }()
    
    private lazy var topHairlineView = UIView()
    private var mentionsTableViewHeightConstraint: NSLayoutConstraint?
    
    // MARK: Lifecycle
    
    init() {
        super.init(frame: .zero)
        
        configureLayout()
        updateColors()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Configuration
    
    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(accessoryView)
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            accessoryView.topAnchor.constraint(equalTo: topAnchor),
            accessoryView.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessoryView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        topHairlineView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topHairlineView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
        
        addSubview(blurEffectView)
        sendSubviewToBack(blurEffectView)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    // MARK: Updates
    
    /// Updates the ChatBarContainerview instance with this chatBarView
    /// - Parameter chatBarView:
    func add(_ chatBarView: ChatBarView) {
        guard chatBarView != self.chatBarView else {
            return
        }
        
        if self.chatBarView != nil {
            removeChatBarView()
        }
        
        self.chatBarView = chatBarView
        
        addSubview(chatBarView)
        chatBarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chatBarView.topAnchor.constraint(equalTo: accessoryView.bottomAnchor),
            chatBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chatBarView.bottomAnchor.constraint(equalTo: bottomAnchor),
            chatBarView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        layoutIfNeeded()
    }
    
    /// Removes the currently set ChatBarView instance from this container
    func removeChatBarView() {
        chatBarView?.removeFromSuperview()
        chatBarView = nil
        
        layoutIfNeeded()
    }
    
    func add(_ mentionsTableViewController: MentionsTableViewController) {
        guard mentionsTableViewController != mentionsTableView else {
            return
        }
        
        if mentionsTableView != nil {
            removeMentionsTableView()
        }
        
        mentionsTableView = mentionsTableViewController
        
        accessoryView.insertArrangedSubview(mentionsTableViewController.view, at: 0)
        
        mentionsTableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        updateMentionsTableViewHeight()
        
        layoutIfNeeded()
    }
    
    func removeMentionsTableView() {
        updateMentionsTableViewHeight(overwriteHeight: 0.0) { _ in
            self.mentionsTableView?.view.removeFromSuperview()
            self.mentionsTableView = nil
        }
    }
    
    func add(_ quoteView: ChatBarQuoteView) {
        guard self.quoteView != quoteView else {
            return
        }
        
        if self.quoteView != nil {
            removeQuoteView()
        }
        
        self.quoteView = quoteView
        
        accessoryView.insertArrangedSubview(quoteView, at: accessoryView.arrangedSubviews.count)
        accessoryView.bringSubviewToFront(quoteView)
        
        quoteView.translatesAutoresizingMaskIntoConstraints = false
        
        layoutIfNeeded()
    }
    
    func removeQuoteView() {
        quoteView?.removeFromSuperview()
        quoteView = nil
        layoutIfNeeded()
    }
    
    func updateColors() {
        topHairlineView.backgroundColor = Colors.backgroundButton
        
        if UIAccessibility.isReduceTransparencyEnabled {
            backgroundColor = Colors.backgroundChatBar
        }
        else {
            // This should give an effect similar to the one in the tab bar
            backgroundColor = .clear
        }
    }
    
    // MARK: Updates for Coordinator
    
    func updateMentionsTableViewHeight(overwriteHeight: CGFloat? = nil, onCompletion: ((Bool) -> Void)? = nil) {
        guard let mentionsTableView = mentionsTableView else {
            DDLogError("Should not call updateMentionsTableViewHeight without mentionsTableView")
            return
        }
        
        layoutIfNeeded()
        
        let maxHeight: CGFloat = overwriteHeight ?? min(
            ChatViewConfiguration.MentionsView.maxHeight,
            Double(mentionsTableView.tableView.contentSize.height)
        )
        
        mentionsTableViewHeightConstraint?.isActive = false
        mentionsTableViewHeightConstraint = mentionsTableView.view.heightAnchor
            .constraint(equalToConstant: maxHeight)
        mentionsTableViewHeightConstraint?.isActive = true
        
        UIView.animate(
            withDuration: ChatViewConfiguration.ChatBar.ContentInsetAnimation.totalDuration,
            delay: ChatViewConfiguration.ChatBar.ContentInsetAnimation.delay,
            options: .curveEaseInOut,
            animations: { [weak self] in
                self?.layoutIfNeeded()
            },
            completion: onCompletion
        )
    }
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        chatBarView?.becomeFirstResponder() ?? false
    }
}
