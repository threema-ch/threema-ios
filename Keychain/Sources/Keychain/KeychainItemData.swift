import Foundation

struct KeychainItemData: Equatable {
    let accessibility: CFString?
    let label: String?
    let account: String?
    let password: Data?
    let generic: Data?
    let service: String?
    
    init(
        accessibility: CFString?,
        label: String?,
        account: String?,
        password: Data?,
        generic: Data?,
        service: String?
    ) {
        self.accessibility = accessibility
        self.label = label
        self.account = account
        self.password = password
        self.generic = generic
        self.service = service
    }
    
    static func == (
        lhs: KeychainItemData,
        rhs: KeychainItemData
    ) -> Bool {
        lhs.accessibility == rhs.accessibility &&
            lhs.label == rhs.label &&
            lhs.account == rhs.account &&
            lhs.password == rhs.password &&
            lhs.generic == rhs.generic &&
            lhs.service == rhs.service
    }
}
