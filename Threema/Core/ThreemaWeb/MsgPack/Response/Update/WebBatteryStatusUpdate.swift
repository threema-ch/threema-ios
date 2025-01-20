//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

class WebBatteryStatusUpdate: WebAbstractMessage {
    
    var percent: Int
    var isCharging: Bool
    
    init(_ requestID: String? = nil) {
        self.percent = Int(UIDevice.current.batteryLevel * 100)
        let batteryState = UIDevice.current.batteryState
        self.isCharging = batteryState == .full || batteryState == .charging
        
        let tmpArgs = [AnyHashable: Any?]()
        var tmpData: [AnyHashable: Any?] = ["isCharging": isCharging] as [String: Any]
        if percent < 0 {
            tmpData.updateValue(nil, forKey: "percent")
        }
        else {
            tmpData.updateValue(percent, forKey: "percent")
        }
        let tmpAck = requestID != nil ? WebAbstractMessageAcknowledgement(requestID, true, nil) : nil
        super.init(
            messageType: "update",
            messageSubType: "batteryStatus",
            requestID: nil,
            ack: tmpAck,
            args: tmpArgs,
            data: tmpData
        )
    }
}
