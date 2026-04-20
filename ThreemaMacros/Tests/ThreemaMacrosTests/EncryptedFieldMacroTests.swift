import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ThreemaMacrosMacros)
    import ThreemaMacrosMacros
#endif

final class EncryptedFieldMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(ThreemaMacrosMacros)
            assertMacroExpansion(
                """
                @EncryptedField
                @objc public dynamic var text: String
                """,
                expandedSource: """
                    @objc public dynamic var text: String

                    private static let textName = "text"

                    private static let encryptedTextName = "textEncrypted"

                    @objc static func keyPathsForValuesAffectingText() -> Set<NSObject> {
                        return [NSString(string: Self.encryptedTextName)]
                    }
                    """,
                macros: ["EncryptedField": EncryptedFieldMacro.self]
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroDeclarationWithOneChar() throws {
        #if canImport(ThreemaMacrosMacros)
            assertMacroExpansion(
                """
                @EncryptedField
                @objc public dynamic var t: String
                """,
                expandedSource: """
                    @objc public dynamic var t: String

                    private static let tName = "t"

                    private static let encryptedTName = "tEncrypted"

                    @objc static func keyPathsForValuesAffectingT() -> Set<NSObject> {
                        return [NSString(string: Self.encryptedTName)]
                    }
                    """,
                macros: ["EncryptedField": EncryptedFieldMacro.self]
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithArgument() throws {
        #if canImport(ThreemaMacrosMacros)
            assertMacroExpansion(
                """
                @EncryptedField(name: "bla")
                @objc public dynamic var text: String
                """,
                expandedSource: """
                    @objc public dynamic var text: String

                    private static let textName = "bla"

                    private static let encryptedTextName = "blaEncrypted"

                    @objc static func keyPathsForValuesAffectingText() -> Set<NSObject> {
                        return [NSString(string: Self.encryptedTextName)]
                    }
                    """,
                macros: ["EncryptedField": EncryptedFieldMacro.self]
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroOnFunc() throws {
        #if canImport(ThreemaMacrosMacros)
            assertMacroExpansion(
                """
                @EncryptedField
                @objc public func text(_ value: String) {
                }
                """,
                expandedSource: """
                    @objc public func text(_ value: String) {
                    }
                    """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@EncryptedField(name: String?) can only be applied to a variable",
                        line: 1,
                        column: 1
                    ),
                ],
                macros: ["EncryptedField": EncryptedFieldMacro.self]
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
