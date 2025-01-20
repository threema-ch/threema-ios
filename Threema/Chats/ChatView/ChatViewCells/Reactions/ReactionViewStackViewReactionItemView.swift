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

import Foundation

class ReactionViewStackViewReactionItemView: UIView, ReactionViewStackViewItemViewSubView {
    
    typealias animationConfig = ChatViewConfiguration.EmojiReactions.Animation

    // MARK: - Properties

    var info: ReactionsManager.ReactionInfo {
        didSet {
            updateView()
        }
    }
    
    // MARK: - Subviews

    private lazy var countLabel: UILabel = {
        let label = UILabel()
        
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .footnote)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])

        let semiboldFont = UIFont(descriptor: descriptor, size: 0)

        label.font = semiboldFont
        label.textColor = Colors.chatReactionBubbleTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var countLabelConstraints: [NSLayoutConstraint] = [
        countLabel.leadingAnchor.constraint(equalTo: reactionLabel.trailingAnchor, constant: 2),
        countLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        countLabel.centerYAnchor.constraint(equalTo: reactionLabel.centerYAnchor),
    ]
    
    private lazy var noCountLabelConstraints: [NSLayoutConstraint] = [
        reactionLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
    ]
    
    private lazy var reactionLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var reactionLabelConstraints: [NSLayoutConstraint] = [
        reactionLabel.topAnchor.constraint(equalTo: self.topAnchor),
        reactionLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
        reactionLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor),
    ]
    
    // MARK: - Lifecycle

    init(info: ReactionsManager.ReactionInfo) {
        self.info = info
        
        super.init(frame: .zero)

        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateView(type: ReactionViewStackViewItemView.ViewType) {
        switch type {
        case let .reaction(newInfo):
            info = newInfo
        case .count, .picker:
            return
        }
    }
    
    func updateColors() {
        countLabel.textColor = Colors.chatReactionBubbleTextColor
    }
    
    private func configureView() {
        isUserInteractionEnabled = false
        
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(reactionLabel)
        
        NSLayoutConstraint.activate(reactionLabelConstraints)
        updateView()
    }
    
    private func updateView() {
        countLabel.text = "\(info.count)"
        reactionLabel.text = info.displayValue
        
        if info.count > 1 {
            UIView.animate(withDuration: animationConfig.defaultHideShowDuration) {
                self.addSubview(self.countLabel)
                
                NSLayoutConstraint.deactivate(self.noCountLabelConstraints)
                NSLayoutConstraint.activate(self.countLabelConstraints)
                
                self.countLabel.isHidden = false
                self.countLabel.alpha = 1.0
            }
        }
        else {
            NSLayoutConstraint.deactivate(countLabelConstraints)
            NSLayoutConstraint.activate(noCountLabelConstraints)
            
            UIView.animate(withDuration: animationConfig.defaultHideShowDuration) {
                self.countLabel.isHidden = true
                self.countLabel.alpha = 0.0
            } completion: { _ in
                self.countLabel.removeFromSuperview()
            }
        }
    }
}
