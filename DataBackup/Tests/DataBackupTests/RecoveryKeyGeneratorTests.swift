import DataBackup
import Testing

@Suite("Recovery Key Generator Tests")
struct RecoveryKeyGeneratorTests {

    @Test func `Generates a key of the default length`() throws {
        let sut = makeSUT()

        #expect(try sut.generate().count == RecoveryKeyGenerator.defaultLength)
    }

    @Test(arguments: [1, 16, 64, 200])
    func `Generates a key of the requested length`(length: Int) throws {
        let sut = makeSUT(length: length)

        #expect(try sut.generate().count == length)
    }

    @Test func `Generates an empty key when the length is zero`() throws {
        let sut = makeSUT(length: 0)

        #expect(try sut.generate().isEmpty)
    }

    @Test func `Uses only characters from the default alphabet`() throws {
        let allowed = Set(RecoveryKeyGenerator.defaultLetters + RecoveryKeyGenerator.defaultDigits)
        let sut = makeSUT()

        for _ in 0..<100 {
            let key = try sut.generate()

            #expect(key.allSatisfy { allowed.contains($0) })
        }
    }

    @Test func `Excludes the confusable glyphs I, L, O, and 0`() throws {
        let confusables: Set<Character> = ["I", "L", "O", "0"]
        let sut = makeSUT()

        for _ in 0..<100 {
            let key = try sut.generate()

            #expect(key.allSatisfy { !confusables.contains($0) })
        }
    }

    @Test(arguments: [
        (letters: "AB", digits: "12"),
        (letters: "XYZ", digits: "789"),
        (letters: "A", digits: "1"),
    ])
    func `Restricts output to the custom letters and digits`(letters: String, digits: String) throws {
        let sut = makeSUT(letters: letters, digits: digits, length: 256)

        #expect(try Set(sut.generate()).isSubset(of: Set(letters + digits)))
    }

    @Test func `Keeps letters and digits in similar proportion`() throws {
        // The category is chosen by an unbiased per-character coin, so over a large sample the
        // letter/digit split is ≈50/50. A generous tolerance keeps this non-flaky.
        let sut = makeSUT(length: 10000)
        let digits = Set(RecoveryKeyGenerator.defaultDigits)

        let key = try sut.generate()
        let digitFraction = Double(key.filter { digits.contains($0) }.count) / Double(key.count)

        #expect((0.4...0.6).contains(digitFraction))
    }

    @Test func `Produces different keys across calls`() throws {
        let sut = makeSUT()

        // With 64 characters, a collision is astronomically unlikely.
        #expect(try sut.generate() != sut.generate())
    }

    // MARK: - Private methods

    private func makeSUT(
        letters: String = RecoveryKeyGenerator.defaultLetters,
        digits: String = RecoveryKeyGenerator.defaultDigits,
        length: Int = RecoveryKeyGenerator.defaultLength
    ) -> RecoveryKeyGenerator {
        RecoveryKeyGenerator(letters: letters, digits: digits, length: length)
    }
}
