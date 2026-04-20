/// Takes a key of type `String` and tries to look up a localized string for the current language set. If no matching
/// string is found it tries falls back to English. If that does no succeed to, then it returns the key itself.
///
///     #localize("key")
///
///     will expand to
///
///     String(localized: "key", defaultValue: BundleUtil.localizedString(for: "key"))"
///
/// - Parameter value: The key of the localized text
@freestanding(expression)
public macro localize<T>(_ value: T) -> String = #externalMacro(
    module: "ThreemaMacrosMacros",
    type: "LocalizationMacro"
)

/// Adds for an entity property a static variable for the field name and the encrypted field
/// name and its KVO function to trigger the observers for that property.
///
///     @EncryptedField(name: "bla")
///     @objc public dynamic var text: String
///
///     will expand to
///
///     @objc public dynamic var text: String
///     private static let textName = "bla"
///     private static let encryptedTextName = "blaEncrypted"
///     @objc class func keyPathsForValuesAffectingText() -> Set<NSObject> {
///         return [NSString(string: Self.encryptedTextName)]
///     }
///
/// - Parameter name: The field name, can be used if is different to the property name
@attached(peer, names: arbitrary)
public macro EncryptedField(name: String? = nil) = #externalMacro(
    module: "ThreemaMacrosMacros",
    type: "EncryptedFieldMacro"
)
