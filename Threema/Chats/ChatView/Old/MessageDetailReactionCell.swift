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

import Foundation
import UIKit

@objc open class MessageDetailReactionCell: UITableViewCell {
    
    private let entityManager = BusinessInjector().entityManager
    
    private var groupDeliveryReceipt: GroupDeliveryReceipt? {
        didSet {
            if groupDeliveryReceipt?.identity == MyIdentityStore.shared().identity {
                textLabel?.text = BundleUtil.localizedString(forKey: "Me")
            }
            else {
                if let contact = entityManager.entityFetcher.contact(for: groupDeliveryReceipt?.identity) {
                    textLabel?.text = contact.displayName
                }
                else {
                    textLabel?.text = groupDeliveryReceipt?.identity
                }
            }
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = groupDeliveryReceipt?.icon()

            detailTextLabel?.attributedText = NSAttributedString(attachment: imageAttachment)
        }
    }
    
    @objc override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = Colors.backgroundTableViewCell
        selectionStyle = .none
    }
        
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func setGroupDeliveryReceipt(groupDeliveryReceipt: GroupDeliveryReceipt) {
        self.groupDeliveryReceipt = groupDeliveryReceipt
    }
}
