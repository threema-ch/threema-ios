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
        case timeout
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
    func sendPeek() async throws -> PeekResponse {
        guard let (data, status) = try await send(.Peek) else {
            return .notDetermined
        }
        
        guard let httpStatus = status as? HTTPURLResponse else {
            return .notRunning
        }
        
        guard httpStatus.statusCode == 200 || httpStatus.statusCode == 401 else {
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] Peek for group call \(groupCallDescription.callID.bytes.hexEncodedString()) returned \(httpStatus.statusCode) instead of 200. Remove call"
            )
            return .notRunning
        }
        
        if httpStatus.statusCode == 401 {
            DDLogWarn(
                "[GroupCall] [PeriodicCleanup] Our credentials have expired. Try again in some time."
            )
            return .needsTokenRefresh
        }
        
        guard let peekResponse = try? Groupcall_SfuHttpResponse.Peek(serializedData: data) else {
            return .notDetermined
        }
        
        return .running(peekResponse)
    }
    
    func sendJoin(with certificate: RTCCertificate) async throws -> JoinResponse {
        
        let task = Task {
            try await send(.Join(certificate))
        }
        
        let intermediateResult = try await Task.timeout(task, 10)
        
        switch intermediateResult {
        case let .error(error):
            if let error {
                throw error
            }
            else {
                return .notDetermined
            }
            
        case .timeout:
            return .timeout
            
        case let .result(result):
            
            guard let (data, status) = result else {
                return .notDetermined
            }
            
            guard let httpStatus = status as? HTTPURLResponse else {
                return .notRunning
            }
            
            guard httpStatus.statusCode == 200 || httpStatus.statusCode == 401 || httpStatus.statusCode == 503 else {
                DDLogWarn(
                    "[GroupCall] [Join Steps] Peek for group call \(groupCallDescription.callID.bytes.hexEncodedString()) returned \(httpStatus.statusCode) instead of 200. Remove call"
                )
                return .notRunning
            }
            
            if httpStatus.statusCode == 401 {
                DDLogWarn(
                    "[GroupCall] [Join Steps] Our credentials have expired. Try again in some time."
                )
                return .notDetermined
            }
            else if httpStatus.statusCode == 503 {
                DDLogWarn(
                    "[GroupCall] [Join Steps] Group call is full."
                )
                return .full
            }
            
            guard let peekResponse = try? Groupcall_SfuHttpResponse.Join(serializedData: data) else {
                return .notDetermined
            }
            
            return .running(peekResponse)
        }
    }
}

extension SFUHTTPConnection {
    fileprivate enum SFUHTTPRequest {
        case Join(RTCCertificate)
        case Peek
        
        var param: String {
            switch self {
            case .Peek:
                return "peek"
            case .Join:
                return "join"
            }
        }
    }
    
    private func send(_ requestType: SFUHTTPRequest) async throws -> (Data, URLResponse)? {
        let param: String = requestType.param
        let requestBody: Data
        
        switch requestType {
        case .Peek:
            requestBody = try create(.Peek)
        case let .Join(certificate):
            requestBody = try create(.Join(certificate))
        }
        
        guard let authorizationToken = try? await dependencies.httpHelper.sfuCredentials() else {
            throw FatalStateError.tokenFailure
        }
        
        guard !Task.isCancelled else {
            return nil
        }
        
        guard let groupCallURL =
            URL(
                string: "\(groupCallDescription.sfuBaseURL)/v1/\(param)/\(groupCallDescription.callID.bytes.hexEncodedString())"
            )
        else {
            throw FatalStateError.SerializationFailure
        }
        
        DDLogNotice("[GroupCall] Checking at URL \(groupCallURL)")
        
        return try await dependencies.groupCallsHTTPClientAdapter.sendPeek(
            authorization: "ThreemaSfuToken \(authorizationToken.sfuTOken)",
            url: groupCallURL,
            body: requestBody
        )
    }
}

extension SFUHTTPConnection {
    private func create(_ request: SFUHTTPRequest) throws -> Data {
        switch request {
        case .Peek:
            guard let data = try createPeekRequest() else {
                throw FatalStateError.SerializationFailure
            }
            return data
        case let .Join(certificate):
            guard let fingerprint = certificate.groupCallFingerprint else {
                throw FatalStateError.SerializationFailure
            }
            guard let data = try createJoinRequest(fingerprint: fingerprint) else {
                throw FatalStateError.SerializationFailure
            }
            return data
        }
    }
    
    private func createPeekRequest() throws -> Data? {
        var body = Groupcall_SfuHttpRequest.Peek()
        body.callID = groupCallDescription.callID.bytes
        
        return try? body.serializedData()
    }
    
    private func createJoinRequest(fingerprint: Data) throws -> Data? {
        var body = Groupcall_SfuHttpRequest.Join()
        body.callID = groupCallDescription.callID.bytes
        body.protocolVersion = groupCallDescription.protocolVersion
        body.dtlsFingerprint = fingerprint
        
        return try? body.serializedData()
    }
}
