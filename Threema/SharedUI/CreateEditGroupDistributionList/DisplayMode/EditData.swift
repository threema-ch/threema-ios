struct EditData {
    let name: String?
    let profilePicture: Data?
    let contacts: [Contact]
}

// MARK: - Helpers

extension EditData {
    init(contacts: [Contact]) {
        self.name = nil
        self.profilePicture = nil
        self.contacts = contacts
    }
    
    static var empty: EditData {
        .init(name: nil, profilePicture: nil, contacts: [])
    }
}
