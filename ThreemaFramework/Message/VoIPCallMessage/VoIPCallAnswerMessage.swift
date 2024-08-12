//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
import WebRTC

@objc public class VoIPCallAnswerMessage: NSObject {
    
    public enum MessageAction: Int {
        case reject
        case call
        
        /// Return the string of the current action for the ValidationLogger
        /// - Returns: String of the current action
        
        public func description() -> String {
            switch self {
            case .reject: "reject"
            case .call: "accept"
            }
        }
    }
    
    public enum MessageRejectReason: Int {
        case unknown
        case busy
        case timeout
        case reject
        case disabled
        case offHours
        
        /// Return the string of the current reject reason for the ValidationLogger
        /// - Returns: String of the current reject reason
        public func description() -> String {
            switch self {
            case .unknown: "unknown"
            case .busy: "busy"
            case .timeout: "timeout"
            case .reject: "reject"
            case .disabled: "disabled"
            case .offHours: "offHours"
            }
        }
    }
    
    public let action: MessageAction
    public var contactIdentity: String?
    public var answer: RTCSessionDescription?
    public var completion: (() -> Void)?
    public let callID: VoIPCallID
    public let rejectReason: MessageRejectReason?
    let features: [String: Any?]?
    public let isVideoAvailable: Bool
    public let isUserInteraction: Bool
    
    public init(
        action: MessageAction,
        contactIdentity: String?,
        answer: RTCSessionDescription?,
        rejectReason: MessageRejectReason?,
        features: [String: Any?]?,
        isVideoAvailable: Bool,
        isUserInteraction: Bool,
        callID: VoIPCallID,
        completion: (() -> Void)?
    ) {
        self.action = action
        self.contactIdentity = contactIdentity
        self.answer = answer
        self.rejectReason = rejectReason
        self.completion = completion
        self.features = features
        self.isVideoAvailable = isVideoAvailable
        self.isUserInteraction = isUserInteraction
        self.callID = callID
        super.init()
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallAnswerMessage: VoIPCallMessageProtocol {
    static let kActionKey = "action"
    static let kAnswerKey = "answer"
    static let kRejectReasonKey = "rejectReason"
    static let kRTCSessionDescriptionTypeKey = "sdpType"
    static let kRTCSessionDescriptionSdpKey = "sdp"
    static let kFeaturesKey = "features"
    static let kFeaturesVideoKey = "video"
    
    enum VoIPCallAnswerMessageError: Error {
        case generateJson(error: Error)
    }

    static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any]) -> T where T: VoIPCallMessageProtocol {
        let tmpAction: MessageAction = VoIPCallAnswerMessage
            .MessageAction(rawValue: dictionary[VoIPCallAnswerMessage.kActionKey] as! Int)!
        var tmpRejectReason: VoIPCallAnswerMessage.MessageRejectReason?
        if let rejectReasonValue = dictionary[VoIPCallAnswerMessage.kRejectReasonKey] {
            tmpRejectReason = VoIPCallAnswerMessage.MessageRejectReason(rawValue: rejectReasonValue as! Int)
        }
        var tmpAnswer: RTCSessionDescription?
        if let answerKey = dictionary[VoIPCallAnswerMessage.kAnswerKey] {
            tmpAnswer = RTCSessionDescription.description(from: answerKey as! [AnyHashable: Any])
        }
        
        var tmpFeatures: [String: Any?]?
        var isVideoAvailable = false
        if let features = dictionary[kFeaturesKey] as? [String: Any?] {
            tmpFeatures = features
            if features.keys.contains(kFeaturesVideoKey) {
                isVideoAvailable = true
            }
        }
        
        let tmpCallID = VoIPCallID(callID: dictionary[VoIPCallConstants.callIDKey] as? UInt32)
        
        return VoIPCallAnswerMessage(
            action: tmpAction,
            contactIdentity: nil,
            answer: tmpAnswer,
            rejectReason: tmpRejectReason,
            features: tmpFeatures,
            isVideoAvailable: isVideoAvailable,
            isUserInteraction: false,
            callID: tmpCallID,
            completion: nil
        ) as! T
    }
    
    private func stringForType() -> String {
        if answer != nil {
            switch answer!.type {
            case .offer:
                return "offer"
            case .prAnswer:
                return "pranswer"
            case .answer:
                return "answer"
            default:
                return ""
            }
        }
        return ""
    }
    
    public func encodeAsJson() throws -> Data {
        var json = [AnyHashable: Any]()
        if answer != nil {
            let extensionConfig: VoIPCallSdpPatcher
                .RtpHeaderExtensionConfig = isVideoAvailable ? .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER : .DISABLE
            json = try [
                VoIPCallConstants.callIDKey: callID.callID,
                VoIPCallAnswerMessage.kActionKey: action.rawValue,
                VoIPCallAnswerMessage
                    .kAnswerKey: [
                        VoIPCallAnswerMessage.kRTCSessionDescriptionTypeKey: stringForType(),
                        VoIPCallAnswerMessage.kRTCSessionDescriptionSdpKey: VoIPCallSdpPatcher(extensionConfig)
                            .patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: answer!.sdp),
                    ],
                VoIPCallAnswerMessage.kRejectReasonKey: rejectReason ?? 0,
            ]
            if isVideoAvailable {
                json[VoIPCallAnswerMessage.kFeaturesKey] = [VoIPCallAnswerMessage.kFeaturesVideoKey: nil]
            }
        }
        else {
            json = [
                VoIPCallConstants.callIDKey: callID.callID,
                VoIPCallAnswerMessage.kActionKey: action.rawValue,
                VoIPCallAnswerMessage.kRejectReasonKey: rejectReason?.rawValue ?? 0,
            ]
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallAnswerMessageError.generateJson(error: error)
        }
    }
}
