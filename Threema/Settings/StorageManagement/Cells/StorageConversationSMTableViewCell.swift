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

import CocoaLumberjackSwift
import ThreemaFramework
import UIKit

class StorageConversationSMTableViewCell: ThemedCodeStackTableViewCell {

    enum CellType {
        case messages
        case files
    }
       
    private var conversation: Conversation?
    private var cellType: CellType?
            
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        label.numberOfLines = 0
        
        return label
    }()
    
    private lazy var valueLabel: CopyLabel = {
        let label = CopyLabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
        
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentStack.addArrangedSubview(labelLabel)
        contentStack.addArrangedSubview(valueLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        conversation = nil
        cellType = nil
    }
    
    override func updateColors() {
        super.updateColors()
        
        valueLabel.textColor = Colors.textLight
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            labelLabel.accessibilityLabel
        }
        set { }
    }
    
    override public var accessibilityValue: String? {
        get {
            valueLabel.accessibilityLabel
        }
        set { }
    }
        
    public func setup(cellType: CellType) {
        self.cellType = cellType
        
        switch cellType {
        case .messages:
            labelLabel.text = BundleUtil.localizedString(forKey: "messages")
        case .files:
            labelLabel.text = BundleUtil.localizedString(forKey: "files")
        }
        
        var totalCount = 0
        
        let entityManager = BusinessInjector().entityManager
        for conv in entityManager.entityFetcher.allConversations() {
            let messageFetcher = MessageFetcher(for: conv as! Conversation, with: entityManager)
            switch cellType {
            case .messages:
                totalCount += messageFetcher.count()
            case .files:
                totalCount += messageFetcher.mediaCount()
            }
        }
        
        valueLabel.text = "\(totalCount)"
    }
    
    public func setup(conversation: Conversation, cellType: CellType) {
        self.conversation = conversation
        self.cellType = cellType
        
        switch cellType {
        case .messages:
            labelLabel.text = BundleUtil.localizedString(forKey: "messages")
        case .files:
            labelLabel.text = BundleUtil.localizedString(forKey: "Files")
        }
                
        let messageFetcher = MessageFetcher(for: conversation, with: BusinessInjector().entityManager)
        switch cellType {
        case .messages:
            valueLabel.text = "\(messageFetcher.count())"
        case .files:
            valueLabel.text = "\(messageFetcher.mediaCount())"
        }
    }
}

// MARK: - Reusable

extension StorageConversationSMTableViewCell: Reusable { }
