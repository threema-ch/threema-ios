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

@objc class VoIPCallOfferMessage: NSObject {
    @objc var offer: RTCSessionDescription?
    @objc var contact: Contact?
    @objc var completion: (() -> Void)?
    var callId: VoIPCallId
    
    var features: [String: Any?]?
    var isVideoAvailable: Bool
    
    @objc override init() {
        offer = nil
        contact = nil
        completion = nil
        features = nil
        isVideoAvailable = false
        callId = VoIPCallId.init(callId: 0)
        super.init()
    }
    
    init(offer: RTCSessionDescription?, contact: Contact?, features:[String: Any?]?, isVideoAvailable: Bool, callId: VoIPCallId, completion: (() -> Void)?) {
        
        self.offer = offer
        self.contact = contact
        self.completion = completion
        self.features = features
        self.isVideoAvailable = isVideoAvailable
        self.callId = callId
        super.init()
    }
}

extension VoIPCallOfferMessage {
    static let kOfferKey = "offer"
    static let kRTCSessionDescriptionTypeKey = "sdpType"
    static let kRTCSessionDescriptionSdpKey = "sdp"
    static let kFeaturesKey = "features"
    static let kFeaturesVideoKey = "video"
    static let kCallId = "callId"
    
    enum VoIPCallOfferMessageError: Error {
        case generateJson(error: Error)
    }

    
    @objc class func offerFromJSONDictionary(_ dictionary: [AnyHashable: Any]) -> VoIPCallOfferMessage {
        var tmpOffer: RTCSessionDescription? = nil
        if let offerKey = dictionary[VoIPCallOfferMessage.kOfferKey] {
            tmpOffer = RTCSessionDescription.description(from: offerKey as! [AnyHashable : Any])
        }
        
        var tmpFeatures: [String: Any?]?
        var isVideoAvailable: Bool = false
        if let features = dictionary[kFeaturesKey] as? [String: Any?] {
            tmpFeatures = features
            if features.keys.contains(kFeaturesVideoKey) {
                isVideoAvailable = true
            }
        }
        let tmpCallId = VoIPCallId(callId: dictionary[kCallId] as? UInt32)
        return VoIPCallOfferMessage.init(offer: tmpOffer, contact: nil, features: tmpFeatures, isVideoAvailable: isVideoAvailable, callId: tmpCallId, completion: nil)
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
        
    func jsonData() throws -> Data {
        var json = [AnyHashable: Any]()
        if offer != nil {
            json = [VoIPCallOfferMessage.kCallId: callId.callId, VoIPCallOfferMessage.kOfferKey: [VoIPCallOfferMessage.kRTCSessionDescriptionTypeKey: stringForType(), VoIPCallOfferMessage.kRTCSessionDescriptionSdpKey: offer?.sdp]]
            if isVideoAvailable {
                json[VoIPCallOfferMessage.kFeaturesKey] = [VoIPCallOfferMessage.kFeaturesVideoKey: nil]
            }
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        }
        catch let error {
            throw VoIPCallOfferMessageError.generateJson(error: error)
        }
    }
}
