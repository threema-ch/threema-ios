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

@objc public class VoIPCallOfferMessage: NSObject {
    public var offer: RTCSessionDescription?
    public var contactIdentity: String?
    public var completion: (() -> Void)?
    public var callID: VoIPCallID
    
    var features: [String: Any?]?
    public var isVideoAvailable: Bool
    
    override init() {
        self.offer = nil
        self.contactIdentity = nil
        self.completion = nil
        self.features = nil
        self.isVideoAvailable = false
        self.callID = VoIPCallID(callID: 0)
        super.init()
    }
    
    public init(
        offer: RTCSessionDescription?,
        contactIdentity: String?,
        features: [String: Any?]?,
        isVideoAvailable: Bool,
        callID: VoIPCallID,
        completion: (() -> Void)?
    ) {
        
        self.offer = offer
        self.contactIdentity = contactIdentity
        self.completion = completion
        self.features = features
        self.isVideoAvailable = isVideoAvailable
        self.callID = callID
        super.init()
    }
}

// MARK: - VoIPCallMessageProtocol

extension VoIPCallOfferMessage: VoIPCallMessageProtocol {
    static let kOfferKey = "offer"
    static let kRTCSessionDescriptionTypeKey = "sdpType"
    static let kRTCSessionDescriptionSdpKey = "sdp"
    static let kFeaturesKey = "features"
    static let kFeaturesVideoKey = "video"
    static let kCallID = "callId"
    
    enum VoIPCallOfferMessageError: Error {
        case generateJson(error: Error)
    }

    static func decodeAsObject<T>(_ dictionary: [AnyHashable: Any]) -> T where T: VoIPCallMessageProtocol {
        var tmpOffer: RTCSessionDescription?
        if let offerKey = dictionary[VoIPCallOfferMessage.kOfferKey] {
            tmpOffer = RTCSessionDescription.description(from: offerKey as! [AnyHashable: Any])
        }
        
        var tmpFeatures: [String: Any?]?
        var isVideoAvailable = false
        if let features = dictionary[kFeaturesKey] as? [String: Any?] {
            tmpFeatures = features
            if features.keys.contains(kFeaturesVideoKey) {
                isVideoAvailable = true
            }
        }
        let tmpCallID = VoIPCallID(callID: dictionary[kCallID] as? UInt32)
        return VoIPCallOfferMessage(
            offer: tmpOffer,
            contactIdentity: nil,
            features: tmpFeatures,
            isVideoAvailable: isVideoAvailable,
            callID: tmpCallID,
            completion: nil
        ) as! T
    }
    
    private func stringForType() -> String {
        if offer != nil {
            switch offer!.type {
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
        if offer != nil {
            json = [
                VoIPCallOfferMessage.kCallID: callID.callID,
                VoIPCallOfferMessage
                    .kOfferKey: [
                        VoIPCallOfferMessage.kRTCSessionDescriptionTypeKey: stringForType(),
                        VoIPCallOfferMessage.kRTCSessionDescriptionSdpKey: offer?.sdp,
                    ],
            ]
            if isVideoAvailable {
                json[VoIPCallOfferMessage.kFeaturesKey] = [VoIPCallOfferMessage.kFeaturesVideoKey: nil]
            }
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch {
            throw VoIPCallOfferMessageError.generateJson(error: error)
        }
    }
}
