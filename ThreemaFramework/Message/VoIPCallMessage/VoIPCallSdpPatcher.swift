import CocoaLumberjackSwift
import Foundation

public final class VoIPCallSdpPatcher: NSObject {
    static let SDP_MEDIA_AUDIO_ANY_RE = "m=audio ([^ ]+) ([^ ]+) (.+)"
    static let SDP_RTPMAP_OPUS_RE = "a=rtpmap:([^ ]+) opus.*"
    static let SDP_RTPMAP_ANY_RE = "a=rtpmap:([^ ]+) .*"
    static let SDP_FMTP_ANY_RE = "a=fmtp:([^ ]+) ([^ ]+)"
    static let SDP_EXTMAP_ANY_RE = "a=extmap:[^ ]+ (.*)"
    
    public convenience init(_ config: RtpHeaderExtensionConfig) {
        self.init()
        self.rtpHeaderExtensionConfig = config
    }
    
    /// Whether this SDP is a local offer, a local answer or a remote SDP.
    public enum SdpType {
        case REMOTE_OFFER
        case REMOTE_ANSWER
        case LOCAL_OFFER
        case LOCAL_ANSWER
    }
    
    /// RTP header extension configuration.
    public enum RtpHeaderExtensionConfig {
        case DISABLE
        case ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY
        case ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER
    }
    
    public enum SdpErrorType: Error, Equatable {
        case invalidSdp
        case illegalArgument
        case matchesError
        case unknownSection
    }
    
    enum SdpSection: String {
        case GLOBAL
        case MEDIA_AUDIO
        case MEDIA_VIDEO
        case MEDIA_DATA_CHANNEL
        case MEDIA_UNKNOWN
        
        func isRtpSection() -> Bool {
            switch self {
            case .GLOBAL, .MEDIA_DATA_CHANNEL, .MEDIA_UNKNOWN:
                false
            case .MEDIA_AUDIO, .MEDIA_VIDEO:
                true
            }
        }
    }
    
    enum LineAction {
        case ACCEPT
        case REJECT
        case REWRITE
    }

    public final class SdpError: Error {
        var type: SdpErrorType
        var description: String
        public init(type: SdpErrorType, description: String) {
            self.type = type
            self.description = description
        }

        var errorDescription: String? {
            description
        }
    }

    var rtpExtensionsInRemoteOffer = RtpExtensionReplayer()

    private var rtpHeaderExtensionConfig: RtpHeaderExtensionConfig = .DISABLE
    
    struct SdpPatcherContext {
        var type: SdpType
        var config: VoIPCallSdpPatcher
        var payloadTypeOpus: String
        var rtpExtensionsInLocalOfferIDRemapper: RtpExtensionIDRemapper
        var section: SdpSection
        
        init(type: SdpType, config: VoIPCallSdpPatcher, payloadTypeOpus: String) {
            self.type = type
            self.config = config
            self.payloadTypeOpus = payloadTypeOpus
            self.rtpExtensionsInLocalOfferIDRemapper = RtpExtensionIDRemapper(config: config)
            self.section = SdpSection.GLOBAL
        }
    }
    
    struct Line {
        private(set) var line: String
        private var action: LineAction?
        
        init(line: String) {
            self.line = line
        }
                
        mutating func accept() throws -> LineAction {
            if action != nil {
                throw SdpError(type: .illegalArgument, description: "LineAction.action already set")
            }
            action = .ACCEPT
            return action!
        }
        
        mutating func reject() throws -> LineAction {
            if action != nil {
                throw SdpError(type: .illegalArgument, description: "LineAction.action already set")
            }
            action = .REJECT
            return action!
        }
        
        mutating func rewrite(line: String) throws -> LineAction {
            if action != nil {
                throw SdpError(type: .illegalArgument, description: "LineAction.action already set")
            }
            action = .REWRITE
            self.line = line
            return action!
        }
    }

    struct RtpExtensionReplayer {
        enum MediaSection {
            case AUDIO, VIDEO
        }
        
        private static var extensions = [MediaSection: [String]]()
        
        static func mediaSection(fromSdpSection section: SdpSection) -> MediaSection? {
            switch section {
            case .MEDIA_AUDIO:
                .AUDIO
            case .MEDIA_VIDEO:
                .VIDEO
            default:
                nil
            }
        }
        
        mutating func add(section: MediaSection, line: String) {
            if let lines = VoIPCallSdpPatcher.RtpExtensionReplayer.extensions[section] {
                VoIPCallSdpPatcher.RtpExtensionReplayer.extensions[section] = lines + [line]
            }
            else {
                VoIPCallSdpPatcher.RtpExtensionReplayer.extensions[section] = [line]
            }
        }
        
        mutating func replay(section: MediaSection) -> [String] {
            VoIPCallSdpPatcher.RtpExtensionReplayer.extensions.removeValue(forKey: section) ?? []
        }
        
        /// Only use for testing
        static func clearExtensionsForTesting() {
            extensions.removeAll()
        }
    }
    
    struct RtpExtensionIDRemapper {
        private var currentID: Int?
        private var maxID: Int?
        private var extensionIDMap = [String: Int]()
        
        init(config: VoIPCallSdpPatcher) {
            self.currentID = 0
            
            switch config.rtpHeaderExtensionConfig {
            case .ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY:
                self.maxID = 14
            case .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER:
                self.maxID = 255
            default:
                self.maxID = 0
            }
        }
        
        mutating func assignID(uriAndAttributes: String) throws -> Int {
            // It is extremely important that we give extensions with the same URI the same ID
            // across different media sections, otherwise the bundling mechanism will fail and we
            // get all sorts of weird behaviour from the WebRTC stack.
            var id = extensionIDMap[uriAndAttributes]
            if id == nil {
                // Check if exhausted
                currentID! += 1
                if currentID! > maxID! {
                    throw SdpError(type: .invalidSdp, description: "RTP extension IDs exhausted")
                }
                id = currentID
                
                if currentID == 15 {
                    currentID! += 1
                    id! += 1
                }
                
                extensionIDMap[uriAndAttributes] = id
            }
            
            return id!
        }
    }
    
    /// Patch an SDP offer / answer with a few things that we want to enforce in Threema:
    /// For all media lines:
    /// - Remove audio level and frame marking header extensions
    /// - Remap extmap IDs (when offering)
    ///
    /// For audio in specific:
    /// - Only support Opus, remove all other codecs
    /// - Force CBR
    ///
    /// The use of CBR (constant bit rate) will also suppress VAD (voice activity detection). For
    /// more security considerations regarding codec configuration, see RFC 6562:
    /// https://tools.ietf.org/html/rfc6562
    ///
    /// - Parameters:
    ///   - type: Type
    ///   - sdp: String
    /// - Throws: SdpError
    /// - Returns: Updated sdp
    public func patch(type: SdpType, sdp: String) throws -> String {
        var payloadTypeOpus: String?
        
        do {
            let sdpRtpmapOpusRegex = try NSRegularExpression(
                pattern: VoIPCallSdpPatcher.SDP_RTPMAP_OPUS_RE,
                options: []
            )
            let sdpRange = NSRange(sdp.startIndex..<sdp.endIndex, in: sdp)
            if let match = sdpRtpmapOpusRegex.firstMatch(in: sdp, options: [], range: sdpRange) {
                if let sub = sdp.substring(with: match.range(at: 1)) {
                    payloadTypeOpus = String(sub)
                }
            }
            else {
                throw SdpError(type: .invalidSdp, description: "a=rtpmap: [...] opus not found")
            }
            
            var lines = String()
            var context = SdpPatcherContext(type: type, config: self, payloadTypeOpus: payloadTypeOpus!)
            let linesArray = sdp.linesArray
            
            for line in linesArray {
                do {
                    var lineLine = Line(line: line)
                    try handleLine(
                        context: &context,
                        lines: &lines,
                        line: &lineLine,
                        sdpLineArray: linesArray,
                    )
                }
                catch {
                    let sdpError = error as! SdpError
                    switch sdpError.type {
                    case .unknownSection:
                        break
                    default:
                        throw error
                    }
                }
            }
            return lines
        }
        catch {
            throw SdpError(type: .invalidSdp, description: "a=rtpmap: [...] opus not found")
        }
    }
    
    /// Handle an SDP line.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - lines: String
    ///   - lineString: String
    ///   - sdpLineArray: [String]
    ///   - index: Int
    /// - Throws: SdpError
    private func handleLine(
        context: inout SdpPatcherContext,
        lines: inout String,
        line: inout Line,
        sdpLineArray: [String],
    ) throws {
        let current: SdpSection = context.section
        var action: LineAction
        if line.line.starts(with: "m=") {
            action = try handleSectionLine(context: &context, line: &line)
        }
        else {
            switch context.section {
            case .GLOBAL:
                action = try handleGlobalLine(context, &line)
            case .MEDIA_AUDIO:
                action = try handleAudioLine(&context, &line)
            case .MEDIA_VIDEO:
                action = try handleVideoLine(&context, &line)
            case .MEDIA_DATA_CHANNEL:
                action = try handleDataChannelLine(&line)
            default:
                // Note: This also swallows `MEDIA_UNKNOWN`. Since we reject these lines completely,
                //       a line within that section should never be parsed.
                throw SdpError(
                    type: .unknownSection,
                    description: "Unknown section \(current.rawValue)"
                )
            }
        }
        
        // Execute line action
        switch action {
        case .ACCEPT, .REWRITE:
            lines.append(line.line)
            lines.append("\r\n")
        case .REJECT:
            DDLogError("Rejected line: \(line.line)")
        }
        
        // If we have switched to another section and the line has been rejected,
        // we need to reject the remainder of the section.
        if current != context.section, action == .REJECT {

            var debug = ""
            var rejectedLine: String?
            
            for newLine in sdpLineArray {
                if !newLine.starts(with: "m=") {
                    debug.append(newLine)
                    rejectedLine = newLine
                }
                else {
                    break
                }
            }
            
            if !debug.isEmpty {
                DDLogError("Rejected section: \(debug)")
            }
            
            // Since we've already read the beginning of the section and can't push it back to the reader, we need to
            // handle it here.
            if let rejectedLine {
                var line = Line(line: rejectedLine)
                try handleLine(context: &context, lines: &lines, line: &line, sdpLineArray: sdpLineArray)
            }
        }
    }
    
    /// Handle a section line.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    /// - Returns: LineAction
    private func handleSectionLine(context: inout SdpPatcherContext, line: inout Line) throws -> LineAction {
        let lineString = line.line

        // Audio section
        do {
            let sectionRegex = try NSRegularExpression(pattern: VoIPCallSdpPatcher.SDP_MEDIA_AUDIO_ANY_RE, options: [])
            let lineRange = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)
            
            if let match = sectionRegex.firstMatch(in: lineString, options: [], range: lineRange) {
                context.section = .MEDIA_AUDIO
                
                // Parse media description line
                if let port = lineString.substring(with: match.range(at: 1)),
                   let proto = lineString.substring(with: match.range(at: 2)),
                   let payloadTypes = lineString.substring(with: match.range(at: 3)) {
                    
                    // Make sure that the Opus payload type is contained here
                    if !String(payloadTypes).split(separator: " ").map(String.init).contains(context.payloadTypeOpus) {
                        throw SdpError(
                            type: .invalidSdp,
                            description: String
                                .localizedStringWithFormat(
                                    "Opus payload type (%@) not found in audio media description",
                                    context.payloadTypeOpus
                                )
                        )
                    }
                    let newString = String(
                        format: "m=audio %@ %@ %@",
                        String(port),
                        String(proto),
                        context.payloadTypeOpus
                    )
                    return try line.rewrite(line: newString)
                }
            }
            
            // Video section
            if lineString.starts(with: "m=video") {
                // Accept
                context.section = SdpSection.MEDIA_VIDEO
                return try line.accept()
            }
        
            // Data channel section
            if lineString.starts(with: "m=application"), lineString.contains("DTLS/SCTP") {
                // Accept
                context.section = SdpSection.MEDIA_DATA_CHANNEL
                return try line.accept()
            }
            
            // unknown section (reject)
            context.section = SdpSection.MEDIA_UNKNOWN
            return try line.reject()
        }
        catch {
            throw SdpError(type: .matchesError, description: "SDP_MEDIA_AUDIO_ANY_RE error")
        }
    }
    
    /// Handle global (non-media) section line.
    /// - Returns: LineAction
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    private func handleGlobalLine(_ context: SdpPatcherContext, _ line: inout Line) throws -> LineAction {
        try handleRtpAttributes(context, &line)
    }
    
    // Handle RTP attributes shared across global (non-media) and media sections.
    /// - Returns: LineAction
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    private func handleRtpAttributes(_ context: SdpPatcherContext, _ line: inout Line) throws -> LineAction {
        let lineString = line.line
        
        // Reject one-/two-byte RTP header mixed mode, if requested
        if context.config.rtpHeaderExtensionConfig != .ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER,
           lineString.starts(with: "a=extmap-allow-mixed") {
            return try line.reject()
        }
        
        // Accept the rest
        return try line.accept()
    }
    
    /// Handle audio section line.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    /// - Returns: LineAction
    private func handleAudioLine(_ context: inout SdpPatcherContext, _ line: inout Line) throws -> LineAction {
        let lineString = line.line
        let lineRange = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)
        
        // RTP mappings
        let rtpMappingRegex = try NSRegularExpression(pattern: VoIPCallSdpPatcher.SDP_RTPMAP_ANY_RE, options: [])
        if let match = rtpMappingRegex.firstMatch(in: lineString, options: [], range: lineRange) {
            if let payloadType = lineString.substring(with: match.range(at: 1)) {
                if payloadType == context.payloadTypeOpus {
                    return try line.accept()
                }
                else {
                    return try line.reject()
                }
            }
        }
        
        // RTP format parameters
        let rtpFormatParametersRegex = try NSRegularExpression(pattern: VoIPCallSdpPatcher.SDP_FMTP_ANY_RE, options: [])
        if let match = rtpFormatParametersRegex.firstMatch(in: lineString, options: [], range: lineRange) {
            guard let payloadType = lineString.substring(with: match.range(at: 1)) else {
                return try line.reject()
            }
            let paramString = lineString.substring(with: match.range(at: 2))
            if payloadType != context.payloadTypeOpus {
                return try line.reject()
            }
            
            // Split parameters
            let params = paramString?.split(separator: ";")
            
            // Specify what params we want to change
            let paramUpdates = ["stereo", "sprop-stereo", "cbr"]
            
            // Write unchanged params
            var builder = String()
            builder.append("a=fmtp:")
            builder.append(context.payloadTypeOpus)
            builder.append(" ")
            for param in params! {
                if let key = param.split(separator: "=").first, !param.isEmpty, !paramUpdates.contains(String(key)) {
                    builder.append(contentsOf: param)
                    builder.append(";")
                }
            }
            
            // Write our custom params
            builder.append("stereo=0;sprop-stereo=0;cbr=1")
            
            return try line.rewrite(line: builder)
        }
        
        // For local answers, inject the accepted remote offer RTP header extensions after the MID in a hacky ugly AF
        // way
        if context.type == .LOCAL_ANSWER, line.line.hasPrefix("a=mid:") {
            return VoIPCallSdpPatcher.handleRtpHeaderExtensionInjectionAfterMid(context: context, line: &line)
        }
        
        // Handle RTP header extensions
        let rtpHeaderExtensionsRegex = try NSRegularExpression(
            pattern: VoIPCallSdpPatcher.SDP_EXTMAP_ANY_RE,
            options: []
        )
        if let match = rtpHeaderExtensionsRegex.firstMatch(in: lineString, options: [], range: lineRange) {
            let uriAndAttributes = lineString.substring(with: match.range(at: 1))
            return try handleRtpHeaderExtensionLine(&context, &line, String(uriAndAttributes!))
        }
    
        // Handle further common cases
        return try handleRtpAttributes(context, &line)
    }
    
    /// Handle video section line.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    /// - Returns: LineAction
    private func handleVideoLine(_ context: inout SdpPatcherContext, _ line: inout Line) throws -> LineAction {
        let lineString = line.line
        let lineRange = NSRange(lineString.startIndex..<lineString.endIndex, in: lineString)
        
        // For local answers, inject the accepted remote offer RTP header extensions after the MID in a hacky ugly AF
        // way
        if context.type == .LOCAL_ANSWER, line.line.hasPrefix("a=mid:") {
            return VoIPCallSdpPatcher.handleRtpHeaderExtensionInjectionAfterMid(context: context, line: &line)
        }
        
        // Handle RTP header extensions
        let rtpHeaderExtensionRegex = try NSRegularExpression(
            pattern: VoIPCallSdpPatcher.SDP_EXTMAP_ANY_RE,
            options: []
        )
        if let match = rtpHeaderExtensionRegex.firstMatch(in: lineString, options: [], range: lineRange) {
            let uriAndAttributes = lineString.substring(with: match.range(at: 1))
            return try handleRtpHeaderExtensionLine(&context, &line, String(uriAndAttributes!))
        }
        
        // Handle further common cases
        return try handleRtpAttributes(context, &line)
    }
    
    /// Handle data channel section line.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    /// - Throws: SdpError
    /// - Returns: LineAction
    private func handleDataChannelLine(_ line: inout Line) throws -> LineAction {
        try line.accept()
    }
    
    /// Handle Rtp header extensions.
    /// - Parameters:
    ///   - context: SdpPatcherContext
    ///   - line: Line
    ///   - uriAndAttributes: String
    /// - Throws: SdpError
    /// - Returns: LineAction
    private func handleRtpHeaderExtensionLine(
        _ context: inout SdpPatcherContext,
        _ line: inout Line,
        _ uriAndAttributes: String
    ) throws -> LineAction {
        // Always reject if disabled
        if context.config.rtpHeaderExtensionConfig == .DISABLE {
            return try line.reject()
        }

        // Always reject some of the header extensions
        if uriAndAttributes
            .contains("urn:ietf:params:rtp-hdrext:ssrc-audio-level") ||
            // Audio level, only useful for SFU use cases, remove
            uriAndAttributes.contains("urn:ietf:params:rtp-hdrext:csrc-audio-level") ||
            uriAndAttributes
            .contains("http://tools.ietf.org/html/draft-ietf-avtext-framemarking-07") {
            // Frame marking, only useful for SFU use cases, remove
            return try line.reject()
        }
        
        switch context.type {
        // Only allow encrypted extensions and remember them so they can be copied into the local answer
        case .REMOTE_OFFER:
            guard uriAndAttributes.starts(with: "urn:ietf:params:rtp-hdrext:encrypt") else {
                return try line.reject()
            }
            if let mediaSection = RtpExtensionReplayer.mediaSection(fromSdpSection: context.section) {
                context.config.rtpExtensionsInRemoteOffer.add(section: mediaSection, line: line.line)
            }
            return try line.accept()
            
        case .REMOTE_ANSWER:
            guard uriAndAttributes.starts(with: "urn:ietf:params:rtp-hdrext:encrypt") else {
                return try line.reject()
            }
            return try line.accept()
            
        case .LOCAL_OFFER:
            if uriAndAttributes.starts(with: "urn:ietf:params:rtp-hdrext:encrypt") {
                // We don't expect any encrypted extensions since they are no longer generated
                // by default. Not having to handle duplicates makes this code simpler.
                return try line.reject()
            }
            return try line.rewrite(line: String(
                format: "a=extmap:%d urn:ietf:params:rtp-hdrext:encrypt %@",
                context.rtpExtensionsInLocalOfferIDRemapper.assignID(uriAndAttributes: uriAndAttributes),
                uriAndAttributes
            ))
        
        // We don't expect any extensions since all encrypted header extensions are stripped by the SDP engine, because
        // Google decided so.
        case .LOCAL_ANSWER:
            return try line.reject()
        }
    }
    
    private static func handleRtpHeaderExtensionInjectionAfterMid(
        context: SdpPatcherContext,
        line: inout Line
    ) -> LineAction {
        guard let mediaSection = RtpExtensionReplayer.mediaSection(fromSdpSection: context.section) else {
            return try! line.accept()
        }
        
        var replayedExtensions = context.config.rtpExtensionsInRemoteOffer.replay(section: mediaSection)
        replayedExtensions.insert(line.line, at: 0)
        return try! line.rewrite(line: "\(replayedExtensions.joined(separator: "\r\n"))")
    }
}

extension String {
    public var linesArray: [String] {
        var result: [String] = []
        enumerateLines { line, _ in
            result.append(line)
        }
        return result
    }
}
