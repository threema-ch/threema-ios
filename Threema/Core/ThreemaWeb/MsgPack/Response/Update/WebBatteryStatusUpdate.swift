import Foundation

final class WebBatteryStatusUpdate: WebAbstractMessage {
    
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
