import Foundation

/// Holds all Call ID's and its corresponding CallKit UUID.
final class CallIDService {
    private var callKitUUIDs: [UInt32: UUID] = [:]
    private let callKitUUIDsQueue = DispatchQueue(label: "ch.threema.VoIPCallKitManager.callKitUUIDsQueue")

    func uuid(for callID: VoIPCallID) -> (callUUID: UUID, isNew: Bool) {
        callKitUUIDsQueue.sync {
            var isNew = false
            if !callKitUUIDs.keys.contains(callID.callID) {
                let callUUID = UUID()
                callKitUUIDs[callID.callID] = callUUID
                isNew = true

                DDLogNotice("VoIPCallService [cid=\(callID.callID)] -> callUUID=\(callUUID)")
            }
            return (callKitUUIDs[callID.callID]!, isNew)
        }
    }

    func callID(for callUUID: UUID) -> VoIPCallID? {
        callKitUUIDsQueue.sync {
            callKitUUIDs.first { item in
                item.value == callUUID
            }
            .map { item in
                VoIPCallID(callID: item.key)
            }
        }
    }
}
