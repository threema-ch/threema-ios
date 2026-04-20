import ThreemaMacros

extension SendProfilePicture {
    var localizedText: String {
        switch self {
        case SendProfilePictureNone:
            #localize("send_profileimage_off")
        case SendProfilePictureAll:
            #localize("send_profileimage_on")
        case SendProfilePictureContacts:
            #localize("send_profileimage_contacts")
        default:
            ""
        }
    }
}
