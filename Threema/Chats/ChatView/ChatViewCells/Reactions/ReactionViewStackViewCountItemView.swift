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

class ReactionViewStackViewCountItemView: UIView, ReactionViewStackViewItemViewSubView {
    
    // MARK: - Properties

    var count: Int {
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
        countLabel.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
        countLabel.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
        countLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
        countLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
    ]
    
    // MARK: - Lifecycle
    
    init(count: Int) {
        self.count = count
        super.init(frame: .zero)
        configureView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateView(type: ReactionViewStackViewItemView.ViewType) {
        switch type {
        case .reaction, .picker:
            return
        case let .count(count):
            self.count = count
        }
    }
    
    func updateColors() {
        countLabel.textColor = Colors.chatReactionBubbleTextColor
    }
    
    private func configureView() {
        isUserInteractionEnabled = false

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(countLabel)
        
        NSLayoutConstraint.activate(countLabelConstraints)
        updateView()
    }
    
    private func updateView() {
        countLabel.text = "+\(count)"
    }
}
