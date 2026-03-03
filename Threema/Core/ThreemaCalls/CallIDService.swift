//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
