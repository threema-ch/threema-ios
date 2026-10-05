import Foundation
import Testing
@testable import ThreemaFramework

@Suite("RingingCallRecord", .serialized)
final class RingingCallRecordTests {

    private let callID = VoIPCallID(callID: 42)
    private let otherCallID = VoIPCallID(callID: 43)
    private let start = Date(timeIntervalSince1970: 1_000_000)

    init() {
        AppGroup.setGroupID("group.ch.threema")
        RingingCallRecord.clear(callID)
        RingingCallRecord.clear(otherCallID)
    }

    deinit {
        RingingCallRecord.clear(callID)
        RingingCallRecord.clear(otherCallID)
    }

    @Test("Only the recorded call counts as ringing")
    func matchesRecordedCallOnly() {
        RingingCallRecord.setRinging(callID, at: start)

        #expect(RingingCallRecord.isRinging(callID, now: start))
        #expect(!RingingCallRecord.isRinging(otherCallID, now: start))
    }

    @Test("Clearing another call keeps the record")
    func clearIgnoresOtherCall() {
        RingingCallRecord.setRinging(callID, at: start)

        RingingCallRecord.clear(otherCallID)
        #expect(RingingCallRecord.isRinging(callID, now: start))

        RingingCallRecord.clear(callID)
        #expect(!RingingCallRecord.isRinging(callID, now: start))
    }

    @Test("A record older than an incoming call can ring expires by itself")
    func expiresAfterMaximumAge() {
        RingingCallRecord.setRinging(callID, at: start)

        #expect(RingingCallRecord.isRinging(callID, now: start.addingTimeInterval(RingingCallRecord.maximumAge)))
        #expect(!RingingCallRecord.isRinging(callID, now: start.addingTimeInterval(RingingCallRecord.maximumAge + 1)))

        #expect(!RingingCallRecord.isRinging(callID, now: start))
    }
}
