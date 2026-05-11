import libPhoneNumber
import ObjectiveC

@objcMembers public final class MetadataHelper: NSObject {
    lazy var countriesDictionary = NBMetadataHelper().countryCodeToCountryNumberDictionary() ?? [:]
}
