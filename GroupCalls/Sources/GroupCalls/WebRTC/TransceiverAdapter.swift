import Foundation

struct TransceiverAdapter<RTCRtpTransceiverImpl: RTCRtpTransceiverProtocol>: Sendable {
    var mid: String
    var transceiver: RTCRtpTransceiverImpl
}
