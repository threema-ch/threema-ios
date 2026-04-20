import Testing
@testable import Threema

struct CallIDServiceTests {

    @Test func testUUIDForCallID() async throws {
        let expectedCallIDOne = VoIPCallID.generate()
        let expectedCallIDTwo = VoIPCallID.generate()

        let callIDService = CallIDService()

        let (uuidOne, isNewOne) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwo, isNewTwo) = callIDService.uuid(for: expectedCallIDTwo)

        let (uuidOneSecond, isNewOneSecond) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwoSecond, isNewTwoSecond) = callIDService.uuid(for: expectedCallIDTwo)

        #expect(isNewOne)
        #expect(!isNewOneSecond)
        #expect(uuidOne == uuidOneSecond)

        #expect(isNewTwo)
        #expect(!isNewTwoSecond)
        #expect(uuidTwo == uuidTwoSecond)

        #expect(uuidOne != uuidTwo)
        #expect(uuidOneSecond != uuidTwoSecond)
    }

    @Test func testCallIDIsNilForUnknownUUID() async throws {
        let callIDService = CallIDService()

        let callID = callIDService.callID(for: UUID())

        #expect(callID == nil)
    }

    @Test func testCallIDForUUID() async throws {
        let expectedCallIDOne = VoIPCallID.generate()
        let expectedCallIDTwo = VoIPCallID.generate()

        let callIDService = CallIDService()

        let (uuidOne, isNewOne) = callIDService.uuid(for: expectedCallIDOne)
        let (uuidTwo, isNewTwo) = callIDService.uuid(for: expectedCallIDTwo)

        #expect(isNewOne)
        #expect(isNewTwo)
        #expect(uuidOne != uuidTwo)

        let callIDOne = callIDService.callID(for: uuidOne)
        let callIDTwo = callIDService.callID(for: uuidTwo)

        #expect(callIDOne?.callID == expectedCallIDOne.callID)
        #expect(callIDTwo?.callID == expectedCallIDTwo.callID)
    }
}
