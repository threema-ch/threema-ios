import Foundation

extension BaseMessageEntity {

    public func add(groupDeliveryReceipt: GroupDeliveryReceipt) {
       
        // Do not save acks/decs for deleted messages
        if groupDeliveryReceipt.deliveryReceiptType() == .acknowledged || groupDeliveryReceipt
            .deliveryReceiptType() == .declined, deletedAt != nil {
            return
        }
            
        if groupDeliveryReceipts == nil {
            groupDeliveryReceipts = [GroupDeliveryReceipt]()
        }
        
        if let deliveryReceipts = groupDeliveryReceipts,
           let index = deliveryReceipts.firstIndex(where: { $0.identity == groupDeliveryReceipt.identity }) {
            groupDeliveryReceipts!.remove(at: index)
            groupDeliveryReceipts!.insert(groupDeliveryReceipt, at: index)
            groupDeliveryReceipts!.append(groupDeliveryReceipt)
        }
    }
    
    public func remove(groupDeliveryReceipt: GroupDeliveryReceipt) {
        
        guard let deliveryReceipts = groupDeliveryReceipts,
              let index = deliveryReceipts.firstIndex(where: { $0.identity == groupDeliveryReceipt.identity }) else {
            return
        }
        
        groupDeliveryReceipts!.remove(at: index)
    }
}
