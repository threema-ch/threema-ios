import CocoaLumberjackSwift
import Foundation
import Punycode

extension URL {
    /// Checks if the hostname of a given URL consists of a mix of different unicode scripts implying a possible
    /// phishing attempt through similar looking characters.
    /// Additionally, all the characters of the hostname must be valid unicode identifiers per UTS 39.
    /// The script mixing rules apply for each domain label (component) separately.
    /// This is partially inspired by validation rules in Chromium and Firefox
    /// Chromium: https://chromium.googlesource.com/chromium/src/+/main/docs/idn.md
    /// Firefox: https://wiki.mozilla.org/IDN_Display_Algorithm#Algorithm
    public var isIDNASafe: Bool {
        
        guard let host = host?.idnaDecoded else {
            DDLogWarn("Can't generate stripped host for \(absoluteString)")
            return true
        }
        
        let components = host.split(separator: ".")
        
        guard !components.isEmpty, components.allSatisfy({ isLegalComponent(component: String($0)) }) else {
            return false
        }
        
        return true
    }
    
    private func isLegalComponent(component: String) -> Bool {
        
        guard let legalHostnamePattern = try? NSRegularExpression(pattern: "^[\\x00-\\x7F]*$")
        else {
            return false
        }
        
        // Skip further tests if the component consists of ASCII only
        if legalHostnamePattern.numberOfMatches(
            in: component,
            range: NSRange(location: 0, length: component.utf16.count)
        ) > 0 {
            return true
        }
        
        // Check that every character belongs to the allowed identifiers per UTS 39
        let unicodeIdentifierCharacterSet = CharacterSet.letters
            .union(.decimalDigits)
            .union(.punctuationCharacters)
            .union(.nonBaseCharacters)
            .union(.controlCharacters)
            .union(.decomposables)
        
        guard component.unicodeScalars.filter({ !unicodeIdentifierCharacterSet.contains($0) }).isEmpty else {
            return false
        }
        
        // Check that script mixing is only allowed based on the "Highly Restrictive" profile of UTS 39
        let scripts = component.map { Unicode.script(for: $0.unicodeScalars.first!.value) }
            .filter { $0 != Unicode.ThreemaScript.common && $0 != Unicode.ThreemaScript.inherited }
        let uniqueScripts = Set(scripts)
        if uniqueScripts.count >= 2,
           !Unicode.validURLUnicodeScriptSets
           .contains(where: { uniqueScripts.isSubset(of: $0) }) {
            return false
        }
        
        return true
    }
}
