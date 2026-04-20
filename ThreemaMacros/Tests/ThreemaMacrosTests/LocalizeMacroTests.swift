import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ThreemaMacrosMacros)
    import ThreemaMacrosMacros
#endif

final class LocalizeMacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(ThreemaMacrosMacros)
            assertMacroExpansion(
                """
                #localize("key")
                """,
                expandedSource: """
                    String(localized: "key", defaultValue: BundleUtil.getFallBackString(for: "key"))
                    """,
                macros: ["localize": LocalizationMacro.self]
            )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
