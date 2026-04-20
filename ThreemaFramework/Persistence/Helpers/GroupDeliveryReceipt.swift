import Foundation

@objc public final class GroupDeliveryReceipt: NSObject, NSSecureCoding, Codable {
    public static var supportsSecureCoding = true
    
    /// Do not change the string of the key because it is used in core data on the message object as transformable
    enum CodingKeys: String, CodingKey {
        case identity
        case date
        case deliveryReceiptTypeValue
    }
    
    @objc public enum DeliveryReceiptType: Int {
        case unknown = 0
        case received = 1
        case read = 2
        case acknowledged = 3 // Unused, do not remove to not mess up values in core data
        case declined = 4 // Same as above
        case consumed = 5
    }
    
    @objc public var identity: String
    @objc public var date: Date
    fileprivate var deliveryReceiptTypeValue: Int
        
    @objc public init(identity: String, deliveryReceiptType: DeliveryReceiptType, date: Date) {
        self.identity = identity
        self.deliveryReceiptTypeValue = deliveryReceiptType.rawValue
        self.date = date
    }
    
    @objc public func deliveryReceiptType() -> DeliveryReceiptType {
        guard let type = DeliveryReceiptType(rawValue: deliveryReceiptTypeValue) else {
            return .unknown
        }
        return type
    }
    
    // MARK: NSSecureCoding

    public required init?(coder: NSCoder) {
        guard let identity = coder.decodeObject(of: NSString.self, forKey: CodingKeys.identity.rawValue),
              let date = coder.decodeObject(of: NSDate.self, forKey: CodingKeys.date.rawValue) else {
            return nil
        }
        
        self.identity = String(identity)
        self.deliveryReceiptTypeValue = coder.decodeInteger(forKey: CodingKeys.deliveryReceiptTypeValue.rawValue)
        self.date = date as Date
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(identity, forKey: CodingKeys.identity.rawValue)
        aCoder.encode(deliveryReceiptTypeValue, forKey: CodingKeys.deliveryReceiptTypeValue.rawValue)
        aCoder.encode(date, forKey: CodingKeys.date.rawValue)
    }
}

@objc(GroupDeliveryReceiptValueTransformer)
final class GroupDeliveryReceiptValueTransformer: NSSecureUnarchiveFromDataTransformer {

    static let name = NSValueTransformerName(rawValue: String(describing: GroupDeliveryReceiptValueTransformer.self))

    override static var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, GroupDeliveryReceipt.self]
    }

    @objc public static func register() {
        let transformer = GroupDeliveryReceiptValueTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}
