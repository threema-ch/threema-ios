import Foundation

protocol VoIPStatsRepresentation {
    func getShortRepresentation() -> String
    func getRepresentation() -> String
}

enum CandidatePairVariant: Int {
    case NONE = 0x00
    case OVERVIEW = 0x01
    case DETAILED = 0x02
    case OVERVIEW_AND_DETAILED = 0x03 // OVERVIEW | DETAILED
}

final class VoIPStatsOptions {
    var transport = false
    var inboundRtp = false
    var outboundRtp = false
    var codecs = false
    var selectedCandidatePair = false
    var candidatePairsFlag = CandidatePairVariant.NONE
    var tracks = false
    var framesReceived = false
    var crypto = false
}

enum CodecMimeTypePrimary {
    case unknown
    case audio
    case video
    
    static func fromRepresentation(string: String?) -> CodecMimeTypePrimary {
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
    
    func toShortRepresentation() -> String {
        switch self {
        case .audio:
            "a"
        case .video:
            "v"
        case .unknown:
            "?"
        }
    }
    
    func toRepresentation() -> String {
        switch self {
        case .audio:
            "audio"
        case .video:
            "video"
        case .unknown:
            "?"
        }
    }
}

final class VoIPStats: VoIPStatsRepresentation {
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
    private var codecs: [String: Codec]?

    /// Instantaneous microphone level, from the `media-source` entry.
    private var micAudioLevel: Double?

    /// Playout delay above this is not explainable by any network this app should be running on.
    private static let inflatedJitterBufferTargetSeconds = 0.4

    /// Network jitter below this means the link is not asking for a large buffer.
    private static let calmNetworkJitterSeconds = 0.05

    /// Set when the jitter buffer is holding back playout by a lot *and the network did not ask it to*.
    var inflatedJitterBufferDiagnosis: String? {
        guard let playout = inboundRtpAudio?.audioPlayout,
              let target = playout.jitterBufferTargetDelayPerSample,
              target > Self.inflatedJitterBufferTargetSeconds else {
            return nil
        }

        let jitter = inboundRtpAudio?.jitter ?? 0
        guard jitter < Self.calmNetworkJitterSeconds, playout.concealmentEventsDelta ?? 0 == 0 else {
            // The link genuinely wants a buffer this size.
            return nil
        }

        let delay = playout.jitterBufferDelayPerSample ?? 0
        return "target=\(Int(target * 1000))ms jbuf=\(Int(delay * 1000))ms jitter=\(jitter) " +
            "compressed=\(playout.removedSamplesDelta ?? 0) — no network cause, playout stalled earlier in the call"
    }
    
    private let transceivers: [RTCRtpTransceiver]
    private var rtpTransceivers: [RtpTransceiver]?
    private var candidatePairs: [CandidatePair]?
    
    private var totalFramesReceived: UInt64?
    
    final class BytesTransferred: VoIPStatsRepresentation {
        let sent: UInt64?
        let received: UInt64?

        init(_ entry: RTCStatistics) {
            if let sentNumber = entry.values["bytesSent"] as? NSNumber {
                self.sent = UInt64(truncating: sentNumber)
            }
            else {
                self.sent = nil
            }
            
            if let receivedNumber = entry.values["bytesReceived"] as? NSNumber {
                self.received = UInt64(truncating: receivedNumber)
            }
            else {
                self.received = nil
            }
        }
        
        func getShortRepresentation() -> String {
            var result = "tx="
            
            if let sent {
                result += "\(toHumanReadableByteCount(sent))"
            }
            else {
                result += "n/a"
            }
            
            result += ", rx="
            if let received {
                result += "\(toHumanReadableByteCount(received))"
            }
            else {
                result += "n/a"
            }
            
            return result
        }
        
        func getRepresentation() -> String {
            getShortRepresentation()
        }
    }
    
    final class Candidate: VoIPStatsRepresentation {
        let address: String?
        let type: String?
        let protocol_: String?
        let network: String?
        
        init(_ entry: RTCStatistics) {
            self.address = entry.values["ip"] as? String
            self.type = entry.values["candidateType"] as? String
            self.protocol_ = entry.values["protocol"] as? String
            self.network = entry.values["networkType"] as? String
        }
        
        func getShortRepresentation() -> String {
            var result = "\(address ?? "?.?.?.?") \(type ?? "n/a") \(protocol_ ?? "n/a")"
            if let network {
                result += " " + network
            }
            return result
        }
        
        func getRepresentation() -> String {
            var result = "address=\(address ?? "?.?.?.?"), type=\(type ?? "n/a"), protocol=\(protocol_ ?? "n/a")"
            if let network {
                result += ", network=\(network)"
            }
            return result
        }
        
        func usesCellular() -> Bool {
            network == "cellular"
        }
    }
    
    final class CandidatePair: VoIPStatsRepresentation {
        enum State: String {
            case unknown
            case frozen
            case waiting
            case in_progress = "in-progress"
            case succeeded
            case failed
        }
        
        let id: String
        let priority: UInt64
        let local: Candidate?
        let remote: Candidate?
        let nominated: Bool?
        let state: State
        let bytesTransferred: BytesTransferred
        let roundTripTime: RoundTripTime
        let availableOutgoingBitrate: Double?
        let usesRelay: Bool

        static func fromID(_ id: String, report: RTCStatisticsReport) -> CandidatePair? {
            // Lookup pair
            let id = id.dropFirst(20)
            for entry in report.statistics.values {
                let entryID = candidatePairID(statsID: entry.id)
                if entryID == id {
                    return CandidatePair(entry, report: report)
                }
            }
            return nil
        }

        init(_ entry: RTCStatistics, report: RTCStatisticsReport) {
            // ID
            self.id = candidatePairID(statsID: entry.id)
            
            // Priority
            self.priority = CandidatePair.priority(entry)
            
            // Candidates
            let localCandidateID = entry.values["localCandidateId"] as? String
            let remoteCandidateID = entry.values["remoteCandidateId"] as? String
            (local, remote) = CandidatePair.lookupCandidates(
                localCandidateID: localCandidateID, remoteCandidateID: remoteCandidateID, report: report
            )
            
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
        
        static func lookupCandidates(
            localCandidateID: String?,
            remoteCandidateID: String?,
            report: RTCStatisticsReport
        )
            -> (Candidate?, Candidate?) {
            var localCandidate: Candidate?
            var remoteCandidate: Candidate?
            if localCandidateID != nil || remoteCandidateID != nil {
                for entry in report.statistics.values {
                    if localCandidateID != nil, entry.id == localCandidateID {
                        localCandidate = Candidate(entry)
                    }
                    if remoteCandidateID != nil, entry.id == remoteCandidateID {
                        remoteCandidate = Candidate(entry)
                    }
                }
            }
            return (localCandidate, remoteCandidate)
        }
        
        private static func priority(_ entry: RTCStatistics) -> UInt64 {
            if let p = entry.values["priority"] as? NSNumber {
                return UInt64(truncating: p)
            }
            return 0
        }
        
        private static func nominated(_ entry: RTCStatistics) -> Bool? {
            if let n = entry.values["nominated"] as? NSNumber {
                return Bool(truncating: n)
            }
            return nil
        }
        
        private static func state(_ entry: RTCStatistics) -> State {
            if let s = entry.values["state"] as? String,
               let newState = State(rawValue: s) {
                return newState
            }
            return .unknown
        }
        
        private static func availableOutgoingBitrate(_ entry: RTCStatistics) -> Double? {
            if let aOB = entry.values["availableOutgoingBitrate"] as? NSNumber {
                return Double(truncating: aOB)
            }
            return nil
        }
        
        private static func usesRelay(_ entry: RTCStatistics, local: Candidate?, remote: Candidate?) -> Bool {
            if let local, local.type == "relay" {
                return true
            }
            else if let remote, remote.type == "relay" {
                return true
            }
            return false
        }
            
        func getShortRepresentation() -> String {
            var result = "pair=\(state) "
            if let nominated, nominated == true {
                result += " nominated"
            }
            result += "\n"
            
            result += "local="
            if local != nil {
                result += local!.getShortRepresentation()
            }
            else {
                result += "n/a"
            }
            result += "\n"
            
            result += "remote="
            if remote != nil {
                result += remote!.getShortRepresentation()
            }
            else {
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
        
        func getRepresentation() -> String {
            var result = "id=\(id), state=\(state), priority="
            if priority > 0 {
                result += String(priority)
            }
            else {
                result += "n/a"
            }
            result += ", active="
            if let active = nominated {
                result += active ? "yes" : "no"
            }
            else {
                result += "n/a"
            }
            result += ", \(roundTripTime.getRepresentation())" +
                ", \(bytesTransferred.getRepresentation())" +
                "\n  Local: \(local?.getRepresentation() ?? "n/a")" +
                "\n  Remote: \(remote?.getRepresentation() ?? "n/a")"
            return result
        }
        
        func getStatusChar() -> String {
            // '-' -> frozen: The pair has been held back due to another pair with the same
            //        foundation that is currently in the waiting state.
            // '.' -> waiting: Pair checking has not started, yet.
            // '+' -> in-progress: Pair checking is in progress. In the webrtc.org implementation,
            //        this is also being used for pairs that (temporarily) have no connection.
            // 'o' -> succeeded: A connection could be established via this pair.
            // 'x' -> failed: No connection could be established via this pair and no further
            //        attempts will be made.
            switch state {
            case .unknown: "?"
            case .frozen: "-"
            case .waiting: "."
            case .in_progress: "+"
            case .succeeded: "o"
            case .failed: "x"
            }
        }
    }
    
    final class Codec: VoIPStatsRepresentation {
        
        struct CodecMimeType {
            let primary: CodecMimeTypePrimary
            let secondary: String
        }

        public let codecID: String
        private let mimeType: CodecMimeType
        private let clockRate: UInt64?

        public init(_ entry: RTCStatistics) {
            self.codecID = entry.id
            self.mimeType = Codec.getMimeType(mimeTypeString: entry.values["mimeType"] as? String)
            if let clockRateNumber = entry.values["clockRate"] as? NSNumber {
                self.clockRate = UInt64(truncating: clockRateNumber)
            }
            else {
                self.clockRate = nil
            }
        }
        
        func getShortRepresentation() -> String {
            var result = "\(mimeType.primary.toShortRepresentation())/\(mimeType.secondary)"
            if clockRate == nil {
                return result
            }
            
            result += "@"
            let clockRateK = clockRate! / 1000
            if clockRateK >= 1 {
                result += "\(clockRateK)k"
            }
            else {
                result += " \(clockRate!)"
            }
            
            return result
        }
        
        func getRepresentation() -> String {
            var result = "mime-type=\(mimeType.primary.toRepresentation())/\(mimeType.secondary)"
                        
            result += ", clock-rate="
            if clockRate != nil {
                result += "\(clockRate!)"
            }
            else {
                result += "n/a"
            }
            return result
        }
        
        static func getMimeType(mimeTypeString: String?) -> CodecMimeType {
            if mimeTypeString == nil {
                return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
            }

            if let mimeType = mimeTypeString?.split(separator: "/") {
                if mimeType.count != 2 {
                    return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
                }
                return CodecMimeType(
                    primary: CodecMimeTypePrimary.fromRepresentation(string: String(mimeType[0])),
                    secondary: String(mimeType[1])
                )
            }
            
            return CodecMimeType(primary: CodecMimeTypePrimary.unknown, secondary: "?")
        }
    }
    
    /// Audio playout metrics of an `inbound-rtp` audio entry
    ///
    /// These answer two questions the rest of the stats cannot: whether the jitter buffer is
    /// holding back playout by seconds (the RFC 3550 `jitter` above is a *network* metric and stays
    /// in the low milliseconds even when playout is three seconds behind), and whether media that
    /// is demonstrably arriving is actually being played out.
    ///
    /// All the underlying WebRTC values except `audioLevel` are cumulative over the whole call, so
    /// reporting them raw is useless here: a three second spike that recovers averages away to
    /// nothing over a five minute call. Everything printed is a delta against the previous sample,
    /// carried over in `VoIPStatsState` the same way `bytesTransferred` already is.
    struct AudioPlayout: VoIPStatsRepresentation {

        // Cumulative values as reported. Retained so the next sample can difference against them;
        // never printed directly.
        let jitterBufferDelay: Double?
        let jitterBufferTargetDelay: Double?
        let jitterBufferEmittedCount: UInt64?
        let concealedSamples: UInt64?
        let concealmentEvents: UInt64?
        let insertedSamplesForDeceleration: UInt64?
        let removedSamplesForAcceleration: UInt64?
        let totalSamplesReceived: UInt64?
        let totalAudioEnergy: Double?

        /// Level of the most recent audio sample, 0...1. Instantaneous, no delta needed. Staying at
        /// zero while `packetsReceived` climbs is the signature of "media arrives, playout never
        /// starts".
        let audioLevel: Double?

        /// Mean playout delay over the last sampling period, in seconds
        private(set) var jitterBufferDelayPerSample: Double?

        /// Mean delay NetEQ was *aiming* for over the last sampling period, in seconds. This rising
        /// is what turns a network blip into seconds of added latency that never recovers.
        private(set) var jitterBufferTargetDelayPerSample: Double?

        private(set) var concealedSamplesDelta: UInt64?
        private(set) var concealmentEventsDelta: UInt64?
        private(set) var insertedSamplesDelta: UInt64?
        private(set) var removedSamplesDelta: UInt64?
        private(set) var totalSamplesReceivedDelta: UInt64?
        private(set) var totalAudioEnergyDelta: Double?

        /// Share of the samples played out over the last sampling period that had to be concealed
        private(set) var concealedPercent: Double?

        init(_ entry: RTCStatistics, previous: AudioPlayout?) {
            self.jitterBufferDelay = entry.doubleValue("jitterBufferDelay")
            self.jitterBufferTargetDelay = entry.doubleValue("jitterBufferTargetDelay")
            self.jitterBufferEmittedCount = entry.uInt64Value("jitterBufferEmittedCount")
            self.concealedSamples = entry.uInt64Value("concealedSamples")
            self.concealmentEvents = entry.uInt64Value("concealmentEvents")
            self.insertedSamplesForDeceleration = entry.uInt64Value("insertedSamplesForDeceleration")
            self.removedSamplesForAcceleration = entry.uInt64Value("removedSamplesForAcceleration")
            self.totalSamplesReceived = entry.uInt64Value("totalSamplesReceived")
            self.totalAudioEnergy = entry.doubleValue("totalAudioEnergy")
            self.audioLevel = entry.doubleValue("audioLevel")

            // Both delays are sums over the emitted samples, so both are divided by the same
            // emitted count delta to get a mean for the period
            if let emittedCountDelta = cumulativeDelta(
                self.jitterBufferEmittedCount,
                previous?.jitterBufferEmittedCount
            ), emittedCountDelta > 0 {
                if let delayDelta = cumulativeDelta(self.jitterBufferDelay, previous?.jitterBufferDelay) {
                    self.jitterBufferDelayPerSample = delayDelta / Double(emittedCountDelta)
                }
                if let targetDelayDelta = cumulativeDelta(
                    self.jitterBufferTargetDelay,
                    previous?.jitterBufferTargetDelay
                ) {
                    self.jitterBufferTargetDelayPerSample = targetDelayDelta / Double(emittedCountDelta)
                }
            }

            self.concealedSamplesDelta = cumulativeDelta(self.concealedSamples, previous?.concealedSamples)
            self.concealmentEventsDelta = cumulativeDelta(self.concealmentEvents, previous?.concealmentEvents)
            self.insertedSamplesDelta = cumulativeDelta(
                self.insertedSamplesForDeceleration,
                previous?.insertedSamplesForDeceleration
            )
            self.removedSamplesDelta = cumulativeDelta(
                self.removedSamplesForAcceleration,
                previous?.removedSamplesForAcceleration
            )
            self.totalSamplesReceivedDelta = cumulativeDelta(self.totalSamplesReceived, previous?.totalSamplesReceived)
            self.totalAudioEnergyDelta = cumulativeDelta(self.totalAudioEnergy, previous?.totalAudioEnergy)

            if let concealedSamplesDelta = self.concealedSamplesDelta,
               let totalSamplesReceivedDelta = self.totalSamplesReceivedDelta, totalSamplesReceivedDelta > 0 {
                self.concealedPercent = Double(concealedSamplesDelta) / Double(totalSamplesReceivedDelta) * 100
            }
        }

        func getShortRepresentation() -> String {
            var parts = [String]()

            if let jitterBufferDelayPerSample {
                var jitterBuffer = "jbuf=\(String(format: "%.0f", jitterBufferDelayPerSample * 1000))ms"
                if let jitterBufferTargetDelayPerSample {
                    jitterBuffer += "/target=\(String(format: "%.0f", jitterBufferTargetDelayPerSample * 1000))ms"
                }
                parts.append(jitterBuffer)
            }

            if let concealedSamplesDelta {
                var concealed = "concealed=\(concealedSamplesDelta)"
                if let concealedPercent {
                    concealed += "(\(String(format: "%.1f", concealedPercent))%)"
                }
                if let concealmentEventsDelta {
                    concealed += "/\(concealmentEventsDelta)evt"
                }
                parts.append(concealed)
            }

            if let insertedSamplesDelta, let removedSamplesDelta {
                parts.append("stretched=\(insertedSamplesDelta)/compressed=\(removedSamplesDelta)")
            }

            // Deliberately coarse — see `levelBucket`
            if let audioLevel {
                parts.append("level=\(AudioPlayout.levelBucket(audioLevel))")
            }

            // Over a 30s sampling period an instantaneous level of zero proves nothing: the remote
            // party may simply not have been speaking at that instant. Whether *any* energy
            // accumulated over the whole period is what separates "playout never started" from
            // "nobody was talking", and it is a single bit.
            if let totalAudioEnergyDelta {
                parts.append("playout=\(totalAudioEnergyDelta > 0 ? "active" : "silent")")
            }

            return parts.joined(separator: " ")
        }

        func getRepresentation() -> String {
            getShortRepresentation()
        }

        /// Bucket an audio level for logging
        ///
        /// `audioLevel` and `totalAudioEnergy` are the only values here derived from call *content*
        /// rather than from transport or DSP behaviour, and they describe the remote party's speech —
        /// who never consented to the log being exported to support. A run of precise levels is an
        /// amplitude envelope of the conversation: far too coarse to recover speech, but enough to
        /// show who spoke when and for how long.
        ///
        /// The diagnosis only needs "is anything coming out of the decoder at all", so only a coarse
        /// bucket is logged. Four buckets at a 30s (or, while connecting, 2s) interval answer that
        /// while carrying essentially nothing about the conversation.
        static func levelBucket(_ level: Double) -> String {
            switch level {
            case ..<0.0001:
                "silent"
            case ..<0.01:
                "low"
            case ..<0.1:
                "mid"
            default:
                "high"
            }
        }
    }

    class Rtp: VoIPStatsRepresentation {
        private let codecs: [String: Codec]
        
        let codecID: String?
        let kind: String
        var jitter: Double?
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
            self.codecID = entry.values["codecId"] as? String
            self.kind = entry.values["kind"] as? String ?? "?"
        }

        public func getShortRepresentation() -> String {
            var shortRepresentation = "\(kind)"
            
            if packetsTotal != nil, packetsLost != nil {
                shortRepresentation
                    .append(
                        " packets-lost=\(packetsLost!)/\(packetsTotal!)(\(String(format: "%.1f", packetLossPercent ?? 0))%)"
                    )
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
            if codecID != nil, let codec = codecs[codecID!] {
                shortRepresentation.append(codec.getShortRepresentation())
            }
            else {
                shortRepresentation.append("?")
            }
            
            if implementation != nil {
                switch implementation {
                case "HWEncoder":
                    shortRepresentation.append(" (hw)")
                case "SWEncoder":
                    shortRepresentation.append(" (sw)")
                case "unknown":
                    break
                default:
                    shortRepresentation.append(" (\(implementation!))")
                }
            }
            
            if qualityLimitationReason != nil {
                shortRepresentation
                    .append(" limit=\(qualityLimitationReason!.replacingOccurrences(of: "bandwidth", with: "bw"))")
                if qualityLimitationResolutionChanges != nil {
                    shortRepresentation.append("/\(qualityLimitationResolutionChanges!)")
                }
            }

            return shortRepresentation
        }
        
        public func getRepresentation() -> String {
            getShortRepresentation()
        }
    }
    
    final class InboundRtp: Rtp {

        /// Only populated for the audio entry
        private(set) var audioPlayout: AudioPlayout?

        public init(
            _ entry: RTCStatistics,
            codecs: [String: Codec],
            previousState: VoIPStatsState?,
            timestamp: CFTimeInterval
        ) {
            super.init(entry, codecs: codecs)
            if let j = entry.values["jitter"] as? NSNumber {
                self.jitter = Double(truncating: j)
            }
            else {
                self.jitter = nil
            }
            
            if let pt = entry.values["packetsReceived"] as? NSNumber {
                self.packetsTotal = UInt64(truncating: pt)
            }
            else {
                self.packetsTotal = nil
            }
            
            if let bt = entry.values["bytesReceived"] as? NSNumber {
                self.bytesTotal = UInt64(truncating: bt)
            }
            else {
                self.bytesTotal = nil
            }
            
            if let pl = entry.values["packetsLost"] as? NSNumber {
                self.packetsLost = UInt64(truncating: pl)
            }
            else {
                self.packetsLost = nil
            }

            self.packetLossPercent = calculatePacketLoss()
            
            var totalInterFrameDelay: Double?
            if let tifd = entry.values["totalInterFrameDelay"] as? NSNumber {
                totalInterFrameDelay = Double(truncating: tifd)
            }
            var framesDecoded: UInt64?
            if let fd = entry.values["framesDecoded"] as? NSNumber {
                framesDecoded = UInt64(truncating: fd)
            }
            
            if totalInterFrameDelay != nil, framesDecoded != nil {
                averageFps = calculateAverageFps(
                    totalInterFrameDelay: totalInterFrameDelay!,
                    framesDecoded: framesDecoded!
                )
            }
            
            // Difference against the previous sample of the *same* kind: measuring the audio entry
            // against the video byte count (and vice versa) yields a meaningless bitrate
            let previousBytesReceived = kind == "audio" ? previousState?.audioBytesReceived : previousState?
                .videoBytesReceived
            if let previousState, let previousBytesReceived, let bytesTotal {
                bitrate = calculateBitrate(
                    previousTimestamp: previousState.timestampUs,
                    previousBytes: previousBytesReceived,
                    currentTimestamp: timestamp,
                    currentBytes: bytesTotal
                )
            }

            if kind == "audio" {
                self.audioPlayout = AudioPlayout(entry, previous: previousState?.audioPlayout)
            }
        }

        override public func getShortRepresentation() -> String {
            let playout = audioPlayout?.getShortRepresentation() ?? ""
            guard !playout.isEmpty else {
                return super.getShortRepresentation()
            }
            return "\(super.getShortRepresentation()) \(playout)"
        }

        private func calculatePacketLoss() -> Float64? {
            if packetsTotal == nil || packetsLost == nil {
                return nil
            }
            
            if packetsLost! > UInt64(0) {
                return Float64(packetsLost!) / Float64(packetsTotal!) * Float64(100)
            }
            else {
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
    
    final class OutboundRtp: Rtp {
        public init(
            _ entry: RTCStatistics,
            codecs: [String: Codec],
            previousState: VoIPStatsState?,
            timestamp: CFTimeInterval
        ) {
            super.init(entry, codecs: codecs)
            
            if let pt = entry.values["packetsSent"] as? NSNumber {
                self.packetsTotal = UInt64(truncating: pt)
            }
            else {
                self.packetsTotal = nil
            }
            
            if let bt = entry.values["bytesSent"] as? NSNumber {
                self.bytesTotal = UInt64(truncating: bt)
            }
            else {
                self.bytesTotal = nil
            }
            
            self.qualityLimitationReason = entry.values["qualityLimitationReason"] as? String
            
            if let qlrc = entry.values["qualityLimitationResolutionChanges"] as? NSNumber {
                self.qualityLimitationResolutionChanges = UInt64(truncating: qlrc)
            }
            else {
                self.qualityLimitationResolutionChanges = nil
            }

            self.implementation = entry.values["encoderImplementation"] as? String

            // Same-kind differencing as in `InboundRtp`
            let previousBytesSent = kind == "audio" ? previousState?.audioBytesSent : previousState?.videoBytesSent
            if let previousState, let previousBytesSent, let bytesTotal {
                bitrate = calculateBitrate(
                    previousTimestamp: previousState.timestampUs,
                    previousBytes: previousBytesSent,
                    currentTimestamp: timestamp,
                    currentBytes: bytesTotal
                )
            }
        }
    }
    
    final class Track: VoIPStatsRepresentation {
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
            }
            else {
                self.frameWidth = nil
            }
            
            if let fh = entry.values["frameHeight"] as? NSNumber {
                self.frameHeight = UInt64(truncating: fh)
            }
            else {
                self.frameHeight = nil
            }
            
            if let fc = entry.values["freezeCount"] as? NSNumber {
                self.freezeCount = UInt64(truncating: fc)
            }
            else {
                self.freezeCount = nil
            }
            
            if let pc = entry.values["pauseCount"] as? NSNumber {
                self.pauseCount = UInt64(truncating: pc)
            }
            else {
                self.pauseCount = nil
            }
            
            if let e = entry.values["ended"] as? NSNumber {
                self.ended = Bool(truncating: e)
            }
            else {
                self.ended = nil
            }
            
            if let rs = entry.values["remoteSource"] as? NSNumber {
                self.remoteSource = Bool(truncating: rs)
            }
            else {
                self.remoteSource = nil
            }
            
            if let tfr = entry.values["framesReceived"] as? NSNumber {
                self.totalFramesReceived = UInt64(truncating: tfr)
            }
            else {
                self.totalFramesReceived = nil
            }
            
            if let d = entry.values["detached"] as? NSNumber {
                self.detached = Bool(truncating: d)
            }
            else {
                self.detached = nil
            }
        }
               
        public func getShortRepresentation() -> String {
            var result = "\(kind)"
            if frameWidth != nil, frameHeight != nil {
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
            getShortRepresentation()
        }
        
        public func areFramesReceived() -> Bool {
            if kind == "video" {
                if totalFramesReceived != nil, ended != nil, remoteSource != nil, totalFramesReceived! > UInt64(0),
                   ended == false, remoteSource == true {
                    return true
                }
            }
            return false
        }
    }
    
    final class RtpTransceiver: VoIPStatsRepresentation {
        
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
                }
                else {
                    plain += 1
                }
            }
            
            result += "#exts=\(encrypted)e/\(plain)p, "
            
            // Add codecs
            result += "cs="
            if !parameters.codecs.isEmpty {
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
            }
            else {
                result += "?"
            }
            
            return result
        }
        
        private func addParametersRepresentation(_ parameters: RTCRtpParameters) -> String {
            var result = ""
            
            // Add codecs
            result += "\n    Codecs (\(parameters.codecs.count))"
            if !parameters.codecs.isEmpty {
                for (_, codec) in parameters.codecs.enumerated() {
                    // add codec
                    result += "\n    - name=\(codec.name), clock-rate=\(shortClockRate(codec: codec))"
                    
                    if let numChannels = codec.numChannels {
                        result += ", #channels=\(numChannels)"
                    }
                    
                    // Add codec attributes
                    result += ", attributes="
                    for (key, value) in codec.parameters {
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
                }
                else {
                    plain += 1
                }
            }
            
            result += "\n    Header Extensions (\(encrypted)e/\(plain)p)\(extensionResult)"

            return result
        }
        
        private func mediaType() -> String {
            switch transceiver.mediaType {
            case .audio:
                "audio"
            case .video:
                "video"
            default:
                "?"
            }
        }
        
        private func direction() -> String {
            switch transceiver.direction {
            case .sendRecv:
                "send/recv"
            case .sendOnly:
                "send"
            case .recvOnly:
                "recv"
            case .inactive:
                "inactive"
            default:
                "?"
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
    
    final class RoundTripTime: VoIPStatsRepresentation {
        private let latest: Double?
        private var average: Double?
        
        public init(_ entry: RTCStatistics) {
            if let latestNumber = entry.values["currentRoundTripTime"] as? NSNumber {
                self.latest = Double(truncating: latestNumber)
            }
            else {
                self.latest = nil
            }
            
            self.average = nil
            let totalRoundTripTime = entry.values["totalRoundTripTime"] as? NSNumber
            let responsesReceived = entry.values["responsesReceived"] as? NSNumber
                        
            if totalRoundTripTime != nil, responsesReceived != nil {
                if UInt64(truncating: responsesReceived!).signum() == 1 {
                    let t = Decimal(Double(truncating: totalRoundTripTime!))
                    let r = Decimal(UInt64(truncating: responsesReceived!))
                    let av = NSDecimalNumber(decimal: t / r)
                    self.average = Double(truncating: av)
                }
            }
        }
        
        public func getShortRepresentation() -> String {
            var result = "rtt-latest="
            if latest != nil {
                result += "\(String(format: "%.3f", latest!))"
            }
            else {
                result += "n/a"
            }
            
            result += " rtt-avg="
            if average != nil {
                result += "\(String(format: "%.3f", average!))"
            }
            else {
                result += "n/a"
            }
            
            return result
        }
        
        public func getRepresentation() -> String {
            getShortRepresentation()
        }
    }
    
    final class Transport: VoIPStatsRepresentation {
        public let selectedCandidatePairID: String
        private let bytesTransferred: BytesTransferred
        private let dtlsState: String
        
        public init(_ entry: RTCStatistics) {
            if let candidatePairIDString = entry.values["selectedCandidatePairId"] as? String {
                self.selectedCandidatePairID = candidatePairID(statsID: candidatePairIDString)
            }
            else {
                self.selectedCandidatePairID = "???"
            }
            
            self.bytesTransferred = BytesTransferred(entry)
            self.dtlsState = entry.values["dtlsState"] as? String ?? "n/a"
        }
        
        public func getShortRepresentation() -> String {
            "dtls=\(dtlsState) \(bytesTransferred.getShortRepresentation())"
        }
        
        public func getRepresentation() -> String {
            "dtls-state=\(dtlsState), selected-candidate-pair-id=\(selectedCandidatePairID), \(bytesTransferred.getRepresentation())"
        }
    }
    
    final class Crypto: VoIPStatsRepresentation {
        private let dtlsVersion: String
        private let dtlsCipher: String
        private let srtpCipher: String
        
        public init(_ entry: RTCStatistics) {
            self.dtlsVersion = VoIPStats.Crypto
                .dtlsVersionString(dtlsVersionBytes: entry.values["tlsVersion"] as? String)
            self.dtlsCipher = entry.values["dtlsCipher"] as? String ?? "?"
            self.srtpCipher = entry.values["srtpCipher"] as? String ?? "?"
        }
        
        private static func dtlsVersionString(dtlsVersionBytes: String?) -> String {
            if dtlsVersionBytes == nil {
                return "?"
            }
            switch dtlsVersionBytes {
            case "FEFF":
                return "1.0"
            case "FEFD":
                return "1.2"
            default:
                return "?"
            }
        }

        public func getShortRepresentation() -> String {
            "dtls=v\(dtlsVersion):\(dtlsCipher) srtp=\(srtpCipher)"
        }
        
        public func getRepresentation() -> String {
            "dtls-version=\(dtlsVersion), dtls-cipher=\(dtlsCipher), srtp-cipher=\(srtpCipher)"
        }
    }
    
    public init(
        report: RTCStatisticsReport,
        options: VoIPStatsOptions,
        transceivers: [RTCRtpTransceiver],
        previousState: VoIPStatsState?
    ) {
        self.report = report
        self.options = options
        self.transceivers = transceivers
        self.previousState = previousState
        self.timestamp = report.timestamp_us

        extract()
    }

    // O(n^2) but could be optimised for O(n) if needed
    func extract() {
        if options.candidatePairsFlag != CandidatePairVariant.NONE {
            candidatePairs = [CandidatePair]()
        }

        // Codecs are collected in their own pass, for two reasons. `report.statistics` is a
        // dictionary, so a `codec` entry can be visited *after* the `inbound-rtp`/`outbound-rtp`
        // entry that references it, and `Rtp` copies the dictionary it is handed — a codec
        // collected later would never become visible to it. And each RTP entry names its own codec
        // via `codecId`, so splitting the codecs by direction up front was never necessary: it was
        // done by matching "Inbound" in the stats ID, which this WebRTC version never emits, so
        // the inbound table was always empty and every inbound line reported `codec=?`.
        var codecs = [String: Codec]()
        for entry in report.statistics.values where entry.type == "codec" {
            codecs[entry.id] = Codec(entry)
        }
        self.codecs = codecs

        // Extract values
        for entry in report.statistics.values {
            switch entry.type {
            case "candidate-pair":
                if options.candidatePairsFlag != .NONE {
                    candidatePairs!.append(CandidatePair(entry, report: report))
                }
                
            case "inbound-rtp":
                if options.inboundRtp {
                    let kind = entry.values["kind"] as? String
                    if kind == "audio" {
                        inboundRtpAudio = InboundRtp(
                            entry,
                            codecs: codecs,
                            previousState: previousState,
                            timestamp: timestamp
                        )
                    }
                    else if kind == "video" {
                        inboundRtpVideo = InboundRtp(
                            entry,
                            codecs: codecs,
                            previousState: previousState,
                            timestamp: timestamp
                        )
                    }
                }
                
            case "media-source":
                if options.outboundRtp, entry.values["kind"] as? String == "audio" {
                    micAudioLevel = entry.values["audioLevel"] as? Double
                }
                
            case "outbound-rtp":
                if options.outboundRtp {
                    let kind = entry.values["kind"] as? String
                    if kind == "audio" {
                        outboundRtpAudio = OutboundRtp(
                            entry,
                            codecs: codecs,
                            previousState: previousState,
                            timestamp: timestamp
                        )
                    }
                    else if kind == "video" {
                        outboundRtpVideo = OutboundRtp(
                            entry,
                            codecs: codecs,
                            previousState: previousState,
                            timestamp: timestamp
                        )
                    }
                }
                
            case "track":
                if options.tracks {
                    let kind = entry.values["kind"] as? String
                    let inbound = entry.values["remoteSource"] as? NSNumber
                    if kind == "video", inbound != nil {
                        if inbound!.boolValue {
                            inboundTrackVideo = Track(entry)
                        }
                        else {
                            outboundTrackVideo = Track(entry)
                        }
                    }
                }
                if options.framesReceived {
                    let kind = entry.values["kind"] as? String
                    let inbound = entry.values["remoteSource"] as? NSNumber
                    if kind == "video",
                       let inbound, inbound.boolValue {
                        let track = Track(entry)
                        if track.totalFramesReceived != nil, track.areFramesReceived() {
                            if totalFramesReceived == nil {
                                totalFramesReceived = track.totalFramesReceived
                            }
                            else {
                                totalFramesReceived! += track.totalFramesReceived!
                            }
                        }
                    }
                }
                
            case "transport":
                if options.transport {
                    transport = Transport(entry)
                }
                if options.crypto {
                    crypto = Crypto(entry)
                }
                if !options.selectedCandidatePair {
                    break
                }
                
                if let candidatePairIDString = entry.values["selectedCandidatePairId"] as? String {
                    if let candidatePair = CandidatePair.fromID(candidatePairIDString, report: report) {
                        selectedCandidatePair = candidatePair
                    }
                }
                
            default:
                break // Ignore
            }
        }
        
        // Sort candidate pairs by priority
        if let candidatePairs {
            self.candidatePairs = candidatePairs.sorted(by: { $0.priority > $1.priority })
        }
        
        // Add transceivers (if any)
        rtpTransceivers = [RtpTransceiver]()
        for transceiver in transceivers {
            rtpTransceivers?.append(RtpTransceiver(transceiver))
        }
    }
    
    public func getShortRepresentation() -> String {
        var result = ""
        if let transport, options.transport {
            result += "\(transport.getShortRepresentation())\n"
        }
        if let crypto, options.crypto {
            result += "\(crypto.getShortRepresentation())\n"
        }
        if let candidatePairs,
           options.candidatePairsFlag.rawValue & CandidatePairVariant.OVERVIEW.rawValue != 0 {
            result += "pairs(\(candidatePairs.count))=\(candidatePairs.map { $0.getStatusChar() }.joined())\n"
        }
        if let selectedCandidatePair {
            result += "\(selectedCandidatePair.getShortRepresentation())\n"
        }
        result += "\n"
        
        if let inboundRtpAudio {
            result += "in: \(inboundRtpAudio.getShortRepresentation())\n"
        }
        if let inboundRtpVideo {
            result += "in: \(inboundRtpVideo.getShortRepresentation())\n"
        }
        if let outboundRtpAudio {
            result += "out: \(outboundRtpAudio.getShortRepresentation())\n"
        }
        if let outboundRtpVideo {
            result += "out: \(outboundRtpVideo.getShortRepresentation())\n"
        }
        result += "\n"
        
        if let inboundTrackVideo {
            result += "in/track- \(inboundTrackVideo.getShortRepresentation())\n"
        }
        if let outboundTrackVideo {
            result += "out/track- \(outboundTrackVideo.getShortRepresentation())\n"
        }

        if options.codecs, codecs != nil {
            result += "codecs "
            for (direction, codec) in describedCodecs() {
                result += "\(direction):\(codec.getShortRepresentation())"
                result += " "
            }
            result += "\n"
        }
        
        if let rtpTransceivers {
            result += "\n"
            for transceiver in rtpTransceivers {
                result += "transceiver \(transceiver.getShortRepresentation())\n"
            }
            result += "\n"
        }
        
        if let candidatePairs,
           options.candidatePairsFlag.rawValue & CandidatePairVariant.DETAILED.rawValue != 0 {
            result += "\(candidatePairs.map { $0.getShortRepresentation() }.joined(separator: "\n"))\n"
        }
        
        // Strip newline (if any)
        result.removeLast(1)
        return result
    }
    
    public func getRepresentation() -> String {
        var result = ""
        if let transport {
            result += "Transport: \(transport.getRepresentation())\n"
        }
        if let crypto {
            result += "Crypto: \(crypto.getRepresentation())\n"
        }
        if let candidatePairs,
           options.candidatePairsFlag.rawValue & CandidatePairVariant.OVERVIEW.rawValue != 0 {
            result +=
                "Candidate Pairs Overview (\(candidatePairs.count)): \(candidatePairs.map { $0.getStatusChar() }.joined())\n"
        }
        if let selectedCandidatePair {
            result += "Selected Candidate Pair: \(selectedCandidatePair.getRepresentation())\n"
        }
        if let inboundRtpAudio {
            result += "Inbound RTP Audio: \(inboundRtpAudio.getRepresentation())\n"
        }
        if let inboundRtpVideo {
            result += "Inbound RTP Video: \(inboundRtpVideo.getRepresentation())\n"
        }
        if let outboundRtpAudio {
            var line = outboundRtpAudio.getRepresentation()
            line += " mic=\(micAudioLevel.map(AudioPlayout.levelBucket) ?? "?")"
            result += "Outbound RTP Audio: \(line)\n"
        }
        if let outboundRtpVideo {
            result += "Outbound RTP Video: \(outboundRtpVideo.getRepresentation())\n"
        }
        if let inboundTrackVideo {
            result += "Inbound Track Video: \(inboundTrackVideo.getRepresentation())\n"
        }
        if let outboundTrackVideo {
            result += "Outbound Track Video: \(outboundTrackVideo.getRepresentation())\n"
        }
        if let codecs {
            result += "Codecs (\(codecs.count))\n"
            for (direction, codec) in describedCodecs() {
                result += "- \(direction) \(codec.getShortRepresentation())\n"
            }
        }
        if let rtpTransceivers {
            result += "Transceivers (\(rtpTransceivers.count))\n"
            for transceiver in rtpTransceivers {
                result += "- \(transceiver.getRepresentation())"
            }
            result += "\n"
        }
        if let candidatePairs,
           options.candidatePairsFlag.rawValue & CandidatePairVariant.DETAILED.rawValue != 0 {
            result += "Candidate Pairs (\(candidatePairs.count))\n"
            result += candidatePairs.map { "- \($0.getRepresentation())\n" }.joined()
        }
        
        // Strip newline (if any)
        result.removeLast(1)
        return result
    }
    
    /// Which direction a codec entry is used in
    ///
    /// A `codec` entry carries no direction of its own — the relationship exists only as the
    /// `codecId` pointer *from* each `inbound-rtp`/`outbound-rtp` entry *to* the codec it uses. So
    /// the label is read back off those pointers rather than guessed from the codec's stats ID,
    /// which is what the old `contains("Inbound")` classification got wrong.
    ///
    /// `?` means the codec was negotiated but no extracted RTP entry references it — including the
    /// case where `options.inboundRtp`/`outboundRtp` were off, so there is nothing to read from.
    private func codecDirectionLabel(for codecID: String) -> String {
        let isInbound = codecID == inboundRtpAudio?.codecID || codecID == inboundRtpVideo?.codecID
        let isOutbound = codecID == outboundRtpAudio?.codecID || codecID == outboundRtpVideo?.codecID

        return switch (isInbound, isOutbound) {
        case (true, false):
            "in"
        case (false, true):
            "out"
        case (true, true):
            "in/out"
        case (false, false):
            "?"
        }
    }

    /// Codecs paired with the direction they are used in, ordered so the log is stable between
    /// samples (`codecs` is a dictionary, so its own iteration order is not)
    private func describedCodecs() -> [(direction: String, codec: Codec)] {
        guard let codecs else {
            return []
        }

        return codecs
            .map { (direction: codecDirectionLabel(for: $0.key), codec: $0.value) }
            .sorted { ($0.direction, $0.codec.getShortRepresentation()) <
                ($1.direction, $1.codec.getShortRepresentation())
            }
    }

    public func isReceivingVideo() -> Bool {
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
        if selectedCandidatePair != nil, selectedCandidatePair!.usesRelay {
            return true
        }
        return false
    }
        
    func buildVoIPStatsState() -> VoIPStatsState {
        VoIPStatsState(
            timestampUs: timestamp,
            audioBytesSent: outboundRtpAudio?.bytesTotal,
            audioBytesReceived: inboundRtpAudio?.bytesTotal,
            videoBytesSent: outboundRtpVideo?.bytesTotal,
            videoBytesReceived: inboundRtpVideo?.bytesTotal,
            videoFramesReceived: totalFramesReceived,
            audioPlayout: inboundRtpAudio?.audioPlayout
        )
    }
}

struct VoIPStatsState {
    let timestampUs: Double
    let audioBytesSent: UInt64?
    let audioBytesReceived: UInt64?
    let videoBytesSent: UInt64?
    let videoBytesReceived: UInt64?
    let videoFramesReceived: UInt64?

    /// Cumulative playout counters of this sample, so the next one can difference against them
    let audioPlayout: VoIPStats.AudioPlayout?
}

// Convert byte count into human readable number
// Based on: https://stackoverflow.com/a/3758880
func toHumanReadableByteCount(_ value: UInt64) -> String {
    let unit: UInt64 = 1024
    if value < unit {
        return "\(value)B"
    }
    else {
        let value = Double(value)
        let unit = Double(unit)
        let exp = (log(value) / log(unit)).binade
        return "\(String(format: "%.1f", value / pow(unit, exp)))\("KMGTPE"[Int(exp - 1)])iB"
    }
}

// Convert ms to seconds
func msToSeconds(_ value: String?) -> String {
    guard let value = Double(value) else {
        return "n/a"
    }
    return String(format: "%.3f", value / 1000)
}

func msToSeconds(_ value: Double?) -> String {
    guard value != nil else {
        return "n/a"
    }
    return String(format: "%.3f", value! / 1000)
}

// Calculate a fraction
func toFraction(_ dividend: String?, divisor: String?) -> String {
    guard let dividend = Double(dividend), let divisor = Double(divisor), divisor > 0 else {
        return "n/a"
    }
    return String(format: "%.1f", dividend / divisor)
}

func candidatePairID(statsID: String?) -> String {
    if statsID == nil {
        return "???"
    }
    let substring = String(statsID!.dropFirst(20))
    if !substring.isEmpty {
        return substring
    }
    return "???"
}

func calculateBitrate(
    previousTimestamp: Double,
    previousBytes: UInt64,
    currentTimestamp: Double,
    currentBytes: UInt64
) -> Double? {
    let microSecondsElapsed = currentTimestamp - previousTimestamp

    if microSecondsElapsed < 0 {
        debugPrint("Previous state must not have a higher timestamp than current state")
        return nil
    }
    if microSecondsElapsed < 100_000 {
        debugPrint("State timestamps should be at least 100ms apart")
        return nil
    }
    // `previous.distance(to: current)`, not the reverse: `Strideable.distance(to:)` returns
    // `other - self`, so the operands being swapped here reported every bitrate negated
    guard let bytesTransferred = cumulativeDelta(currentBytes, previousBytes) else {
        return nil
    }
    return (8 * Double(bytesTransferred)) / (microSecondsElapsed / 1000 / 1000)
}

/// Difference two samples of a counter that only ever grows
///
/// Returns `nil` rather than wrapping around when the counter went backwards, which happens when
/// the underlying stream is replaced mid-call and the counters restart at zero.
func cumulativeDelta(_ current: UInt64?, _ previous: UInt64?) -> UInt64? {
    guard let current, let previous, current >= previous else {
        return nil
    }
    return current - previous
}

func cumulativeDelta(_ current: Double?, _ previous: Double?) -> Double? {
    guard let current, let previous, current >= previous else {
        return nil
    }
    return current - previous
}

extension RTCStatistics {
    fileprivate func doubleValue(_ key: String) -> Double? {
        guard let number = values[key] as? NSNumber else {
            return nil
        }
        return Double(truncating: number)
    }

    fileprivate func uInt64Value(_ key: String) -> UInt64? {
        guard let number = values[key] as? NSNumber else {
            return nil
        }
        return UInt64(truncating: number)
    }
}
