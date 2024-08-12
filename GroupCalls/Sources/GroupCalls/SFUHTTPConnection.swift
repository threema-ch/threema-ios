//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import Foundation
import ThreemaProtocols
import WebRTC

struct SFUHTTPConnection {
    let dependencies: Dependencies
    let groupCallDescription: GroupCallBaseState
}

extension SFUHTTPConnection {
    enum PeekResponse {
        case notRunning
        case notDetermined
        case needsTokenRefresh
        case invalidRequest
        case running(Groupcall_SfuHttpResponse.Peek)
    }
    
    enum JoinResponse {
        case running(Groupcall_SfuHttpResponse.Join)
        case notDetermined
        case full
        case notRunning
        case timeout
    }
}

extension SFUHTTPConnection {
    func peek() async throws -> PeekResponse {
        guard let (data, status) = try await send(.peek) else {
            return .notDetermined
        }
        
        guard let httpStatus = status as? HTTPURLResponse else {
            return .notRunning
        }
        
        guard httpStatus.statusCode == 200 || httpStatus.statusCode == 400 || httpStatus.statusCode == 401 else {
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] Peek for group call \(groupCallDescription.callID) returned \(httpStatus.statusCode) instead of 200, 400 or 401. Removing call"
            )
            return .notRunning
        }
        
        if httpStatus.statusCode == 401 {
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] Our credentials have expired. Try again in some time."
            )
            return .needsTokenRefresh
        }
        
        if httpStatus.statusCode == 400 {
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] Peek for group call \(groupCallDescription.callID) failed with 400, because the provided data invalid or call ids don't match"
            )
            return .invalidRequest
        }
        
        guard let peekResponse = try? Groupcall_SfuHttpResponse.Peek(serializedData: data) else {
            return .notDetermined
        }
        
        return .running(peekResponse)
    }
    
    func join(with certificate: RTCCertificate) async throws -> JoinResponse {
        
        let task = Task {
            try await send(.join(certificate))
        }
        
        let intermediateResult = try await Task.timeout(task, 10)
        
        switch intermediateResult {
        case let .error(error):
            if let error {
                throw error
            }
            else {
                DDLogError("[GroupCall] [Join Steps] An unknown error occurred")
                return .notDetermined
            }
            
        case .timeout:
            DDLogError("[GroupCall] [Join Steps] Join timed out")
            return .timeout
            
        case let .result(result):
            
            guard let (data, status) = result else {
                DDLogError("[GroupCall] [Join Steps] Undetermined result")
                return .notDetermined
            }
            
            guard let httpStatus = status as? HTTPURLResponse else {
                DDLogError("[GroupCall] [Join Steps] Group call not running")
                return .notRunning
            }
            
            /// **Protocol Step: Group Call Join Steps**
            /// 3. If the received status code is `503`, notify the user that the group call
            ///   is full and abort these steps.
            if httpStatus.statusCode == 503 {
                DDLogWarn("[GroupCall] [Join Steps] Group call is full")
                return .full
            }
            
            if httpStatus.statusCode == 401 {
                DDLogWarn("[GroupCall] [Join Steps] Our credentials have expired. Try again in some time.")
                return .notDetermined
            }
            
            /// **Protocol Step: Group Call Join Steps**
            /// 4. If the server could not be reached or the received status code is not
            ///   `200` or if the _Join_ response could not be decoded, abort these steps
            ///   and notify the user.
            guard httpStatus.statusCode == 200 else {
                DDLogWarn(
                    "[GroupCall] [Join Steps] Peek for group call \(groupCallDescription.callID) returned \(httpStatus.statusCode) instead of 200. Removing call"
                )
                return .notRunning
            }
            
            guard let joinResponse = try? Groupcall_SfuHttpResponse.Join(serializedData: data) else {
                DDLogError("[GroupCall] [Join Steps] Could not create join from received data")
                return .notDetermined
            }
            
            return .running(joinResponse)
        }
    }
}

extension SFUHTTPConnection {
    fileprivate enum SFUHTTPRequest {
        case join(RTCCertificate)
        case peek
        
        var param: String {
            switch self {
            case .peek:
                "peek"
            case .join:
                "join"
            }
        }
    }
    
    private func send(_ requestType: SFUHTTPRequest) async throws -> (Data, URLResponse)? {
        
        /// **Protocol Step: SfuHttpRequest (Sending 1. - 3.)**
        /// 1. Use `POST` as method.
        /// 2. Set the `Authorization` header to `ThreemaSfuToken <sfu-token>`.
        /// 3. Set the encoded `SfuHttpRequest.Peek`/`SfuHttpRequest.Join` message as body.
        
        let param: String = requestType.param
        let requestBody: Data =
            switch requestType {
            case .peek:
                try create(.peek)
            case let .join(certificate):
                try create(.join(certificate))
            }
        
        guard let authorizationToken = try? await dependencies.httpHelper.sfuCredentials() else {
            throw GroupCallError.invalidToken
        }
        
        guard !Task.isCancelled else {
            return nil
        }
        
        let groupCallURL = groupCallDescription.sfuBaseURL
            .appendingPathComponent("v1")
            .appendingPathComponent(param)
            .appendingPathComponent(groupCallDescription.callID.bytes.hexEncodedString())
        
        DDLogNotice("[GroupCall] Checking at URL \(groupCallURL)")

        return try await dependencies.groupCallsHTTPClientAdapter.sendPeek(
            authorization: "ThreemaSfuToken \(authorizationToken.sfuToken)",
            url: groupCallURL,
            body: requestBody
        )
    }
}

extension SFUHTTPConnection {
    private func create(_ request: SFUHTTPRequest) throws -> Data {
        switch request {
        case .peek:
            guard let data = try createPeekRequest() else {
                throw GroupCallError.serializationFailure
            }
            return data
        case let .join(certificate):
            guard let fingerprint = certificate.groupCallFingerprint else {
                throw GroupCallError.serializationFailure
            }
            guard let data = try createJoinRequest(fingerprint: fingerprint) else {
                throw GroupCallError.serializationFailure
            }
            return data
        }
    }
    
    private func createPeekRequest() throws -> Data? {
        var body = Groupcall_SfuHttpRequest.Peek()
        body.callID = groupCallDescription.callID.bytes
        
        return try? body.ownSerializedData()
    }
    
    private func createJoinRequest(fingerprint: Data) throws -> Data? {
        var body = Groupcall_SfuHttpRequest.Join()
        body.callID = groupCallDescription.callID.bytes
        body.protocolVersion = groupCallDescription.protocolVersion
        body.dtlsFingerprint = fingerprint
        
        return try? body.ownSerializedData()
    }
}
