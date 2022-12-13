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

import Foundation

@objc public extension BaseMessage {
        
    func add(groupDeliveryReceipt: GroupDeliveryReceipt) {
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
    
    func reaction(for identity: String) -> GroupDeliveryReceipt? {
        if let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt],
           let index = deliveryReceipts.firstIndex(where: { $0.identity == identity }) {
            return groupDeliveryReceipts[index] as? GroupDeliveryReceipt
        }
        return nil
    }
    
    func reactionForMyIdentity() -> GroupDeliveryReceipt? {
        if let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt],
           let index = deliveryReceipts.firstIndex(where: { $0.identity == MyIdentityStore.shared().identity }) {
            return groupDeliveryReceipts[index] as? GroupDeliveryReceipt
        }
        return nil
    }
    
    func groupReactionsCount(of type: GroupDeliveryReceipt.DeliveryReceiptType) -> Int {
        guard let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt] else {
            return 0
        }

        let ackGroupDeliveryReceipts = deliveryReceipts.filter { $0.deliveryReceiptType() == type }
        return ackGroupDeliveryReceipts.count
    }
    
    func groupReactions(for type: GroupDeliveryReceipt.DeliveryReceiptType) -> [GroupDeliveryReceipt] {
        guard let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt] else {
            return []
        }

        return deliveryReceipts.filter { $0.deliveryReceiptType() == type }
    }
    
    func groupReactionsDictForWeb() -> [AnyHashable: [String]] {
        [
            "ack": groupReactionsIdentityList(for: .userAcknowledgment),
            "dec": groupReactionsIdentityList(for: .userDeclined),
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
