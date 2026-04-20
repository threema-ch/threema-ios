import Foundation

struct Ended: GroupCallState {
    func next() async throws -> GroupCallState? {
        DDLogNotice("[GroupCall] Ended `next()`")
        return nil
    }
}
