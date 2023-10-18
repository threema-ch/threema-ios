//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import CocoaLumberjackSwift
import CryptoKit
import Foundation
import ThreemaProtocols
@preconcurrency import WebRTC

@GlobalGroupCallActor
/// Group Call Connection State
/// Sends a http request to the SFU and up receiving it creates the `Connecting` state.
struct Joining: GroupCallState {
    // MARK: - Internal Properties

    let groupCallActor: GroupCallActor
    
    // MARK: - Lifecycle
    
    func next() async throws -> GroupCallState? {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] State is Joining \(groupCallActor.callID.bytes.hexEncodedString())")
        
        guard let certificate = RTCCertificate.generate(withParams: [RTCEncryptionKeyType.ECDSA: 2_592_000]) else {
            throw GroupCallError.serializationFailure
        }
        
        /// **Protocol Step: Group Call Join Steps** 2. Join (or implicitly create) the group call via a
        /// SfuHttpRequest.Join request. If this does not result in a response within 10s,
        ///  abort these steps and notify the user.
        ///  Note: Join Steps 3 & 4 are within the `.join()` below.
        switch try await groupCallActor.sfuHTTPConnection.join(with: certificate) {
        case .notDetermined, .notRunning, .timeout, .full:
            return Ending(groupCallActor: groupCallActor)
            
        case let .running(joinResponse):
            guard !Task.isCancelled else {
                return Ending(groupCallActor: groupCallActor)
            }
            
            // TODO: IOS-4090
            await groupCallActor.setExactCallStartDate(joinResponse.startedAt)
            
            DDLogNotice("[GroupCall] [JoinSteps] Start Connecting")
            
            return try Connecting(groupCallActor: groupCallActor, joinResponse: joinResponse, certificate: certificate)
        }
    }
}
