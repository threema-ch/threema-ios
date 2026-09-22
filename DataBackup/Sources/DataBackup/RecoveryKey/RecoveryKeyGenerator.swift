import Foundation
import Security

/// Generates cryptographically secure recovery keys using the system CSPRNG (`SecRandomCopyBytes`).
///
/// Each character is drawn in two independent steps: an unbiased coin selects whether the character
/// is a letter or a digit, then a symbol is sampled uniformly from that sub-alphabet. Selecting the
/// category independently of the symbol keeps letters and digits in similar proportion (≈50/50)
/// regardless of how many symbols each sub-alphabet holds.
///
/// Both steps are free of modulo bias: random bytes that fall in the biased tail of the `0..<256`
/// range are rejected rather than folded, so every symbol within a sub-alphabet is equally likely,
/// and the coin is exact because exactly half of the 256 byte values are even.
public struct RecoveryKeyGenerator: RecoveryKeyGeneratorProtocol {

    // MARK: - Public properties

    /// The default letters: the uppercase ASCII letters excluding the confusable glyphs
    /// `I`, `L`, and `O`.
    public static let defaultLetters = "ABCDEFGHJKMNPQRSTUVWXYZ"

    /// The default digits: the decimal digits excluding the confusable glyph `0`.
    public static let defaultDigits = "123456789"

    /// The default number of characters in a generated key.
    public static let defaultLength = 64

    // MARK: - Private properties

    private let letters: [Character]
    private let digits: [Character]
    private let length: Int

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - letters: The letters to draw from. Must be non-empty and contain at most 256 symbols.
    ///   - digits: The digits to draw from. Must be non-empty and contain at most 256 symbols.
    ///   - length: The number of characters to generate. Must not be negative.
    public init(
        letters: String = RecoveryKeyGenerator.defaultLetters,
        digits: String = RecoveryKeyGenerator.defaultDigits,
        length: Int = RecoveryKeyGenerator.defaultLength
    ) {
        let letters = Array(letters)
        let digits = Array(digits)

        precondition(!letters.isEmpty, "The letters must not be empty.")
        precondition(!digits.isEmpty, "The digits must not be empty.")
        precondition(letters.count <= 256, "The letters must contain at most 256 characters.")
        precondition(digits.count <= 256, "The digits must contain at most 256 characters.")
        precondition(length >= 0, "The length must not be negative.")

        self.letters = letters
        self.digits = digits
        self.length = length
    }

    // MARK: - Public methods

    public func generate() throws -> String {
        guard length > 0 else {
            return ""
        }

        var randomness = SecureRandomByteStream()

        var characters = [Character]()
        characters.reserveCapacity(length)

        for _ in 0..<length {
            // Unbiased coin: exactly half of the 256 byte values are even, so the parity selects
            // letters vs. digits with equal probability. Drawing the category independently of the
            // in-category symbol keeps the letter/digit split balanced (≈50/50).
            let subAlphabet = try randomness.nextByte().isMultiple(of: 2) ? letters : digits
            try characters.append(sample(from: subAlphabet, using: &randomness))
        }

        return String(characters)
    }

    // MARK: - Private methods

    /// Draws one character uniformly at random from `subAlphabet`, rejecting bytes in the biased tail
    /// so every symbol is equally likely (avoids `% count` modulo bias).
    private func sample(from subAlphabet: [Character], using randomness: inout SecureRandomByteStream) throws
        -> Character {
        let count = subAlphabet.count

        // `unbiasedUpperBound` is the largest multiple of `count` that fits in a byte, e.g. 253 for 23.
        let unbiasedUpperBound = 256 - (256 % count)

        // On average only a tiny fraction of bytes are rejected, so this rarely loops.
        while true {
            let byte = try Int(randomness.nextByte())
            if byte < unbiasedUpperBound {
                return subAlphabet[byte % count]
            }
        }
    }
}

/// Streams bytes from the system CSPRNG (`SecRandomCopyBytes`), refilling in batches on demand so
/// callers can draw a variable, rejection-dependent number of bytes without sizing a buffer upfront.
private struct SecureRandomByteStream {
    private static let batchSize = 64

    private var buffer = [UInt8]()
    private var index = 0

    mutating func nextByte() throws -> UInt8 {
        if index == buffer.count {
            try refill()
        }
        defer { index += 1 }
        return buffer[index]
    }

    private mutating func refill() throws {
        buffer = [UInt8](repeating: 0, count: Self.batchSize)

        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        guard status == errSecSuccess else {
            throw RecoveryKeyGeneratorError.secureRandomFailed(status: status)
        }

        index = 0
    }
}
