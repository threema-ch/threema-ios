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

import Foundation

class ConversationDescriptionCell: UICollectionViewCell {
    private var conversationDescription: NSAttributedString?
    
    override var isAccessibilityElement: Bool {
        set { }
        get {
            true
        }
    }
    
    static var descriptionLabel: UILabel = {
        let label =
            UILabel(frame: CGRect(
                x: 0,
                y: 0,
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ))
        label.numberOfLines = 2
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        
        return label
    }()
    
    private lazy var conversationDescriptionLabel: UILabel = {
        let label = ConversationDescriptionCell.descriptionLabel
        label.frame = contentView.frame
        label.attributedText = conversationDescription
        
        return label
    }()
    
    init(conversationDescription: NSAttributedString) {
        self.conversationDescription = conversationDescription
        
        super.init(frame: .zero)
        
        configureLayout()
        setColors()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureLayout()
        setColors()
    }
    
    func setupCell(conversationDescription: NSAttributedString) {
        self.conversationDescription = conversationDescription
        conversationDescriptionLabel.attributedText = self.conversationDescription
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColors() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    private func configureLayout() {
        contentView.addSubview(conversationDescriptionLabel)
        contentView.bringSubviewToFront(conversationDescriptionLabel)
        
        NSLayoutConstraint.activate([
            conversationDescriptionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            conversationDescriptionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}
