import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum EncryptedFieldError: Error, CustomStringConvertible {
    case onlyApplicableToVariable

    var description: String {
        switch self {
        case .onlyApplicableToVariable: "@EncryptedField(name: String?) can only be applied to a variable"
        }
    }
}

/// Implementation of the `EncryptedField` macro
public struct EncryptedFieldMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let variable = declaration.as(VariableDeclSyntax.self),
              let identifier = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              !identifier.text.isEmpty else {
            throw EncryptedFieldError.onlyApplicableToVariable
        }

        // Get field encryption name from argument `name:` or from the variable (property) identifier
        let encryptedFieldName =
            if let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            let lable = arguments.first?.as(LabeledExprSyntax.self)?.label,
            lable.text == "name",
            let expression = arguments.first?.as(LabeledExprSyntax.self)?.expression,
            let segments = expression.as(StringLiteralExprSyntax.self)?.segments,
            segments.count == 1,
            case let .stringSegment(argumentSuffix)? = segments.first {
                argumentSuffix.description
            }
            else {
                identifier.text
            }

        let identifierPlaceholder =
            if identifier.text.count > 1 {
                identifier.text.prefix(1).uppercased() + identifier.text.dropFirst()
            }
            else {
                identifier.text.prefix(1).uppercased()
            }

        let variableName = "\(identifier.text)Name"
        let variableEncryptedName = "encrypted\(identifierPlaceholder)Name"

        return [
            """
            private static let \(raw: variableName) = "\(raw: encryptedFieldName)"
            """,
            """
            private static let \(raw: variableEncryptedName) = "\(raw: encryptedFieldName)Encrypted"
            """,
            """
            @objc static func keyPathsForValuesAffecting\(raw: identifierPlaceholder)() -> Set<NSObject> {
                return [NSString(string: Self.\(raw: variableEncryptedName))]
            }
            """,
        ]
    }
}
