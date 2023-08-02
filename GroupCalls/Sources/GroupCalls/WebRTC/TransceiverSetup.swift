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
import WebRTC

enum TransceiverSetup {
    static func setupTransceiver(_ transceiver: RTCRtpTransceiver) {
        // TODO: Setup Transceiver
        
        var error: NSError?
        transceiver.setDirection(.recvOnly, error: &error)
        
        transceiver.receiver.track?.isEnabled = true
        transceiver.sender.track?.isEnabled = true
        
        if let error {
            fatalError(error.localizedDescription)
        }
    }
    
    static func setupLocalTransceiver(_ transceiver: RTCRtpTransceiver, kind: SdpKind) {
        
        var error: NSError?
        transceiver.setDirection(.sendOnly, error: &error)
        
        if let error {
            fatalError(error.localizedDescription)
        }
        
        TransceiverSetup.setCameraVideoSimulcastEncodingParameters(kind: kind, transceiver: transceiver)
    }
    
    static func setCameraVideoSimulcastEncodingParameters(kind: SdpKind, transceiver: RTCRtpTransceiver) {
        guard kind == .video else {
            return
        }
        
        DDLogNotice("[GroupCall] Current parameters \(transceiver.sender.parameters)")
        
        let prevParam = transceiver.sender.parameters
        
        transceiver.sender.parameters = {
            let param = RTCRtpParameters()
            // In Android this was taken from an enum. We have guessed the correct value here.
            param.degradationPreference = NSNumber(value: 3)
            param.encodings = [RTCRtpEncodingParameters]()
            param.encodings = GroupCallSessionDescription.CAMERA_SEND_ENCODINGS.map { $0.toRtcEncoding() }
            // swiftformat:disable acronyms
            param.transactionId = prevParam.transactionId
            // swiftformat:enable acronyms
            
            return param
        }()
    }
}
