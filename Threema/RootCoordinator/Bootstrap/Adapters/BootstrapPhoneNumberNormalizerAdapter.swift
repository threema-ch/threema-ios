import Foundation
import ThreemaFramework

// MARK: - BootstrapPhoneNumberNormalizerProtocol

@MainActor
protocol BootstrapPhoneNumberNormalizerProtocol: AnyObject {
    /// Normalizes a phone number to E.164 format using the user's default region.
    /// - Parameter phoneNumber: The phone number to normalize
    /// - Returns: The normalized phone number in E.164 format, or nil if normalization fails
    func normalize(_ phoneNumber: String) -> String?
}

// MARK: - BootstrapPhoneNumberNormalizerAdapter

@MainActor
final class BootstrapPhoneNumberNormalizerAdapter: BootstrapPhoneNumberNormalizerProtocol {
    
    private var normalizer: PhoneNumberNormalizer? {
        PhoneNumberNormalizer.sharedInstance()
    }
    
    func normalize(_ phoneNumber: String) -> String? {
        var prettyFormat: NSString?
        return normalizer?.phoneNumber(
            toE164: phoneNumber,
            withDefaultRegion: PhoneNumberNormalizer.userRegion(),
            prettyFormat: &prettyFormat
        )
    }
}
