//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@objc class VoIPCallAnswerMessage: NSObject {
    
    @objc enum MessageAction: Int {
        case reject
        case call
        
        /**
         Return the string of the current action for the ValidationLogger
         - Returns: String of the current action
         */
        func description() -> String {
            switch self {
            case .reject: return "reject"
            case .call: return "accept"
            }
        }
    }
    
    @objc enum MessageRejectReason: Int {
        case unknown
        case busy
        case timeout
        case reject
        case disabled
        case offHours
        
        /**
         Return the string of the current reject reason for the ValidationLogger
         - Returns: String of the current reject reason
         */
        func description() -> String {
            switch self {
            case .unknown: return "unknown"
            case .busy: return "busy"
            case .timeout: return "timeout"
            case .reject: return "reject"
            case .disabled: return "disabled"
            case .offHours: return "offHours"
            }
        }
    }

    @objc let action: MessageAction
    @objc var contact: Contact?
    @objc var answer: RTCSessionDescription?
    var completion: (() -> Void)?
    let callId: VoIPCallId
    let rejectReason: MessageRejectReason?
    let features: [String: Any?]?
    let isVideoAvailable: Bool
    
    init(action: MessageAction, contact: Contact?, answer: RTCSessionDescription?, rejectReason: MessageRejectReason?, features: [String: Any?]?, isVideoAvailable: Bool, callId: VoIPCallId, completion: (() -> Void)?) {
        self.action = action
        self.contact = contact
        self.answer = answer
        self.rejectReason = rejectReason
        self.completion = completion
        self.features = features
        self.isVideoAvailable = isVideoAvailable
        self.callId = callId
        super.init()
    }
}

extension VoIPCallAnswerMessage {
    static let kActionKey = "action"
    static let kAnswerKey = "answer"
    static let kRejectReasonKey = "rejectReason"
    static let kRTCSessionDescriptionTypeKey = "sdpType"
    static let kRTCSessionDescriptionSdpKey = "sdp"
    static let kFeaturesKey = "features"
    static let kFeaturesVideoKey = "video"
    static let kCallIdKey = "callId"
    
    enum VoIPCallAnswerMessageError: Error {
        case generateJson(error: Error)
    }

    
    @objc class func answerFromJSONDictionary(_ dictionary: [AnyHashable: Any]) -> VoIPCallAnswerMessage {
        let tmpAction: MessageAction = VoIPCallAnswerMessage.MessageAction(rawValue: dictionary[VoIPCallAnswerMessage.kActionKey] as! Int)!
        var tmpRejectReason: VoIPCallAnswerMessage.MessageRejectReason? = nil
        if let rejectReasonValue = dictionary[VoIPCallAnswerMessage.kRejectReasonKey] {
            tmpRejectReason = VoIPCallAnswerMessage.MessageRejectReason.init(rawValue: rejectReasonValue as! Int)
        }
        var tmpAnswer: RTCSessionDescription? = nil
        if let answerKey = dictionary[VoIPCallAnswerMessage.kAnswerKey] {
            tmpAnswer = RTCSessionDescription.description(from: answerKey as! [AnyHashable : Any])
        }
        
        var tmpFeatures: [String: Any?]?
        var isVideoAvailable: Bool = false
        if let features = dictionary[kFeaturesKey] as? [String: Any?] {
            tmpFeatures = features
            if features.keys.contains(kFeaturesVideoKey) {
                isVideoAvailable = true
            }
        }
        
        let tmpCallId = VoIPCallId(callId: dictionary[kCallIdKey] as? UInt32)
        
        return VoIPCallAnswerMessage.init(action: tmpAction, contact: nil, answer: tmpAnswer, rejectReason: tmpRejectReason, features: tmpFeatures, isVideoAvailable: isVideoAvailable, callId: tmpCallId, completion: nil)
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
    
    func jsonData() throws -> Data {
        var json = [AnyHashable: Any]()
        if answer != nil {
            let extensionConfig: VoIPCallSdpPatcher.RtpHeaderExtensionConfig = contact?.isVideoCallAvailable() ?? false ? .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER : .DISABLE
            json = [VoIPCallAnswerMessage.kCallIdKey: callId.callId, VoIPCallAnswerMessage.kActionKey: action.rawValue, VoIPCallAnswerMessage.kAnswerKey: [VoIPCallAnswerMessage.kRTCSessionDescriptionTypeKey: stringForType(), VoIPCallAnswerMessage.kRTCSessionDescriptionSdpKey: try VoIPCallSdpPatcher(extensionConfig).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: answer!.sdp)], VoIPCallAnswerMessage.kRejectReasonKey: rejectReason ?? 0]
            if isVideoAvailable {
                json[VoIPCallAnswerMessage.kFeaturesKey] = [VoIPCallAnswerMessage.kFeaturesVideoKey: nil]
            }
        } else {
            json = [VoIPCallAnswerMessage.kCallIdKey: callId.callId, VoIPCallAnswerMessage.kActionKey: action.rawValue, VoIPCallAnswerMessage.kRejectReasonKey: rejectReason?.rawValue ?? 0]
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch let error {
            throw VoIPCallAnswerMessageError.generateJson(error: error)
        }
    }
}
