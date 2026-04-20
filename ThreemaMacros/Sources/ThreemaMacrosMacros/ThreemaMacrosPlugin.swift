import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ThreemaMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LocalizationMacro.self,
        EncryptedFieldMacro.self,
    ]
}
