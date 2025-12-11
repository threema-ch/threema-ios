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
import ThreemaProtocols

struct RTPHeaderExtensionIDs {
    
    enum RTPHeaderExtensionIDError: Error {
        case invalidKey
    }
    
    // Use only string array
    fileprivate static let fallbackMicrophone: [UInt: String] = [
        1: "urn:ietf:params:rtp-hdrext:sdes:mid",
        4: "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
        5: "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
        // TODO(SE-257): Disabled until we can use cryptex
        // 10: "urn:ietf:params:rtp-hdrext:ssrc-audio-level",
    ]

    fileprivate static let fallbackCameraAndScreen: [UInt: String] = [
        1: "urn:ietf:params:rtp-hdrext:sdes:mid",
        2: "urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id",
        3: "urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id",
        4: "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
        5: "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
        11: "urn:3gpp:video-orientation",
        12: "urn:ietf:params:rtp-hdrext:toffset",
    ]
    
    let microphone: [UInt: String]
    let cameraAndScreen: [UInt: String]
    
    init(_ joinResponse: Groupcall_SfuHttpResponse.Join) throws {
        // swiftformat:disable:next acronyms
        guard joinResponse.hasRtpHeaderExtensionIds else {
            self.microphone = RTPHeaderExtensionIDs.fallbackMicrophone
            self.cameraAndScreen = RTPHeaderExtensionIDs.fallbackCameraAndScreen
            return
        }
     
        // swiftformat:disable:next acronyms
        let extensionIDs = joinResponse.rtpHeaderExtensionIds
        
        self.microphone = [
            UInt(extensionIDs.mid): "urn:ietf:params:rtp-hdrext:sdes:mid",
            UInt(extensionIDs.absoluteSendTime): "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
            UInt(
                extensionIDs
                    .transportWideCongestionControl01
            ): "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
        ]
        
        self.cameraAndScreen = [
            UInt(extensionIDs.mid): "urn:ietf:params:rtp-hdrext:sdes:mid",
            UInt(extensionIDs.rtpStreamID): "urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id",
            UInt(extensionIDs.repairedRtpStreamID): "urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id",
            UInt(extensionIDs.absoluteSendTime): "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time",
            UInt(
                extensionIDs
                    .transportWideCongestionControl01
            ): "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01",
            UInt(extensionIDs.videoOrientation): "urn:3gpp:video-orientation",
            UInt(extensionIDs.timeOffset): "urn:ietf:params:rtp-hdrext:toffset",
        ]
            
        try validate()
    }
    
    // Used in tests
    init() {
        self.microphone = RTPHeaderExtensionIDs.fallbackMicrophone
        self.cameraAndScreen = RTPHeaderExtensionIDs.fallbackCameraAndScreen
    }
    
    private func validate() throws {
        for key in microphone.keys {
            guard key >= 1, key <= 14 else {
                throw RTPHeaderExtensionIDError.invalidKey
            }
        }
        
        for key in cameraAndScreen.keys {
            guard key >= 1, key <= 14 else {
                throw RTPHeaderExtensionIDError.invalidKey
            }
        }
    }
}
