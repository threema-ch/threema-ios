import Foundation

public enum SwiftUtils {
    
    /// Use this class for new utils. Rewrite old Objective C utils if needed
    
    /// Returns a pseudorandom string
    /// - Parameter length: the length of the returned String
    /// - Returns: A pseudorandom string of the given length
    public static func pseudoRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    /// Returns a pseudorandom string, letters only in upper case.
    /// - Parameters:
    ///    - length: The length of the returned String
    ///    - exclude: Exclude characters for calculation
    /// - Returns: A pseudorandom string of the given length
    public static func pseudoRandomStringUpperCaseOnly(length: Int, exclude: [Character]?) -> String {
        var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        if let exclude {
            letters.removeAll { character in
                exclude.contains(character)
            }
        }

        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
