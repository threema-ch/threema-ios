//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct ThreemaMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LocalizationMacro.self,
    ]
}

/// Implementation of the `localize` macro, which takes a key
/// of type `String` and tries to look up a localized string for the current language set. If no matching string is
/// found it tries falls back to English. If that does no succeed to, then it returns the key itself.
///
///     #localize("key")
///
///  will expand to
///
///     "String(localized: \(argument), defaultValue: BundleUtil.localizedString(for: \(argument)))"
public struct LocalizationMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }
        
        return "String(localized: \(argument), defaultValue: BundleUtil.getFallBackString(for: \(argument)))"
    }
}
