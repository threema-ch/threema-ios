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

import Combine
import Foundation
import ThreemaFramework
import UIKit

final class ScrollToBottomView: UIView {
    typealias Config = ChatViewConfiguration.ScrollToBottomButton
    
    // MARK: Private Properties
    
    private let scrollDownAction: () -> Void
    private var currentUnreadCount: Int?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let unreadMessagesSnapshot: UnreadMessagesStateManager
    
    private lazy var scrollDownButton: ThemedCodeButton = {
        let button = ThemedCodeButton { [weak self] _ in
            self?.scrollDownAction()
        }
        
        let image = UIImage(
            systemName: "chevron.down.circle",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .title1)
        )
        button.setImage(image, for: .normal)
        
        return button
    }()
    
    private lazy var scrollDownButtonStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            scrollDownButton,
        ])
        
        unreadCountLabel.alpha = 0.0
        stackView.addArrangedSubview(unreadCountLabel)
        
        stackView.spacing = 5
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var contentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            scrollDownButtonStack,
        ])
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private lazy var unreadCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.text = ""
        
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14.0, weight: .semibold)
        label.textColor = .systemGreen
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    private let processingQueue = DispatchQueue(label: "ch.threema.chatView.scrollToBottomView")
    
    // MARK: - Lifecycle
    
    init(unreadMessagesSnapshot: UnreadMessagesStateManager, scrollDownAction: @escaping (() -> Void)) {
        self.scrollDownAction = scrollDownAction
        self.unreadMessagesSnapshot = unreadMessagesSnapshot
        
        super.init(frame: .zero)
        
        if let unreadMessagesState = unreadMessagesSnapshot.unreadMessagesState,
           unreadMessagesState.numberOfUnreadMessages == 0 {
            // This avoids a weird animation where the width of the view will change. It is caused by the the subscription to `unreadMessagesSnapshot.$unreadMessagesState` which
            // will get the state only after the view was initially shown.
            hideUnreadCount(animated: false)
        }
        
        unreadMessagesSnapshot.$unreadMessagesState
            .debounce(for: .milliseconds(Config.dataUpdateDebounce), scheduler: processingQueue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] unreadMessagesState in
                if let unreadMessagesState = unreadMessagesState, unreadMessagesState.numberOfUnreadMessages <= 0 {
                    self?.hideUnreadCount()
                }
                else if let unreadMessagesState = unreadMessagesState {
                    self?.unreadCountLabel.text = "\(unreadMessagesState.numberOfUnreadMessages)"
                    self?.showUnreadCount()
                }
            }
            .store(in: &cancellables)
        
        unreadMessagesSnapshot.$userIsAtBottomOfTableView
            .debounce(for: .milliseconds(Config.dataUpdateDebounce), scheduler: processingQueue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userIsAtBottomOfTableView in
                if userIsAtBottomOfTableView {
                    self?.hide()
                }
                else {
                    self?.show()
                }
            }
            .store(in: &cancellables)
        
        configure()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration Functions
    
    private func configure() {
        addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: Config.topBottomInsets),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Config.topBottomInsets),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Config.topBottomInsets),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Config.topBottomInsets),
        ])
        
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        layer.cornerRadius = Config.cornerRadius
        layer.cornerCurve = .continuous
        
        alpha = 0.0
    }
    
    // MARK: - Update Functions
    
    private func show() {
        guard alpha == 0.0 else {
            return
        }
        
        UIView.animate(
            withDuration: Config.ShowHideAnimation.duration,
            delay: Config.ShowHideAnimation.delay,
            options: .curveEaseInOut
        ) { [self] in
            alpha = 1.0
        }
    }
    
    private func updateUnreadCount(_ count: Int) {
        unreadCountLabel.text = "\(count)"
        
        if count == 0 {
            currentUnreadCount = count
            hideUnreadCount()
        }
        else if count > 0, unreadCountLabel.isHidden, currentUnreadCount != count {
            currentUnreadCount = count
            showUnreadCount()
        }
    }
    
    private func hide() {
        guard alpha == 1.0 else {
            return
        }
        
        UIView.animate(
            withDuration: Config.ShowHideAnimation.duration,
            delay: Config.ShowHideAnimation.delay,
            options: .curveEaseInOut
        ) { [self] in
            alpha = 0.0
        }
        
        hideUnreadCount()
    }
    
    private func hideUnreadCount(animated: Bool = true) {
        guard animated else {
            UIView.performWithoutAnimation {
                self.unreadCountLabel.isHidden = true
                self.unreadCountLabel.text = "0"
                self.unreadCountLabel.alpha = 1.0
            }
            return
        }
        UIView.animate(withDuration: Config.ShowHideAnimation.duration, delay: Config.ShowHideAnimation.delay) {
            self.unreadCountLabel.alpha = 1.0
        }
        UIView.animate(
            withDuration: Config.ShowHideAnimation.duration,
            delay: Config.ShowHideAnimation.duration + Config.ShowHideAnimation.delay
        ) {
            self.unreadCountLabel.isHidden = true
            self.unreadCountLabel.text = "0"
        }
    }
    
    func updateColors() {
        unreadCountLabel.textColor = .primary
        backgroundColor = Colors.backgroundChatBar
    }
    
    // MARK: - Private functions
    
    private func showUnreadCount() {
        UIView
            .animate(withDuration: Config.ShowHideAnimation.duration, delay: Config.ShowHideAnimation.delay) { [self] in
                unreadCountLabel.isHidden = false
            }
        UIView.animate(
            withDuration: Config.ShowHideAnimation.duration,
            delay: Config.ShowHideAnimation.duration + Config.ShowHideAnimation.delay
        ) { [self] in
            unreadCountLabel.alpha = 1.0
        }
    }
}
