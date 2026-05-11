import Foundation
import libPhoneNumber
import ObjectiveC

@objcMembers public final class PhoneNumberNormalizer: NSObject, PhoneNumberNormalizerProtocol {

    // MARK: - Private properties

    private let phoneNumberUtil: NBPhoneNumberUtil

    // MARK: - Lifecycle

    override public init() {
        self.phoneNumberUtil = NBPhoneNumberUtil.sharedInstance()
        super.init()
    }

    // MARK: - Public methods

    public func e164Format(from phoneNumber: String, defaultRegion: String) -> String? {
        guard
            let parsed = try? phoneNumberUtil.parse(phoneNumber, defaultRegion: defaultRegion),
            let formatted = try? phoneNumberUtil.format(parsed, numberFormat: .E164)
        else {
            return nil
        }

        return formatted.trimmingCharacters(in: CharacterSet(charactersIn: "+"))
    }

    public func prettyFormat(from phoneNumber: String, defaultRegion: String) -> String? {
        guard
            let parsed = try? phoneNumberUtil.parse(phoneNumber, defaultRegion: defaultRegion)
        else {
            return nil
        }

        return try? phoneNumberUtil.format(parsed, numberFormat: .INTERNATIONAL)
    }

    public func examplePhoneNumber(for region: String) -> String? {
        guard
            let exampleNumber = try? phoneNumberUtil.getExampleNumber(region)
        else {
            return nil
        }

        return try? phoneNumberUtil.format(exampleNumber, numberFormat: .NATIONAL)
    }

    public func exampleRegionalPhoneNumber(for region: String) -> String? {
        guard
            let exampleNumber = try? phoneNumberUtil.getExampleNumber(region),
            let number = try? phoneNumberUtil.format(exampleNumber, numberFormat: .INTERNATIONAL)
        else {
            return nil
        }

        return regionalPart(from: number)
    }

    public func regionalPart(from phoneNumber: String) -> String? {
        guard
            let metadataHelper = NBMetadataHelper(),
            let region = region(from: phoneNumber)
        else {
            return nil
        }

        if
            let code = metadataHelper.countryCodeToCountryNumberDictionary()[region] as? String,
            let codeRange = phoneNumber.range(of: code) {
            return String(phoneNumber[codeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    public func userRegion() -> String {
        Locale.current.region?.identifier ?? ""
    }

    public func region(from phoneNumber: String) -> String? {
        guard let parsed = try? phoneNumberUtil.parse(phoneNumber, defaultRegion: nil) else {
            return nil
        }
        return phoneNumberUtil.getRegionCode(for: parsed)
    }
}
