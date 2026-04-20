import CocoaLumberjackSwift
import CryptoKit
import Foundation
import ThreemaProtocols

/// Group Call State
/// A group call which we believe to exists on the SFU but in which we do not actively participate in it in this state
struct UnJoined: GroupCallState {
    // MARK: - Internal Properties

    let groupCallActor: GroupCallActor
    
    // MARK: - Lifecycle

    func next() async throws -> GroupCallState? {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Unjoined `next()` in \(groupCallActor.callID)")
        return Joining(groupCallActor: groupCallActor)
    }
}
