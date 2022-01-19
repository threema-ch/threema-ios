//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

internal protocol VoIPStatsRepresentation {
    func getShortRepresentation() -> String
    func getRepresentation() -> String
}

@objc public enum CandidatePairVariant: Int {
    case NONE = 0x00
    case OVERVIEW = 0x01
    case DETAILED = 0x02
    case OVERVIEW_AND_DETAILED = 0x03 // OVERVIEW | DETAILED
}

@objc public class VoIPStatsOptions: NSObject {
    @objc public var transport = false
    @objc public var inboundRtp = false
    @objc public var outboundRtp = false
    @objc public var codecs = false
    @objc public var selectedCandidatePair = false
    @objc public var candidatePairsFlag = CandidatePairVariant.NONE
    @objc public var tracks = false
    @objc public var framesReceived = false
    @objc public var crypto = false
}

internal enum Direction {
    case inbound
    case outbound
}

internal enum CodecMimeTypePrimary {
    case unknown
    case audio
    case video
    
    internal static func fromRepresentation(string: String?) -> CodecMimeTypePrimary {
        if string == nil {
            return .unknown
        }
        switch string {
        case "audio":
            return .audio
        case "video":
            return .video
        default:
            return .unknown
        }
    }
    
    internal func toShortRepresentation() -> String {
        switch self {
        case .audio:
            return "a"
        case .video:
            return "v"
        case .unknown:
            return "?"
        }
    }
    
    internal func toRepresentation() -> String {
        switch self {
        case .audio:
            return "audio"
        case .video:
            return "video"
        case .unknown:
            return "?"
        }
    }
}

@objc public class VoIPStats: NSObject, VoIPStatsRepresentation {
    private let report: RTCStatisticsReport
    private let options: VoIPStatsOptions
    private let previousState: VoIPStatsState?
    private let timestamp: CFTimeInterval
            
    private var transport: Transport?
    private var crypto: Crypto?
    private var selectedCandidatePair: CandidatePair?
    private var inboundRtpAudio: InboundRtp?
    private var inboundRtpVideo: InboundRtp?
    private var outboundRtpAudio: OutboundRtp?
    private var outboundRtpVideo: OutboundRtp?
    private var inboundTrackVideo: Track?
    private var outboundTrackVideo: Track?
    private var inboundCodecs: [String: Codec]?
    private var outboundCodecs: [String: Codec]?
    private let transceivers: [RTCRtpTransceiver]
    private var rtpTransceivers: [RtpTransceiver]?
    private var candidatePairs: [CandidatePair]?
    
    private var totalFramesReceived: UInt64?
    
    internal class BytesTransferred: VoIPStatsRepresentation {
        public let sent: UInt64?
        public let received: UInt64?

        internal init(_ entry: RTCStatistics) {
            if let sentNumber = entry.values["bytesSent"] as? NSNumber {
                self.sent = UInt64(truncating: sentNumber)
            } else {
                self.sent = nil
            }
            
            if let receivedNumber = entry.values["bytesReceived"] as? NSNumber {
                self.received = UInt64(truncating: receivedNumber)
            } else {
                self.received = nil
            }
        }
        
        public func getShortRepresentation() -> String {
            var result = "tx="
            
            if let sent = self.sent {
                result += "\(toHumanReadableByteCount(sent))"
            } else {
                result += "n/a"
            }
            
            result += ", rx="
            if let received = self.received {
                result += "\(toHumanReadableByteCount(received))"
            } else {
                result += "n/a"
            }
            
            return result
        }
        
        public func getRepresentation() -> String {
            return getShortRepresentation()
        }
    }
    
    internal class Candidate: VoIPStatsRepresentation {
        public let address: String?
        public let type: String?
        public let protocol_: String?
        public let network: String?
        
        internal init(_ entry: RTCStatistics) {
            self.address = entry.values["ip"] as? String
            self.type = entry.values["candidateType"] as? String
            self.protocol_ = entry.values["protocol"] as? String
            self.network = entry.values["networkType"] as? String
        }
        
        public func getShortRepresentation() -> String {
            var result = "\(self.address ?? "?.?.?.?") \(self.type ?? "n/a") \(self.protocol_ ?? "n/a")"
            if let network = self.network {
                result += " " + network
            }
            return result
        }
        
        public func getRepresentation() -> String {
            var result = "address=\(self.address ?? "?.?.?.?"), type=\(self.type ?? "n/a"), protocol=\(self.protocol_ ?? "n/a")"
            if let network = self.network {
                result += ", network=\(network)"
            }
            return result
        }
        
        public func usesCellular() -> Bool {
            return network == "cellular"
        }
    }
    
    internal class CandidatePair: VoIPStatsRepresentation {
        internal enum State: String {
            case unknown
            case frozen
            case waiting
            case in_progress = "in-progress"
            case succeeded
            case failed
        }
        
        public let id: String
        public let priority: UInt64
        public let local: Candidate?
        public let remote: Candidate?
        public let nominated: Bool?
        public let state: State
        public let bytesTransferred: BytesTransferred
        public let roundTripTime: RoundTripTime
        public let availableOutgoingBitrate: Double?
        public let usesRelay: Bool

        static public func fromId(_ id: String, report: RTCStatisticsReport) -> CandidatePair? {
            // Lookup pair
            let id = id.dropFirst(20)
            for entry in report.statistics.values {
                let entryId = candidatePairId(statsId: entry.id)
                if entryId == id {
                    return CandidatePair(entry, report: report)
                }
            }
            return nil
        }

        
        public init(_ entry: RTCStatistics, report: RTCStatisticsReport) {
            // Id
            self.id = candidatePairId(statsId: entry.id)
            
            // Priority
            self.priority = CandidatePair.priority(entry)
            
            // Candidates
            let localCandidateId = entry.values["localCandidateId"] as? String
            let remoteCandidateId = entry.values["remoteCandidateId"] as? String
            (self.local, self.remote) = CandidatePair.lookupCandidates(
                localCandidateId: localCandidateId, remoteCandidateId: remoteCandidateId, report: report)
            
            // Nominated
            self.nominated = CandidatePair.nominated(entry)
        
            // State
            self.state = CandidatePair.state(entry)
            
            // Bytes transferred
            self.bytesTransferred = BytesTransferred(entry)
            
            // RTT
            self.roundTripTime = RoundTripTime(entry)
            
            // Available bitrate
            self.availableOutgoingBitrate = CandidatePair.availableOutgoingBitrate(entry)
                        
            // Check use relay
            self.usesRelay = CandidatePair.usesRelay(entry, local: local, remote: remote)
        }
        
        static internal func lookupCandidates(localCandidateId: String?, remoteCandidateId: String?, report: RTCStatisticsReport)
            -> (Candidate?, Candidate?) {
            var localCandidate: Candidate?
            var remoteCandidate: Candidate?
            if localCandidateId != nil || remoteCandidateId != nil {
                for entry in report.statistics.values {
                    if localCandidateId != nil && entry.id == localCandidateId {
                        localCandidate = Candidate(entry)
                    }
                    if remoteCandidateId != nil && entry.id == remoteCandidateId {
                        remoteCandidate = Candidate(entry)
                    }
                }
            }
            return (localCandidate, remoteCandidate)
        }
        
        static private func priority(_ entry: RTCStatistics) -> UInt64 {
            if let p = entry.values["priority"] as? NSNumber {
                return UInt64(truncating: p)
            }
            return 0
        }
        
        static private func nominated(_ entry: RTCStatistics) -> Bool? {
            if let n = entry.values["nominated"] as? NSNumber {
                return Bool(truncating: n)
            }
            return nil
        }
        
        static private func state(_ entry: RTCStatistics) -> State {
            if let s = entry.values["state"] as? String,
               let newState = State.init(rawValue: s) {
                return newState
            }
            return .unknown
        }
        
        static private func availableOutgoingBitrate(_ entry: RTCStatistics) -> Double? {
            if let aOB = entry.values["availableOutgoingBitrate"] as? NSNumber {
                return Double(truncating: aOB)
            }
            return nil
        }
        
        static private func usesRelay(_ entry: RTCStatistics, local: Candidate?, remote: Candidate?) -> Bool {
            if let local = local, local.type == "relay" {
                return true
            }
            else if let remote = remote, remote.type == "relay" {
                return true
            }
            return false
        }
            
        public func getShortRepresentation() -> String {
            var result = "pair=\(self.state) "
            if let nominated = self.nominated, nominated == true {
                result += " nominated"
            }
            result += "\n"
            
            result += "local="
            if local != nil {
                result += local!.getShortRepresentation()
            } else {
                result += "n/a"
            }
            result += "\n"
            
            result += "remote="
            if remote != nil {
                result += remote!.getShortRepresentation()
            } else {
                result += "n/a"
            }
            result += "\n"
            
            result += "relayed=\(usesRelay)\n"
            
            result += "\(bytesTransferred.getShortRepresentation())"
            if availableOutgoingBitrate != nil {
                result += " bitrate=\(String(format: "%.0fkbps", availableOutgoingBitrate! / 1000))"
            }
            result += "\n"
            
            result += "\(roundTripTime.getShortRepresentation())"
            return result
        }
        
        public func getRepresentation() -> String {
            var result = "id=\(self.id), state=\(self.state), priority="
            if self.priority > 0 {
                result += String(self.priority)
            } else {
                result += "n/a"
            }
            result += ", active="
            if let active = self.nominated {
                result += active ? "yes" : "no"
            } else {
                result += "n/a"
            }
            result += ", \(self.roundTripTime.getRepresentation())" +
                      ", \(self.bytesTransferred.getRepresentation())" +
                      "\n  Local: \(self.local?.getRepresentation() ?? "n/a")" +
                      "\n  Remote: \(self.remote?.getRepresentation() ?? "n/a")"
            return result
        }
        
        public func getStatusChar() -> String {
            /*
             * '-' -> frozen: The pair has been held back due to another pair with the same
             *        foundation that is currently in the waiting state.
             * '.' -> waiting: Pair checking has not started, yet.
             * '+' -> in-progress: Pair checking is in progress. In the webrtc.org implementation,
             *        this is also being used for pairs that (temporarily) have no connection.
             * 'o' -> succeeded: A connection could be established via this pair.
             * 'x' -> failed: No connection could be established via this pair and no further
             *        attempts will be made.
             */
            switch self.state {
            case .unknown: return "?"
            case .frozen: return "-"
            case .waiting: return "."
            case .in_progress: return "+"
            case .succeeded: return "o"
            case .failed: return "x"
            }
        }
    }
    
    internal class Codec: VoIPStatsRepresentation {
        
        internal struct CodecMimeType {
            public let primary: CodecMimeTypePrimary
            public let secondary: String
        }

        public let codecId: String
        public let direction: Direction
        private let mimeType: CodecMimeType
        private let clockRate: UInt64?
        
        public init(_ entry: RTCStatistics) {
            self.codecId = entry.id
            self.direction = codecId.contains("Inbound") ? Direction.inbound : Direction.outbound
            self.mimeType =  Codec.getMimeType(mimeTypeString: entry.values["mimeType"] as? String)
            if let clockRateNumber = entry.values["clockRate"] as? NSNumber {
                self.clockRate = UInt64(truncating: clockRateNumber)
            } else {
                self.clockRate = nil
            }
        }
        
        public func getShortRepresentation() -> String {
            var result = "\(self.mimeType.primary.toShortRepresentation())/\(self.mimeType.secondary)"
            if clockRate == nil {
                return result
            }
            
            result += "@"
            let clockRateK = clockRate! / 1000
            if clockRateK >= 1 {
                result += "\(clockRateK)k"
            } else {
                result += " \(self.clockRate!)"
            }
            
            return result
        }
        
        public func getRepresentation() -> String {
            var result = "mime-type=\(self.mimeType.primary.toRepresentation())/\(self.mimeType.secondary)"
                        
            result += ", clock-rate="
            if clockRate != nil {
                result += "\(self.clockRate!)"
            } else {
                result += "n/a"
            }
            return result
        }
        
        public static func getMimeType(mimeTypeString: String?) -> CodecMimeType {
            if mimeTypeString == nil {
                return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
            }

            if let mimeType = mimeTypeString?.split(separator: "/") {
                if mimeType.count != 2 {
                    return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
                }
                return CodecMimeType(primary: CodecMimeTypePrimary.fromRepresentation(string: String(mimeType[0])), secondary: String(mimeType[1]))
            }
            
            return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
        }
    }
    
    internal class Rtp: VoIPStatsRepresentation {
        private let codecs: [String: Codec]
        
        public let codecId: String?
        public let kind: String
        public var jitter: Double?
        public var packetsTotal: UInt64?
        public var bytesTotal: UInt64?
        public var packetsLost: UInt64?
        public var packetLossPercent: Float64?
        public var qualityLimitationReason: String?
        public var qualityLimitationResolutionChanges: UInt64?
        public var implementation: String?
        public var averageFps: Float?
        public var bitrate: Double?
        
        public init(_ entry: RTCStatistics, codecs: [String: Codec]) {
            self.codecs = codecs
            self.codecId = entry.values["codecId"] as? String
            self.kind = entry.values["kind"] as? String ?? "?"
        }

        public func getShortRepresentation() -> String {
            var shortRepresentation = "\(kind)"
            
            if packetsTotal != nil && packetsLost != nil {
                shortRepresentation.append(" packets-lost=\(packetsLost!)/\(packetsTotal!)(\(String(format: "%.1f", packetLossPercent ?? 0))%)")
            }
            else if packetsTotal != nil {
                shortRepresentation.append(" packets=\(packetsTotal!)")
            }
            if jitter != nil {
                shortRepresentation.append(" jitter=\(jitter!)")
            }
            
            if bitrate != nil {
                shortRepresentation.append(" bitrate=\(String(format: "%.0f", bitrate! / 1000))kbps")
            }

            if averageFps != nil {
                shortRepresentation.append(" avfps=\(String(format: "%.1f", averageFps!))")
            }
            
            shortRepresentation.append(" codec=")
            if codecId != nil, let codec = codecs[codecId!] {
                shortRepresentation.append(codec.getShortRepresentation())
            } else {
                shortRepresentation.append("?")
            }
            
            if implementation != nil {
                switch implementation {
                case "HWEncoder":
                    shortRepresentation.append(" (hw)")
                    break
                case "SWEncoder":
                    shortRepresentation.append(" (sw)")
                    break
                case "unknown":
                    break
                default:
                    shortRepresentation.append(" (\(implementation!))")
                }
            }
            
            if qualityLimitationReason != nil {
                shortRepresentation.append(" limit=\(qualityLimitationReason!.replacingOccurrences(of: "bandwidth", with: "bw"))")
                if qualityLimitationResolutionChanges != nil {
                    shortRepresentation.append("/\(qualityLimitationResolutionChanges!)")
                }
            }

            return shortRepresentation
        }
        
        public func getRepresentation() -> String {
            return getShortRepresentation()
        }
    }
    
    internal class InboundRtp: Rtp {
        public init(_ entry: RTCStatistics, codecs: [String: Codec], previousState: VoIPStatsState?, timestamp: CFTimeInterval) {
            super.init(entry, codecs: codecs)
            if let j = entry.values["jitter"] as? NSNumber {
                self.jitter = Double(truncating: j)
            } else {
                self.jitter = nil
            }
            
            if let pt = entry.values["packetsReceived"] as? NSNumber {
                self.packetsTotal = UInt64(truncating: pt)
            } else {
                self.packetsTotal = nil
            }
            
            if let bt = entry.values["bytesReceived"] as? NSNumber {
                self.bytesTotal = UInt64(truncating: bt)
            } else {
                self.bytesTotal = nil
            }
            
            if let pl = entry.values["packetsLost"] as? NSNumber {
                self.packetsLost = UInt64(truncating: pl)
            } else {
                self.packetsLost = nil
            }

            self.packetLossPercent = calculatePacketLoss()
            
            
            var totalInterFrameDelay: Double? = nil
            if let tifd = entry.values["totalInterFrameDelay"] as? NSNumber {
                totalInterFrameDelay = Double(truncating: tifd)
            }
            var framesDecoded: UInt64? = nil
            if let fd = entry.values["framesDecoded"] as? NSNumber {
                framesDecoded = UInt64(truncating: fd)
            }
            
            if totalInterFrameDelay != nil && framesDecoded != nil {
                averageFps = calculateAverageFps(totalInterFrameDelay: totalInterFrameDelay!, framesDecoded: framesDecoded!)
            }
            
            if previousState != nil, previousState!.videoBytesReceived != nil && bytesTotal != nil {
                bitrate = calculateVideoBitrate(previousTimestamp: previousState!.timestampUs, previousBytes: previousState!.videoBytesReceived!, currentTimestamp: timestamp, currentBytes: bytesTotal!)
            }
        }
                
        private func calculatePacketLoss() -> Float64? {
            if packetsTotal == nil || packetsLost == nil {
                return nil
            }
            
            if packetsLost! > UInt64(0) {
                return Float64(packetsLost!) / Float64(packetsTotal!) * Float64(100)
            } else {
                return 0
            }
        }
        
        private func calculateAverageFps(totalInterFrameDelay: Double, framesDecoded: UInt64) -> Float {
            if framesDecoded == 0 {
                return 0.0
            }
            return Float(1.0 / (totalInterFrameDelay / Double(framesDecoded)))
        }
    }
    
    internal class OutboundRtp: Rtp {
        public init(_ entry: RTCStatistics, codecs: [String: Codec], previousState: VoIPStatsState?, timestamp: CFTimeInterval) {
            super.init(entry, codecs: codecs)
            
            if let pt = entry.values["packetsSent"] as? NSNumber {
                self.packetsTotal = UInt64(truncating: pt)
            } else {
                self.packetsTotal = nil
            }
            
            if let bt = entry.values["bytesSent"] as? NSNumber {
                self.bytesTotal = UInt64(truncating: bt)
            } else {
                self.bytesTotal = nil
            }
            
            self.qualityLimitationReason = entry.values["qualityLimitationReason"] as? String
            
            if let qlrc = entry.values["qualityLimitationResolutionChanges"] as? NSNumber {
                self.qualityLimitationResolutionChanges = UInt64(truncating: qlrc)
            } else {
                self.qualityLimitationResolutionChanges = nil
            }

            self.implementation = entry.values["encoderImplementation"] as? String

            if previousState != nil, previousState!.videoBytesSent != nil && bytesTotal != nil {
                bitrate = calculateVideoBitrate(previousTimestamp: previousState!.timestampUs, previousBytes: previousState!.videoBytesSent!, currentTimestamp: timestamp, currentBytes: bytesTotal!)
            }
        }
    }
    
    internal class Track: VoIPStatsRepresentation {
        public let kind: String
        public var frameWidth: UInt64?
        public var frameHeight: UInt64?
        public var freezeCount: UInt64?
        public var pauseCount: UInt64?
        
        public var ended: Bool?
        public var remoteSource: Bool?
        public var detached: Bool?
        public var totalFramesReceived: UInt64?

        public init(_ entry: RTCStatistics) {
            self.kind = entry.values["kind"] as? String ?? "?"
            
            if let fw = entry.values["frameWidth"] as? NSNumber {
                self.frameWidth = UInt64(truncating: fw)
            } else {
                self.frameWidth = nil
            }
            
            if let fh = entry.values["frameHeight"] as? NSNumber {
                self.frameHeight = UInt64(truncating: fh)
            } else {
                self.frameHeight = nil
            }
            
            if let fc = entry.values["freezeCount"] as? NSNumber {
                self.freezeCount = UInt64(truncating: fc)
            } else {
                self.freezeCount = nil
            }
            
            if let pc = entry.values["pauseCount"] as? NSNumber {
                self.pauseCount = UInt64(truncating: pc)
            } else {
                self.pauseCount = nil
            }
            
            if let e = entry.values["ended"] as? NSNumber {
                self.ended = Bool(truncating: e)
            } else {
                self.ended = nil
            }
            
            if let rs = entry.values["remoteSource"] as? NSNumber {
                self.remoteSource = Bool(truncating: rs)
            } else {
                self.remoteSource = nil
            }
            
            if let tfr = entry.values["framesReceived"] as? NSNumber {
                self.totalFramesReceived = UInt64(truncating: tfr)
            } else {
                self.totalFramesReceived = nil
            }
            
            if let d = entry.values["detached"] as? NSNumber {
                self.detached = Bool(truncating: d)
            } else {
                self.detached = nil
            }
        }
               
        public func getShortRepresentation() -> String {
            var result = "\(self.kind)"
            if frameWidth != nil && frameHeight != nil {
                result += " res=\(frameWidth!)x\(frameHeight!)"
            }
            if freezeCount != nil {
                result += " freeze=\(freezeCount!)"
            }
            if pauseCount != nil {
                result += " pause=\(pauseCount!)"
            }
            return result
        }
        
        public func getRepresentation() -> String {
            return getShortRepresentation()
        }
        
        public func areFramesReceived() -> Bool {
            if kind == "video" {
                if totalFramesReceived != nil, ended != nil, remoteSource != nil, totalFramesReceived! > UInt64(0) && ended == false && remoteSource == true {
                    return true
                }
            }
            return false
        }
    }
    
    internal class RtpTransceiver: VoIPStatsRepresentation {
        
        public let transceiver: RTCRtpTransceiver

        public init(_ rtpTransceiver: RTCRtpTransceiver) {
            self.transceiver = rtpTransceiver
        }
               
        public func getShortRepresentation() -> String {
            var result = "kind=\(mediaType())"
            result += ", mid=\(transceiver.mid)"
            var transceiverDirection = transceiver.direction
            if transceiver.currentDirection(&transceiverDirection) {
                result += ", cur-dir=\(direction())"
            }
            
            result += "\n sender: \(addParametersShortRepresentation(transceiver.sender.parameters))"
            result += "\n receiver: \(addParametersShortRepresentation(transceiver.receiver.parameters))"
            return result
        }
        
        public func getRepresentation() -> String {
            var result = "kind=\(mediaType())"
            result += ", mid=\(transceiver.mid)"
            result += ", direction=\(direction())"
            var transceiverDirection = transceiver.direction
            if transceiver.currentDirection(&transceiverDirection) {
                result += ", cur-dir=\(direction())"
            }
            
            result += "\n Sender: \(addParametersRepresentation(transceiver.sender.parameters))"
            result += "\n Receiver: \(addParametersRepresentation(transceiver.receiver.parameters))"
            
            return result
        }
        
        private func addParametersShortRepresentation(_ parameters: RTCRtpParameters) -> String {
            var result = ""
            var plain = 0
            var encrypted = 0
            
            // Add amount of encrypted vs. non-encrypted header extensions
            for headerExtension in parameters.headerExtensions {
                if headerExtension.isEncrypted {
                    encrypted += 1
                } else {
                    plain += 1
                }
            }
            
            result += "#exts=\(encrypted)e/\(plain)p, "
            
            // Add codecs
            result += "cs="
            if parameters.codecs.count > 0 {
                for codec in parameters.codecs {
                    // Add codec
                    result += "\(codec.name)/\(shortClockRate(codec: codec))"
                    if let numChannels = codec.numChannels {
                        result += "/\(numChannels)"
                    }
                    
                    // Add codec attributes
                    // Note: We only care about Opus CBR attributes
                    if codec.name == "opus" {
                        let cbr = codec.parameters["cbr"] as? String
                        result += "["
                        result += "cbr=\(cbr ?? "?")]"
                    }
                    result += " "
                }
            } else {
                result += "?"
            }
            
            return result
        }
        
        private func addParametersRepresentation(_ parameters: RTCRtpParameters) -> String {
            var result = ""
            
            // Add codecs
            result += "\n    Codecs (\(parameters.codecs.count))"
            if parameters.codecs.count > 0 {
                for (_, codec) in parameters.codecs.enumerated() {
                    // add codec
                    result += "\n    - name=\(codec.name), clock-rate=\(shortClockRate(codec: codec))"
                    
                    if let numChannels = codec.numChannels {
                        result += ", #channels=\(numChannels)"
                    }
                    
                    // Add codec attributes
                    result += ", attributes="
                    for (key,value) in codec.parameters {
                        result += "\(key)=\(value) "
                    }
                }
            }
            
            // Add header extensions
            var extensionResult = ""
            var plain = 0
            var encrypted = 0

            for (_, headerExtension) in parameters.headerExtensions.enumerated() {
                extensionResult += "\n    - id=\(headerExtension.id)"
                extensionResult += ", encrypted=\(headerExtension.isEncrypted ? "true" : "false")"
                extensionResult += ", uri=\(headerExtension.uri)"
                if headerExtension.isEncrypted {
                    encrypted += 1
                } else {
                    plain += 1
                }
            }
            
            result += "\n    Header Extensions (\(encrypted)e/\(plain)p)\(extensionResult)"

            return result
        }
        
        private func mediaType() -> String {
            switch transceiver.mediaType {
            case .audio:
                return "audio"
            case .video:
                return "video"
            default:
                return "?"
            }
        }
        
        private func direction() -> String {
            switch transceiver.direction {
            case .sendRecv:
                return "send/recv"
            case .sendOnly:
                return "send"
            case .recvOnly:
                return "recv"
            case .inactive:
                return "inactive"
            default:
                return "?"
            }
        }
        
        private func shortClockRate(codec: RTCRtpCodecParameters) -> String {
            let clockRateK = codec.clockRate!.intValue / 1000
            if clockRateK >= 1 {
                return "\(clockRateK)k"
            }
            return codec.clockRate!.stringValue
        }
    }
    
    internal class RoundTripTime: VoIPStatsRepresentation {
        private let latest: Double?
        private var average: Double?
        
        public init(_ entry: RTCStatistics) {
            if let latestNumber = entry.values["currentRoundTripTime"] as? NSNumber {
                self.latest = Double(truncating: latestNumber)
            } else {
                self.latest = nil
            }
            

            average = nil
            let totalRoundTripTime = entry.values["totalRoundTripTime"] as? NSNumber
            let responsesReceived = entry.values["responsesReceived"] as? NSNumber
                        
            if totalRoundTripTime != nil, responsesReceived != nil {
                if UInt64(truncating: responsesReceived!).signum() == 1 {
                    let t = Decimal(Double(truncating: totalRoundTripTime!))
                    let r = Decimal(UInt64(truncating: responsesReceived!))
                    let av = NSDecimalNumber(decimal: t / r)
                    average = Double(truncating: av)
                }
            }
        }
        
        public func getShortRepresentation() -> String {
            var result = "rtt-latest="
            if latest != nil {
                result += "\(String(format: "%.3f", latest!))"
            } else {
                result += "n/a"
            }
            
            result += " rtt-avg="
            if average != nil {
                result += "\(String(format: "%.3f", average!))"
            } else {
                result += "n/a"
            }
            
            return result
        }
        
        public func getRepresentation() -> String {
            return getShortRepresentation()
        }
    }
    
    internal class Transport: VoIPStatsRepresentation {
        public let selectedCandidatePairId: String
        private let bytesTransferred: BytesTransferred
        private let dtlsState: String
        
        public init(_ entry: RTCStatistics) {
            if let candidatePairIdString = entry.values["selectedCandidatePairId"] as? String {
                self.selectedCandidatePairId = candidatePairId(statsId: candidatePairIdString)
            } else {
                self.selectedCandidatePairId = "???"
            }
            
            self.bytesTransferred = BytesTransferred(entry)
            self.dtlsState = entry.values["dtlsState"] as? String ?? "n/a"
        }
        
        public func getShortRepresentation() -> String {
            return "dtls=\(dtlsState) \(bytesTransferred.getShortRepresentation())"
        }
        
        public func getRepresentation() -> String {
            return "dtls-state=\(dtlsState), selected-candidate-pair-id=\(self.selectedCandidatePairId), \(bytesTransferred.getRepresentation())"
        }
    }
    
    internal class Crypto: VoIPStatsRepresentation {
        private let dtlsVersion: String
        private let dtlsCipher: String
        private let srtpCipher: String
        
        public init(_ entry: RTCStatistics) {
            self.dtlsVersion = VoIPStats.Crypto.dtlsVersionString(dtlsVersionBytes: entry.values["tlsVersion"] as? String)
            self.dtlsCipher = entry.values["dtlsCipher"] as? String ?? "?"
            self.srtpCipher = entry.values["srtpCipher"] as? String ?? "?"
        }
        
        private static func dtlsVersionString(dtlsVersionBytes: String?) -> String {
            if (dtlsVersionBytes == nil) {
                return "?";
            }
            switch dtlsVersionBytes {
                case "FEFF":
                    return "1.0";
                case "FEFD":
                    return "1.2";
                default:
                    return "?";
            }
        }

        public func getShortRepresentation() -> String {
            return "dtls=v\(dtlsVersion):\(dtlsCipher) srtp=\(srtpCipher)"
        }
        
        public func getRepresentation() -> String {
            return "dtls-version=\(dtlsVersion), dtls-cipher=\(dtlsCipher), srtp-cipher=\(srtpCipher)"
        }
    }
    
    public init(report: RTCStatisticsReport, options: VoIPStatsOptions, transceivers:[RTCRtpTransceiver], previousState: VoIPStatsState?) {
        self.report = report
        self.options = options
        self.transceivers = transceivers
        self.previousState = previousState
        self.timestamp = report.timestamp_us
        super.init()
        self.extract()
    }

    // O(n^2) but could be optimised for O(n) if needed
    internal func extract() {
        self.inboundCodecs = [String: Codec]()
        self.outboundCodecs = [String: Codec]()

        if self.options.candidatePairsFlag != CandidatePairVariant.NONE {
            self.candidatePairs = [CandidatePair]()
        }
        
        // Extract values
        for entry in report.statistics.values {
            switch entry.type {
            case "codec":
                let codec = Codec(entry)
                if codec.direction == .inbound {
                    self.inboundCodecs![codec.codecId] = codec
                } else {
                    self.outboundCodecs![codec.codecId] = codec
                }
                break
            case "candidate-pair":
                if options.candidatePairsFlag != .NONE {
                    self.candidatePairs!.append(CandidatePair(entry, report:report))
                }
                break
            case "inbound-rtp":
                if options.inboundRtp {
                    let kind = entry.values["kind"] as? String
                    if kind == "audio" {
                        self.inboundRtpAudio = InboundRtp(entry, codecs: inboundCodecs!, previousState: previousState, timestamp: timestamp)
                    }
                    else if kind == "video" {
                        self.inboundRtpVideo = InboundRtp(entry, codecs: inboundCodecs!, previousState: previousState, timestamp: timestamp)
                    }
                }
                break
            case "outbound-rtp":
                if options.outboundRtp {
                    let kind = entry.values["kind"] as? String
                    if kind == "audio" {
                        self.outboundRtpAudio = OutboundRtp(entry, codecs: outboundCodecs!, previousState: previousState, timestamp: timestamp)
                    }
                    else if kind == "video" {
                        self.outboundRtpVideo = OutboundRtp(entry, codecs: outboundCodecs!, previousState: previousState, timestamp: timestamp)
                    }
                }
                break
            case "track":
                if options.tracks {
                    let kind = entry.values["kind"] as? String
                    let inbound = entry.values["remoteSource"] as? NSNumber
                    if kind == "video" && inbound != nil {
                        if inbound!.boolValue {
                            self.inboundTrackVideo = Track(entry)
                        } else {
                            self.outboundTrackVideo = Track(entry)
                        }
                    }
                }
                if options.framesReceived {
                    let kind = entry.values["kind"] as? String
                    let inbound = entry.values["remoteSource"] as? NSNumber
                    if kind == "video" && inbound != nil {
                        if inbound!.boolValue {
                            let track = Track(entry)
                            if track.totalFramesReceived != nil && track.areFramesReceived() {
                                if totalFramesReceived == nil {
                                    totalFramesReceived = track.totalFramesReceived
                                } else {
                                    totalFramesReceived! += track.totalFramesReceived!
                                }
                            }
                        }
                    }
                }
                break
            case "transport":
                if options.transport {
                    self.transport = Transport(entry)
                }
                if options.crypto {
                    self.crypto = Crypto(entry)
                }
                if !options.selectedCandidatePair {
                    break
                }
                
                if let candidatePairIdString = entry.values["selectedCandidatePairId"] as? String {
                    if let candidatePair = CandidatePair.fromId(candidatePairIdString, report: report) {
                        self.selectedCandidatePair = candidatePair
                    }
                }
                break
            default:
                break // Ignore
            }
        }
        
        // Sort candidate pairs by priority
        if let candidatePairs = self.candidatePairs {
            self.candidatePairs = candidatePairs.sorted(by: { $0.priority > $1.priority })
        }
        
        // Add transceivers (if any)
        rtpTransceivers = [RtpTransceiver]()
        for transceiver in transceivers {
            rtpTransceivers?.append(RtpTransceiver(transceiver))
        }
    }
    
    @objc public func getShortRepresentation() -> String {
        var result = ""
        if let transport = self.transport, options.transport {
            result += "\(transport.getShortRepresentation())\n"
        }
        if let crypto = self.crypto, options.crypto {
            result += "\(crypto.getShortRepresentation())\n"
        }
        if let candidatePairs = self.candidatePairs, self.options.candidatePairsFlag.rawValue & CandidatePairVariant.OVERVIEW.rawValue != 0 {
            result += "pairs(\(candidatePairs.count))=\(candidatePairs.map({ $0.getStatusChar() }).joined())\n"
        }
        if let selectedCandidatePair = self.selectedCandidatePair {
            result += "\(selectedCandidatePair.getShortRepresentation())\n"
        }
        result += "\n"
        
        if let inboundRtpAudio = self.inboundRtpAudio {
            result += "in: \(inboundRtpAudio.getShortRepresentation())\n"
        }
        if let inboundRtpVideo = self.inboundRtpVideo {
            result += "in: \(inboundRtpVideo.getShortRepresentation())\n"
        }
        if let outboundRtpAudio = self.outboundRtpAudio {
            result += "out: \(outboundRtpAudio.getShortRepresentation())\n"
        }
        if let outboundRtpVideo = self.outboundRtpVideo {
            result += "out: \(outboundRtpVideo.getShortRepresentation())\n"
        }
        result += "\n"
        
        if let inboundTrackVideo = self.inboundTrackVideo {
            result += "in/track- \(inboundTrackVideo.getShortRepresentation())\n"
        }
        if let outboundTrackVideo = self.outboundTrackVideo {
            result += "out/track- \(outboundTrackVideo.getShortRepresentation())\n"
        }

        if options.codecs {
            if let inboundCodecs = self.inboundCodecs {
                result += "in/codecs "
                for codec in inboundCodecs.values {
                    result += codec.getShortRepresentation()
                    result += " "
                }
                result += "\n"
            }
            
           if let outboundCodecs = self.outboundCodecs {
                result += "out/codecs "
                for codec in outboundCodecs.values {
                    result += codec.getShortRepresentation()
                    result += " "
                }
                result += "\n"
            }
        }
        
        if let rtpTransceivers = self.rtpTransceivers  {
            result += "\n"
            for transceiver in rtpTransceivers {
                result += "transceiver \(transceiver.getShortRepresentation())\n"
            }
            result += "\n"
        }
        
        if let candidatePairs = self.candidatePairs, self.options.candidatePairsFlag.rawValue & CandidatePairVariant.DETAILED.rawValue != 0 {
            result += "\(candidatePairs.map({ $0.getShortRepresentation() }).joined(separator: "\n"))\n"
        }
        
        // Strip newline (if any)
        result.removeLast(1)
        return result
    }
    
    @objc public func getRepresentation() -> String {
        var result = ""
        if let transport = self.transport {
            result += "Transport: \(transport.getRepresentation())\n"
        }
        if let crypto = self.crypto {
            result += "Crypto: \(crypto.getRepresentation())\n"
        }
        if let candidatePairs = self.candidatePairs, self.options.candidatePairsFlag.rawValue & CandidatePairVariant.OVERVIEW.rawValue != 0 {
            result += "Candidate Pairs Overview (\(candidatePairs.count)): \(candidatePairs.map({ $0.getStatusChar() }).joined())\n"
        }
        if let selectedCandidatePair = self.selectedCandidatePair {
            result += "Selected Candidate Pair: \(selectedCandidatePair.getRepresentation())\n"
        }
        if let inboundRtpAudio = self.inboundRtpAudio {
            result += "Inbound RTP Audio: \(inboundRtpAudio.getRepresentation())\n"
        }
        if let inboundRtpVideo = self.inboundRtpVideo {
            result += "Inbound RTP Video: \(inboundRtpVideo.getRepresentation())\n"
        }
        if let outboundRtpAudio = self.outboundRtpAudio {
            result += "Outbound RTP Audio: \(outboundRtpAudio.getRepresentation())\n"
        }
        if let outboundRtpVideo = self.outboundRtpVideo {
            result += "Outbound RTP Video: \(outboundRtpVideo.getRepresentation())\n"
        }
        if let inboundTrackVideo = self.inboundTrackVideo {
            result += "Inbound Track Video: \(inboundTrackVideo.getRepresentation())\n"
        }
        if let outboundTrackVideo = self.outboundTrackVideo {
            result += "Outbound Track Video: \(outboundTrackVideo.getRepresentation())\n"
        }
        if let inboundCodecs = self.inboundCodecs {
            result += "Inbound Codecs (\(inboundCodecs.count))\n"
            for codec in inboundCodecs.values {
                result += "- \(codec.getShortRepresentation())\n"
            }
        }
        if let outboundCodecs = self.outboundCodecs {
            result += "Outbound Codecs (\(outboundCodecs.count))\n"
            for codec in outboundCodecs.values {
                result += "- \(codec.getShortRepresentation())\n"
            }
        }
        if let rtpTransceivers = self.rtpTransceivers  {
            result += "Transceivers (\(rtpTransceivers.count))\n"
            for transceiver in rtpTransceivers {
                result += "- \(transceiver.getRepresentation())"
            }
            result += "\n"
        }
        if let candidatePairs = self.candidatePairs, self.options.candidatePairsFlag.rawValue & CandidatePairVariant.DETAILED.rawValue != 0 {
            result += "Candidate Pairs (\(candidatePairs.count))\n"
            result += candidatePairs.map({ "- \($0.getRepresentation())\n" }).joined()
        }
        
        // Strip newline (if any)
        result.removeLast(1)
        return result
    }
    
    @objc public func isReceivingVideo() -> Bool {
        // check previous and actual frames and compare
        if totalFramesReceived != nil, previousState != nil, previousState?.videoFramesReceived != nil {
            let diff = totalFramesReceived!.distance(to: previousState!.videoFramesReceived!)
            if diff != 0 {
                return true
            }
        }
        return false
    }
    
    public func isSelectedCandidatePairCellular() -> Bool {
        if let candidatePair = selectedCandidatePair, let local = candidatePair.local {
            return local.usesCellular()
        }
        return false
    }
    
    public func usesRelay() -> Bool {
        if selectedCandidatePair != nil , selectedCandidatePair!.usesRelay {
            return true
        }
        return false
    }
        
    public func buildVoIPStatsState() -> VoIPStatsState {
        return VoIPStatsState(timestampUs: timestamp, videoBytesSent: outboundRtpVideo?.bytesTotal ?? nil, videoBytesReceived: inboundRtpVideo?.bytesTotal ?? nil, videoFramesReceived: totalFramesReceived ?? nil)
    }
}

public struct VoIPStatsState {
    public let timestampUs: Double
    public let videoBytesSent: UInt64?
    public let videoBytesReceived: UInt64?
    public let videoFramesReceived: UInt64?
}

// Convert byte count into human readable number
// Based on: https://stackoverflow.com/a/3758880
internal func toHumanReadableByteCount(_ value: UInt64) -> String {
    let unit:UInt64 = 1024
    if value < unit {
        return "\(value)B"
    } else {
        let value = Double(value)
        let unit = Double(unit)
        let exp = (log(value) / log(unit)).binade
        return "\(String(format: "%.1f", value / pow(unit, exp)))\("KMGTPE"[Int(exp - 1)])iB"
    }
}

// Convert ms to seconds
internal func msToSeconds(_ value: String?) -> String {
    guard let value = Double(value) else {
        return "n/a"
    }
    return String(format: "%.3f", value / 1000)
}

internal func msToSeconds(_ value: Double?) -> String {
    guard value != nil else {
        return "n/a"
    }
    return String(format: "%.3f", value! / 1000)
}


// Calculate a fraction
internal func toFraction(_ dividend: String?, divisor: String?) -> String {
    guard let dividend = Double(dividend), let divisor = Double(divisor), divisor > 0 else {
        return "n/a"
    }
    return String(format: "%.1f", dividend / divisor)
}

internal func candidatePairId(statsId: String?) -> String {
    if statsId == nil {
        return "???"
    }
    let substring = String(statsId!.dropFirst(20))
    if substring.count > 0 {
        return substring
    }
    return "???"
}

internal func calculateVideoBitrate(previousTimestamp: Double, previousBytes: UInt64, currentTimestamp: Double, currentBytes: UInt64) -> Double? {
    let bytesSent = currentBytes.distance(to: previousBytes)
    let microSecondsElapsed = currentTimestamp - previousTimestamp
    
    if microSecondsElapsed < 0 {
        debugPrint("Previous state must not have a higher timestamp than current state")
        return nil
    }
    if microSecondsElapsed < 100000 {
        debugPrint("State timestamps should be at least 100ms apart")
        return nil
    }
    return Double((8 * Double(bytesSent)) / (microSecondsElapsed / 1000 / 1000))
}
