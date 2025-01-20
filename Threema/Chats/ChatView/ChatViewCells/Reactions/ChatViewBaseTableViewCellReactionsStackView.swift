//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

class ChatViewBaseTableViewCellReactionsStackView: UIStackView {
    
    enum StackViewSize {
        case tiny, small, full
        
        var maxItemCount: Int {
            switch self {
            case .tiny:
                2
            case .small:
                3
            case .full:
                4
            }
        }
    }
    
    typealias config = ChatViewConfiguration.EmojiReactions.CellStackView
    typealias animationConfig = ChatViewConfiguration.EmojiReactions.Animation

    // MARK: - Private properties

    private(set) var reactionsManager: ReactionsManager
    
    private let stackViewSize: StackViewSize
    
    private var cancellables = Set<AnyCancellable>()
    
    private let countView: ReactionViewStackViewItemView
    private var pickerItemView: ReactionViewStackViewItemView?
    
    private lazy var longPressGestureRecognizer = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handleLongPress(_:))
    )
    
    private var itemCountFontSizeOverride: Int {
        if traitCollection.preferredContentSizeCategory >= .extraLarge {
            return 3
        }
        return 4
    }
    
    // MARK: - Lifecycle

    init(reactionsManager: ReactionsManager, size: StackViewSize) {
        self.reactionsManager = reactionsManager
        self.stackViewSize = size
        
        self.countView = ReactionViewStackViewItemView(reactionsManager: reactionsManager, type: .count(count: 0))
        
        super.init(frame: .zero)
        
        configureView()
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureView() {
        spacing = config.itemSpacing
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            axis = .vertical
        }
        else {
            axis = .horizontal
        }
       
        if reactionsManager.pickerButtonVisible() {
            let pickerItem = ReactionViewStackViewItemView(reactionsManager: reactionsManager, type: .picker)
            pickerItemView = pickerItem
            addArrangedSubview(pickerItem)
        }
        
        reactionsManager.$currentReactions.sink { newInfos in
            self.updateSubviews(newInfos: newInfos)
        }
        .store(in: &cancellables)
        
        addGestureRecognizer(longPressGestureRecognizer)
    }
    
    public func updateColors() {
        for case let arrangedSubview as ReactionViewStackViewItemView in arrangedSubviews {
            arrangedSubview.updateColors()
        }
    }

    // MARK: - Private functions
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            reactionsManager.showExistingReactions()
        default:
            break
        }
    }
    
    private func updateSubviews(newInfos: [ReactionsManager.ReactionInfo]) {
        let maxItemCount = min(stackViewSize.maxItemCount, itemCountFontSizeOverride)
        let tempInfos = newInfos.prefix(maxItemCount)
        
        // Picker button
        if reactionsManager.pickerButtonVisible(), pickerItemView == nil {
            let pickerItem = ReactionViewStackViewItemView(reactionsManager: reactionsManager, type: .picker)
            pickerItemView = pickerItem
            addArrangedSubview(pickerItem)
        }
        
        // Count view
        let count = max(newInfos.count - maxItemCount, 0)
        countView.type = .count(count: count)
        if count > 0 {
            if !arrangedSubviews.contains(countView) {
                insertArrangedSubview(countView, at: max(arrangedSubviews.count - 2, 0))
            }
        }
        else {
            countView.removeFromSuperview()
        }
        
        // Reaction views
        
        // We remove arranged subviews with reactions that are not present in the new info
        for case let existingReactionView as ReactionViewStackViewItemView in arrangedSubviews {
            if case let .reaction(info) = existingReactionView.type {
                let matchingReaction = tempInfos.first {
                    $0.reactionString == info.reactionString
                }
                
                if matchingReaction == nil {
                    UIView.animate(withDuration: 0.3) {
                        existingReactionView.removeFromSuperview()
                    }
                }
            }
        }
        
        // Get remaining reactions
        var remainingReactionViews = [ReactionViewStackViewItemView]()
        
        for arrangedSubview in arrangedSubviews {
            guard let reactionView = arrangedSubview as? ReactionViewStackViewItemView,
                  case .reaction = reactionView.type else {
                continue
            }
            remainingReactionViews.append(reactionView)
        }
        
        // Then we either update and move the existing view or create a new one
        for (index, newInfo) in tempInfos.enumerated() {
            let existingView = remainingReactionViews.first {
                guard case let .reaction(info) = $0.type else {
                    return false
                }
                return info.reactionString == newInfo.reactionString
            }
            
            if let existingView {
                UIView.animate(withDuration: animationConfig.defaultHideShowDuration) {
                    self.insertArrangedSubview(existingView, at: index)
                } completion: { _ in
                    existingView.type = .reaction(info: newInfo)
                }
            }
            else {
                let newView = ReactionViewStackViewItemView(
                    reactionsManager: reactionsManager,
                    type: .reaction(info: newInfo)
                )

                insertArrangedSubview(newView, at: index)

                UIView.animate(withDuration: animationConfig.defaultHideShowDuration) {
                    newView.isHidden = false
                    newView.alpha = 1.0
                }
            }
        }
    }
}
