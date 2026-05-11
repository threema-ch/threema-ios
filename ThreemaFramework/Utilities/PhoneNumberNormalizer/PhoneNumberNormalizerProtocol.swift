public protocol PhoneNumberNormalizerProtocol {
    func e164Format(from phoneNumber: String, defaultRegion: String) -> String?

    func prettyFormat(from phoneNumber: String, defaultRegion: String) -> String?

    func examplePhoneNumber(for region: String) -> String?

    func exampleRegionalPhoneNumber(for region: String) -> String?

    func regionalPart(from phoneNumber: String) -> String?

    func userRegion() -> String

    func region(from phoneNumber: String) -> String?
}
