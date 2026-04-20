import Foundation

extension String {
    @available(*, deprecated, message: "Use the macro #localize(key) instead.")
    public var localized: String {
        BundleUtil.localizedString(forKey: self)
    }
}
