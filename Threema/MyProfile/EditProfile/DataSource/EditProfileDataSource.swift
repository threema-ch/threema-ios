// MARK: - Section types

enum EditProfileSection: Int, Hashable {
    case editName
    case editPictureReceivers
    
    enum Row: Hashable {
        case nameField
        case releasePicture(kind: SendProfilePicture)
    }
}
