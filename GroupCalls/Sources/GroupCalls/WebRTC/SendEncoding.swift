import Foundation
import WebRTC

struct SendEncoding {
    let rid: String
    let maxBitrateBps: UInt64
    let scalabilityMode: ScalabilityMode
    let scaleResolutionDownBy: UInt16?
    
    init(rid: String, maxBitrateBps: UInt64, scalabilityMode: ScalabilityMode, scaleResolutionDownBy: UInt16? = nil) {
        self.rid = rid
        self.maxBitrateBps = maxBitrateBps
        self.scalabilityMode = scalabilityMode
        self.scaleResolutionDownBy = scaleResolutionDownBy
    }
    
    func toRtcEncoding() -> RTCRtpEncodingParameters {
        let encoding = RTCRtpEncodingParameters()
        encoding.rid = rid
        encoding.isActive = true
        encoding.scaleResolutionDownBy = 1.0
        encoding.maxBitrateBps = NSNumber(integerLiteral: Int(maxBitrateBps))
        encoding.numTemporalLayers = (scalabilityMode.temporalLayers) as NSNumber
        encoding.scaleResolutionDownBy = scaleResolutionDownBy != nil ? Double(scaleResolutionDownBy!) as NSNumber : nil
        return encoding
    }
}
