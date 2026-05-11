@testable import ThreemaFramework

struct PhoneNumberNormalizerMock: PhoneNumberNormalizerProtocol {
    var e164FormatResponse: String?
    var prettyFormatResponse: String?
    var examplePhoneNumberResponse: String?
    var exampleRegionalPhoneNumberResponse: String?
    var regionalPartResponse: String?
    var userRegionResponse = "CH"
    var regionFromPhoneNumberResponse: String?

    func e164Format(from phoneNumber: String, defaultRegion: String) -> String? { e164FormatResponse }

    func prettyFormat(from phoneNumber: String, defaultRegion: String) -> String? { prettyFormatResponse }

    func examplePhoneNumber(for region: String) -> String? { examplePhoneNumberResponse }

    func exampleRegionalPhoneNumber(for region: String) -> String? { exampleRegionalPhoneNumberResponse }

    func regionalPart(from phoneNumber: String) -> String? { regionalPartResponse }

    func userRegion() -> String { userRegionResponse }

    func region(from phoneNumber: String) -> String? { regionFromPhoneNumberResponse }
}
