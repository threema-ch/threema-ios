import Foundation

extension SystemMessageEntity {
    var isAllowedAsLastMessage: Bool {
        !SystemMessageEntity.SystemMessageEntityType.excludeTypesAsLastMessage.contains(type.intValue)
    }

    public static func isTypeAllowedAsLastMessage(_ type: SystemMessageEntityType) -> Bool {
        !SystemMessageEntity.SystemMessageEntityType.excludeTypesAsLastMessage.contains(type.rawValue)
    }
}
