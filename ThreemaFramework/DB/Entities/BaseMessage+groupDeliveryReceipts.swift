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

extension BaseMessage {
    /// State of this message
    public enum GroupReactionsState {
        // Common
        case none
        case acknowledged
        case declined
        case acknowledgedAndDeclined
    }
    
    public var messageGroupReactionState: GroupReactionsState {
        
        // We don't show state in system messages
        if self is SystemMessageEntity {
            return .none
        }
        
        guard isGroupMessage else {
            return .none
        }
        
        let acknowledged = groupReactionsCount(of: .acknowledged)
        let declined = groupReactionsCount(of: .declined)
        
        if acknowledged > 0, declined > 0 {
            return .acknowledgedAndDeclined
        }
        else if acknowledged > 0 {
            return .acknowledged
        }
        else if declined > 0 {
            return .declined
        }

        return .none
    }
    
    public var groupReactionsThumbsUpImage: UIImage? {
        if isMyReaction(.acknowledged) {
            return UIImage(systemName: "hand.thumbsup.fill")?
                .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
        }
        return UIImage(systemName: "hand.thumbsup")?
            .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
    }
    
    public var groupReactionsThumbsDownImage: UIImage? {
        if isMyReaction(.declined) {
            return UIImage(systemName: "hand.thumbsdown.fill")?
                .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
        }
        return UIImage(systemName: "hand.thumbsdown")?
            .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
    }
    
    @objc public func add(groupDeliveryReceipt: GroupDeliveryReceipt) {
       
        // Do not save acks/decs for deleted messages
        if groupDeliveryReceipt.deliveryReceiptType() == .acknowledged || groupDeliveryReceipt
            .deliveryReceiptType() == .declined, deletedAt != nil {
            return
        }
            
        if groupDeliveryReceipts == nil {
            groupDeliveryReceipts = [GroupDeliveryReceipt]()
        }
        
        if let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt],
           let index = deliveryReceipts.firstIndex(where: { $0.identity == groupDeliveryReceipt.identity }) {
            groupDeliveryReceipts.remove(at: index)
            groupDeliveryReceipts.insert(groupDeliveryReceipt, at: index)
        }
        else {
            groupDeliveryReceipts.append(groupDeliveryReceipt)
        }
    }
    
    public func groupReactionsCount(of type: GroupDeliveryReceipt.DeliveryReceiptType) -> Int {
        guard let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt] else {
            return 0
        }

        let ackGroupDeliveryReceipts = deliveryReceipts.filter { $0.deliveryReceiptType() == type }
        return ackGroupDeliveryReceipts.count
    }
    
    public func isMyReaction(_ type: GroupDeliveryReceipt.DeliveryReceiptType) -> Bool {
        if let myReaction = reaction(for: MyIdentityStore.shared().identity) {
            return myReaction.deliveryReceiptType() == type
        }
        return false
    }
    
    public func reaction(for identity: String) -> GroupDeliveryReceipt? {
        if let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt] {
            return deliveryReceipts.first(where: { $0.identity == identity })
        }
        return nil
    }
    
    public func groupReactions(for type: GroupDeliveryReceipt.DeliveryReceiptType) -> [GroupDeliveryReceipt] {
        guard let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt] else {
            return []
        }

        return deliveryReceipts.filter { $0.deliveryReceiptType() == type }
    }
    
    public func groupReactionsDictForWeb() -> [AnyHashable: [String]] {
        [
            "ack": groupReactionsIdentityList(for: .acknowledged),
            "dec": groupReactionsIdentityList(for: .declined),
        ]
    }
    
    private func groupReactionsIdentityList(for type: GroupDeliveryReceipt.DeliveryReceiptType) -> [String] {
        var deliveryIdentityList = [String]()
        for delvieryReceipt in groupReactions(for: type) {
            deliveryIdentityList.append(delvieryReceipt.identity)
        }
        return deliveryIdentityList
    }
}
