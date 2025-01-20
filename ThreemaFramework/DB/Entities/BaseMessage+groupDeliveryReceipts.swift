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

extension BaseMessage {

    public func add(groupDeliveryReceipt: GroupDeliveryReceipt) {
       
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
    
    public func remove(groupDeliveryReceipt: GroupDeliveryReceipt) {
       
        guard let deliveryReceipts = groupDeliveryReceipts as? [GroupDeliveryReceipt],
              let index = deliveryReceipts.firstIndex(where: { $0.identity == groupDeliveryReceipt.identity }) else {
            return
        }

        groupDeliveryReceipts.remove(at: index)
    }
}
