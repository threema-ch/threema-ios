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

@objc public class GroupDeliveryReceipt: NSObject, NSSecureCoding {
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
        case acknowledged = 3
        case declined = 4
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
    
    public func icon() -> UIImage {
        let deliveryReceiptType = DeliveryReceiptType(rawValue: deliveryReceiptTypeValue)
        switch deliveryReceiptType {
        case .acknowledged:
            return UIImage(
                systemName: identity == MyIdentityStore.shared()
                    .identity ? "hand.thumbsup.fill" : "hand.thumbsup"
            )!
                .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
        case .declined:
            return UIImage(
                systemName: identity == MyIdentityStore.shared()
                    .identity ? "hand.thumbsdown.fill" : "hand.thumbsdown"
            )!
                .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
        default:
            return UIImage()
        }
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
