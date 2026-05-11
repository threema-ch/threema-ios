import Testing

@testable import ThreemaFramework

struct PhoneNumberNormalizerTests {
    private let sut = PhoneNumberNormalizer()

    @Test func e164() {
        #expect(sut.e164Format(from: "+41212345678", defaultRegion: "CH") == "41212345678")
        #expect(sut.e164Format(from: "+41212345678", defaultRegion: "XX") == "41212345678")
        #expect(sut.e164Format(from: "+41212345678", defaultRegion: "123") == "41212345678")

        #expect(sut.e164Format(from: "+4930123456", defaultRegion: "DE") == "4930123456")

        #expect(sut.e164Format(from: "", defaultRegion: "CH") == nil)
        #expect(sut.e164Format(from: "+", defaultRegion: "CH") == nil)
        #expect(sut.e164Format(from: "+1", defaultRegion: "CH") == nil)
        #expect(sut.e164Format(from: "+411", defaultRegion: "CH") == nil)
        #expect(sut.e164Format(from: "invalid_number", defaultRegion: "CH") == nil)
    }

    @Test func prettyFormat() {
        #expect(sut.prettyFormat(from: "+41212345678", defaultRegion: "CH") == "+41 21 234 56 78")
        #expect(sut.prettyFormat(from: "+41212345678", defaultRegion: "XX") == "+41 21 234 56 78")
        #expect(sut.prettyFormat(from: "+41212345678", defaultRegion: "123") == "+41 21 234 56 78")

        #expect(sut.prettyFormat(from: "+4930123456", defaultRegion: "DE") == "+49 30 123456")

        #expect(sut.prettyFormat(from: "", defaultRegion: "CH") == nil)
        #expect(sut.prettyFormat(from: "+", defaultRegion: "CH") == nil)
        #expect(sut.prettyFormat(from: "+1", defaultRegion: "CH") == nil)
        #expect(sut.prettyFormat(from: "+411", defaultRegion: "CH") == nil)
        #expect(sut.prettyFormat(from: "invalid_number", defaultRegion: "CH") == nil)
    }

    @Test func examplePhoneNumber() {
        #expect(sut.examplePhoneNumber(for: "CH") == "021 234 56 78")
        #expect(sut.examplePhoneNumber(for: "DE") == "030 123456")
        #expect(sut.examplePhoneNumber(for: "AT") == "01 234567890")
        #expect(sut.examplePhoneNumber(for: "FR") == "01 23 45 67 89")
        #expect(sut.examplePhoneNumber(for: "GB") == "0121 234 5678")

        #expect(sut.examplePhoneNumber(for: "") == nil)
        #expect(sut.examplePhoneNumber(for: "invalid_number") == nil)
    }

    @Test func exampleRegionalPhoneNumber() {
        #expect(sut.exampleRegionalPhoneNumber(for: "CH") == "21 234 56 78")
        #expect(sut.exampleRegionalPhoneNumber(for: "DE") == "30 123456")
        #expect(sut.exampleRegionalPhoneNumber(for: "AT") == "1 234567890")
        #expect(sut.exampleRegionalPhoneNumber(for: "FR") == "1 23 45 67 89")
        #expect(sut.exampleRegionalPhoneNumber(for: "GB") == "121 234 5678")

        #expect(sut.exampleRegionalPhoneNumber(for: "") == nil)
        #expect(sut.exampleRegionalPhoneNumber(for: "invalid_number") == nil)
    }

    @Test func regionalPartFromNumber() {
        #expect(sut.regionalPart(from: "+41212345678") == "212345678")
        #expect(sut.regionalPart(from: "+4930123456") == "30123456")

        #expect(sut.regionalPart(from: "41212345678") == nil)
        #expect(sut.regionalPart(from: "4930123456") == nil)

        #expect(sut.regionalPart(from: "") == nil)
        #expect(sut.regionalPart(from: "+") == nil)
        #expect(sut.regionalPart(from: "212345678") == nil)
        #expect(sut.regionalPart(from: "30123456") == nil)
        #expect(sut.regionalPart(from: "invalid_number") == nil)
    }

    @Test func regionFromNumber() {
        #expect(sut.region(from: "+41212345678") == "CH")
        #expect(sut.region(from: "+4930123456") == "DE")

        #expect(sut.region(from: "41212345678") == nil)
        #expect(sut.region(from: "4930123456") == nil)

        #expect(sut.region(from: "") == nil)
        #expect(sut.region(from: "+") == nil)
        #expect(sut.region(from: "invalid_number") == nil)
    }
}
