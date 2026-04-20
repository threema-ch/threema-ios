import Foundation

extension BundleUtil {
    public static func getFallBackString(for key: String) -> String.LocalizationValue {
        String.LocalizationValue(BundleUtil.localizedString(forKey: key))
    }
}
