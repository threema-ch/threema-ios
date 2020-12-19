//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

import XCTest

@testable import Threema

class SdpPatcherTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
            
    /// If the "cbr" parameter is already contained in the fmtp attribute, it should be updated.
    func testPatchForceCbr() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:111 minptime=10;cbr=0;useinbandfec=1\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// If the fmtp line contains parameters without an '=' sign, nothing should break.
    func testPatchInvalidFmtpLine() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:111 minptime=10;cbr0;useinbandfec=1\r\n" +
            "a=fmtp:1337 cat=yes;duck=no\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:111 minptime=10;cbr0;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// Non-Opus fmtp lines should be dropped.
    func testPatchIgnoreNonOpusFmtpLine() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:1337 cat=yes;duck=no\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// We always require Opus, so it should throw an exception if it's not present.
    func testPatchWithoutOpusAnswer() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 popus/48000/2\r\n" +
            "a=urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=fmtp:111 minptime=10;cbr0;useinbandfec=1\r\n"
        XCTAssertThrowsError(try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// We always require Opus, so it should throw an exception if it's not present.
    func testPatchWithoutOpusOffer() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 popus/48000/2\r\n" +
            "a=urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=fmtp:111 minptime=10;cbr0;useinbandfec=1\r\n"
        
        XCTAssertThrowsError(try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// It should throw an exception if the Opus payload type cannot be found in the RTP map.
    func testPatchWithoutOpusPayloadTypeAnswer() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 1337\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        XCTAssertThrowsError(try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// It should throw an exception if the Opus payload type cannot be found in the RTP map.
    func testPatchWithoutOpusPayloadTypeOffer() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 1337\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        XCTAssertThrowsError(try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// Unknown media sections should be completely stripped.
    func testPatchWithUnknownMedia() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "m=everything in plain text over the wire kthx\r\n" +
            "a=plaintext OH YES YES YES\r\n" +
            "a=moar-plaintext\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=sctp-port:5000\r\n" +
            "m=the-train-protocol\r\n" +
            "a=choo-chooo\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=sctp-port:5000\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// Ensure data channel sections aren't stripped.
    func testPatchWithDataChannelMedia() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=sctp-port:5000\r\n"
        
        XCTAssertEqual(sdp, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: sdp))
        XCTAssertEqual(sdp, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: sdp))
    }
    
    
    /// When RTP header extensions have been disabled, ensure the lines are stripped.
    func testPatchWithNoRtpHeaderExtensions() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-2\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt 5\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt 3\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt 1\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt 7\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt 8\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt 9\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt 11\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt 10\r\n" +
            "a=extmap:12 urn:ietf:params:rtp-hdrext:encrypt 12\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt 15\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt 19\r\n" +
            "a=extmap:1337387126438213678123681273618 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.DISABLE).patch(type: .LOCAL_OFFER, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.DISABLE).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
    }
    
    /// When local offer, in one-byte header mode, RTP header extension IDs should be reassigned in the range from 1-14.
    func testPatchWithRtpOneByteModeHeaderIdsReassigned() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-2\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt 5\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt 3\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt 1\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt 7\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt 8\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt 9\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt 11\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt 10\r\n" +
            "a=extmap:12 urn:ietf:params:rtp-hdrext:encrypt 12\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt 15\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt 19\r\n" +
            "a=extmap:1337387126438213678123681273618 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt 6-1\r\n" +
            "a=extmap:2 urn:ietf:params:rtp-hdrext:encrypt 6-2\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt 5\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:encrypt 3\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt 1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 7\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt 8\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt 9\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt 11\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt 10\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt 12\r\n" +
            "a=extmap:12 urn:ietf:params:rtp-hdrext:encrypt 15\r\n" +
            "a=extmap:13 urn:ietf:params:rtp-hdrext:encrypt 19\r\n" +
            "a=extmap:14 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// When local offer, in one-byte header mode, more than 14 RTP header extensions are not allowed.
    func testPatchWithRtpOneByteModeHeaderMoreThan14Offer() {
        let sdp = "v=0\r\n" +
        "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-2\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt 5\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt 3\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt 1\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt 7\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt 8\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt 9\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt 11\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt 10\r\n" +
            "a=extmap:12 urn:ietf:params:rtp-hdrext:encrypt 12\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt 15\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt 19\r\n" +
            "a=extmap:20 urn:ietf:params:rtp-hdrext:encrypt 20\r\n" +
            "a=extmap:1337387126438213678123681273618 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n"
        
        XCTAssertThrowsError(try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_OFFER, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// When local answer or remote SDP, in one-byte header mode, RTP header extension IDs should not be reassigned and more than 14 header extensions will be accepted, too.
    func testPatchWithRtpOneByteModeHeaderMoreThan14AnswerOrRemote() {
        let sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt 6-2\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt 5\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt 3\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt 1\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt 7\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt 8\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt 9\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt 11\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt 10\r\n" +
            "a=extmap:12 urn:ietf:params:rtp-hdrext:encrypt 12\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt 15\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt 19\r\n" +
            "a=extmap:1337387126438213678123681273618 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n" +
            "a=extmap:1337387126438213678123681273618 urn:ietf:params:rtp-hdrext:encrypt 1337387126438213678123681273618\r\n"
        
        XCTAssertEqual(sdp, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: sdp))
    }
    
    /// When local offer, in two-byte (mixed) header mode, RTP header extension IDs should be reassigned in the range from 1-14 and 16-255.
    func testPatchWithRtpMixedModeHeaderIdsReassigned() {
        var actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        var expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        let ids: [Int] = [134, 68, 14, 95, 97, 64, 66, 89, 143, 82, 51, 53, 145, 172, 91, 64, 144, 107, 241, 37,
                          244, 233, 108, 158, 17, 185, 73, 88, 181, 226, 180, 95, 91, 106, 68, 220, 42, 116, 134,
                          102, 63, 193, 135, 248, 141, 1, 157, 116, 34, 251, 218, 33, 90, 124, 28, 163, 22, 129,
                          73, 234, 138, 93, 224, 220, 150, 6, 56, 55, 112, 112, 210, 189, 150, 202, 197, 74, 176,
                          170, 218, 234, 203, 244, 205, 170, 160, 165, 67, 156, 222, 107, 5, 220, 167, 49, 160,
                          3, 243, 194, 60, 230, 164, 241, 88, 183, 143, 192, 111, 139, 233, 235, 71, 30, 30, 117,
                          188, 245, 230, 92, 37, 82, 119, 236, 250, 2, 123, 188, 243, 196, 220, 177, 172, 105,
                          120, 217, 32, 67, 169, 170, 37, 16, 132, 128, 67, 87, 191, 75, 21, 240, 96, 2, 72, 31,
                          23, 126, 137, 134, 209, 249, 67, 139, 19, 31, 173, 135, 41, 151, 42, 161, 44, 111, 165,
                          193, 243, 216, 248, 89, 251, 140, 97, 18, 22, 47, 108, 50, 35, 188, 186, 212, 43, 80,
                          21, 16, 144, 173, 92, 53, 3, 162, 126, 208, 117, 160, 238, 140, 4, 87, 227, 231, 49,
                          82, 235, 156, 1, 99, 30, 154, 178, 45, 92, 246, 148, 100, 218, 27, 146, 193, 81, 179,
                          197, 68, 221, 59, 237, 74, 249, 1, 73, 234, 15, 63, 158, 23, 166, 36, 1, 76, 101, 180,
                          176, 162, 52, 254, 1337, 564654655]
        
        XCTAssertEqual(ids.count, 254)
        
        for (index, currentId) in ids.enumerated() {
            actual.append(String(format:"a=extmap:%i urn:ietf:params:rtp-hdrext:encrypt %i\r\n", currentId, index))
            var id = index + 1
            if id >= 15 {
                id += 1
            }
            expected.append(String(format:"a=extmap:%i urn:ietf:params:rtp-hdrext:encrypt %i\r\n", id, index))
        }
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// When local offer, in two-byte header mode, more than 254 RTP header extensions are not allowed.
    func testPatchWithRtpMixedModeHeaderMoreThan254Offer() {
        var sdp = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n"
        
        let ids: [Int] = [134, 68, 14, 95, 97, 64, 66, 89, 143, 82, 51, 53, 145, 172, 91, 64, 144, 107, 241, 37,
                          244, 233, 108, 158, 17, 185, 73, 88, 181, 226, 180, 95, 91, 106, 68, 220, 42, 116, 134,
                          102, 63, 193, 135, 248, 141, 1, 157, 116, 34, 251, 218, 33, 90, 124, 28, 163, 22, 129,
                          73, 234, 138, 93, 224, 220, 150, 6, 56, 55, 112, 112, 210, 189, 150, 202, 197, 74, 176,
                          170, 218, 234, 203, 244, 205, 170, 160, 165, 67, 156, 222, 107, 5, 220, 167, 49, 160,
                          3, 243, 194, 60, 230, 164, 241, 88, 183, 143, 192, 111, 139, 233, 235, 71, 30, 30, 117,
                          188, 245, 230, 92, 37, 82, 119, 236, 250, 2, 123, 188, 243, 196, 220, 177, 172, 105,
                          120, 217, 32, 67, 169, 170, 37, 16, 132, 128, 67, 87, 191, 75, 21, 240, 96, 2, 72, 31,
                          23, 126, 137, 134, 209, 249, 67, 139, 19, 31, 173, 135, 41, 151, 42, 161, 44, 111, 165,
                          193, 243, 216, 248, 89, 251, 140, 97, 18, 22, 47, 108, 50, 35, 188, 186, 212, 43, 80,
                          21, 16, 144, 173, 92, 53, 3, 162, 126, 208, 117, 160, 238, 140, 4, 87, 227, 231, 49,
                          82, 235, 156, 1, 99, 30, 154, 178, 45, 92, 246, 148, 100, 218, 27, 146, 193, 81, 179,
                          197, 68, 221, 59, 237, 74, 249, 1, 73, 234, 15, 63, 158, 23, 166, 36, 1, 76, 101, 180,
                          176, 162, 52, 254, 239, 236, 11, 1337, 564654655]
        
        XCTAssertEqual(ids.count, 257)
        
        for (index, currentId) in ids.enumerated() {
            sdp.append(String(format:"a=extmap:%i urn:ietf:params:rtp-hdrext:encrypt %i\r\n", currentId, index))
        }
        
        XCTAssertThrowsError(try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_OFFER, sdp: sdp), "") { (error) in
            let sdpError = error as! VoIPCallSdpPatcher.SdpError
            XCTAssertEqual(sdpError.type, VoIPCallSdpPatcher.SdpErrorType.invalidSdp)
            XCTAssertEqual(sdpError.description, "a=rtpmap: [...] opus not found")
        }
    }
    
    /// Ensure the `a=extmap-allow-mixed` attribute is stripped when talking to legacy apps.
    func testPatchMixedRtpHeaderStrippedTowardsLegacy() {
        let actual = "v=0\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=video whatever\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=sctp-port:5000\r\n"
        
        let expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "m=video whatever\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=sctp-port:5000\r\n"
        
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_OFFER, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher().patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    ///  Ensure the `a=extmap-allow-mixed` attribute is not stripped when talking to non-legacy apps.
    func testPatchMixedRtpHeaderNotStrippedTowardsCurrent() {
        let actual = "v=0\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=video whatever\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=sctp-port:5000\r\n"
        
        let expected = "v=0\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=video whatever\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=sctp-port:5000\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// All non-encrypted RTP header extensions should be stripped.
    func testPatchWitRtpHeaderUnencrypted() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=extmap:7 duck-noises\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        
        var expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        
        expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_OFFER, sdp: actual))
        
        expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        
        expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// All encrypted RTP header extensions should be left as-is (apart from ID remapping).
    func testPatchWithRtpHeaderEncrypted() {
        let actual = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=extmap:7 duck-noises\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        
        var expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        
        expected = "v=0\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt encrypted-duck-noises\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_LEGACY_ONE_BYTE_HEADER_ONLY).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// Audio only
    func testPatchWithLegacyAudioOnly() {
        let actual = "v=0\r\n" +
            "o=- 8329341859617817285 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE audio\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111 103 9 102 0 8 105 13 110 113 126\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:hFGR\r\n" +
            "a=ice-pwd:HPszOFM6RDZWdhZ3PpPQ7w1H\r\n" +
            "a=ice-options:renomination\r\n" +
            "a=fingerprint:sha-256 F7:3A:7C:0C:A0:1E:EA:C5:2E:33:ED:90:61:55:0E:DF:59:8E:EA:EF:A6:E3:01:6E:A5:9E:34:78:5E:E3:8E:44\r\n" +
            "a=setup:active\r\n" +
            "a=mid:audio\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=extmap:2 urn:ietf:params:rtp-hdrext:csrc-audio-level\r\n" +
            "a=extmap:3 my-cool-extension-we-absolutely-want-to-have\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:csrc-audio-level\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt my-cool-extension-we-absolutely-want-to-have\r\n" +
            "a=sendrecv\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1\r\n" +
            "a=rtpmap:103 ISAC/16000\r\n" +
            "a=rtpmap:9 G722/8000\r\n" +
            "a=rtpmap:102 ILBC/8000\r\n" +
            "a=rtpmap:0 PCMU/8000\r\n" +
            "a=rtpmap:8 PCMA/8000\r\n" +
            "a=rtpmap:105 CN/16000\r\n" +
            "a=rtpmap:13 CN/8000\r\n" +
            "a=rtpmap:110 telephone-event/48000\r\n" +
            "a=rtpmap:113 telephone-event/16000\r\n" +
            "a=rtpmap:126 telephone-event/8000\r\n" +
            "a=ssrc:2080079676 cname:Jb5aR24iJnFDp6OS\r\n" +
            "a=ssrc:2080079676 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:2080079676 mslabel:3MACALL\r\n" +
            "a=ssrc:2080079676 label:3MACALLa0\r\n"
        
        var expected = "v=0\r\n" +
            "o=- 8329341859617817285 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE audio\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:hFGR\r\n" +
            "a=ice-pwd:HPszOFM6RDZWdhZ3PpPQ7w1H\r\n" +
            "a=ice-options:renomination\r\n" +
            "a=fingerprint:sha-256 F7:3A:7C:0C:A0:1E:EA:C5:2E:33:ED:90:61:55:0E:DF:59:8E:EA:EF:A6:E3:01:6E:A5:9E:34:78:5E:E3:8E:44\r\n" +
            "a=setup:active\r\n" +
            "a=mid:audio\r\n" +
            "a=sendrecv\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n" +
            "a=ssrc:2080079676 cname:Jb5aR24iJnFDp6OS\r\n" +
            "a=ssrc:2080079676 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:2080079676 mslabel:3MACALL\r\n" +
            "a=ssrc:2080079676 label:3MACALLa0\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.DISABLE).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        
        expected = "v=0\r\n" +
            "o=- 8329341859617817285 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE audio\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:hFGR\r\n" +
            "a=ice-pwd:HPszOFM6RDZWdhZ3PpPQ7w1H\r\n" +
            "a=ice-options:renomination\r\n" +
            "a=fingerprint:sha-256 F7:3A:7C:0C:A0:1E:EA:C5:2E:33:ED:90:61:55:0E:DF:59:8E:EA:EF:A6:E3:01:6E:A5:9E:34:78:5E:E3:8E:44\r\n" +
            "a=setup:active\r\n" +
            "a=mid:audio\r\n" +
            "a=sendrecv\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n" +
            "a=ssrc:2080079676 cname:Jb5aR24iJnFDp6OS\r\n" +
            "a=ssrc:2080079676 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:2080079676 mslabel:3MACALL\r\n" +
            "a=ssrc:2080079676 label:3MACALLa0\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.DISABLE).patch(type: .LOCAL_OFFER, sdp: actual))
    }
    
    /// Video and audio
    func testPatchSdpWithAudioVideo() {
        let actual = "v=0\r\n" +
            "o=- 72507000979779968 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE 0 1 2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104 9 102 0 8 106 105 13 110 112 113 126\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:0\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n" +
            "a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:16 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:17 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:18 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLa0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1\r\n" +
            "a=rtpmap:103 ISAC/16000\r\n" +
            "a=rtpmap:104 ISAC/32000\r\n" +
            "a=rtpmap:9 G722/8000\r\n" +
            "a=rtpmap:102 ILBC/8000\r\n" +
            "a=rtpmap:0 PCMU/8000\r\n" +
            "a=rtpmap:8 PCMA/8000\r\n" +
            "a=rtpmap:106 CN/32000\r\n" +
            "a=rtpmap:105 CN/16000\r\n" +
            "a=rtpmap:13 CN/8000\r\n" +
            "a=rtpmap:110 telephone-event/48000\r\n" +
            "a=rtpmap:112 telephone-event/32000\r\n" +
            "a=rtpmap:113 telephone-event/16000\r\n" +
            "a=rtpmap:126 telephone-event/8000\r\n" +
            "a=ssrc:3148626149 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:3148626149 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:3148626149 mslabel:3MACALL\r\n" +
            "a=ssrc:3148626149 label:3MACALLa0\r\n" +
            "m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 127 123 125\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:1\r\n" +
            "a=extmap:25 urn:ietf:params:rtp-hdrext:encrypt http://tools.ietf.org/html/draft-ietf-avtext-framemarking-07\r\n" +
            "a=extmap:26 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\n" +
            "a=extmap:14 urn:ietf:params:rtp-hdrext:toffset\r\n" +
            "a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:13 urn:3gpp:video-orientation\r\n" +
            "a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:12 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\n" +
            "a=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\n" +
            "a=extmap:17 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:8 http://tools.ietf.org/html/draft-ietf-avtext-framemarking-07\r\n" +
            "a=extmap:9 http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=extmap:20 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:toffset\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:21 urn:ietf:params:rtp-hdrext:encrypt urn:3gpp:video-orientation\r\n" +
            "a=extmap:16 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:22 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\n" +
            "a=extmap:23 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\n" +
            "a=extmap:24 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\n" +
            "a=extmap:11 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\n" +
            "a=extmap:18 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLv0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtcp-rsize\r\n" +
            "a=rtpmap:96 VP8/90000\r\n" +
            "a=rtcp-fb:96 goog-remb\r\n" +
            "a=rtcp-fb:96 transport-cc\r\n" +
            "a=rtcp-fb:96 ccm fir\r\n" +
            "a=rtcp-fb:96 nack\r\n" +
            "a=rtcp-fb:96 nack pli\r\n" +
            "a=rtpmap:97 rtx/90000\r\n" +
            "a=fmtp:97 apt=96\r\n" +
            "a=rtpmap:98 VP9/90000\r\n" +
            "a=rtcp-fb:98 goog-remb\r\n" +
            "a=rtcp-fb:98 transport-cc\r\n" +
            "a=rtcp-fb:98 ccm fir\r\n" +
            "a=rtcp-fb:98 nack\r\n" +
            "a=rtcp-fb:98 nack pli\r\n" +
            "a=rtpmap:99 rtx/90000\r\n" +
            "a=fmtp:99 apt=98\r\n" +
            "a=rtpmap:100 H264/90000\r\n" +
            "a=rtcp-fb:100 goog-remb\r\n" +
            "a=rtcp-fb:100 transport-cc\r\n" +
            "a=rtcp-fb:100 ccm fir\r\n" +
            "a=rtcp-fb:100 nack\r\n" +
            "a=rtcp-fb:100 nack pli\r\n" +
            "a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\n" +
            "a=rtpmap:101 rtx/90000\r\n" +
            "a=fmtp:101 apt=100\r\n" +
            "a=rtpmap:127 red/90000\r\n" +
            "a=rtpmap:123 rtx/90000\r\n" +
            "a=fmtp:123 apt=127\r\n" +
            "a=rtpmap:125 ulpfec/90000\r\n" +
            "a=ssrc-group:FID 2961420724 927121398\r\n" +
            "a=ssrc:2961420724 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:2961420724 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:2961420724 mslabel:3MACALL\r\n" +
            "a=ssrc:2961420724 label:3MACALLv0\r\n" +
            "a=ssrc:927121398 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:927121398 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:927121398 mslabel:3MACALL\r\n" +
            "a=ssrc:927121398 label:3MACALLv0\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:2\r\n" +
            "a=sctp-port:5000\r\n" +
            "a=max-message-size:262144\r\n"
        
        var expected = "v=0\r\n" +
            "o=- 72507000979779968 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE 0 1 2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:0\r\n" +
            "a=extmap:16 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:17 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:18 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLa0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n" +
            "a=ssrc:3148626149 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:3148626149 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:3148626149 mslabel:3MACALL\r\n" +
            "a=ssrc:3148626149 label:3MACALLa0\r\n" +
            "m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 127 123 125\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:1\r\n" +
            "a=extmap:26 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\n" +
            "a=extmap:17 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:20 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:toffset\r\n" +
            "a=extmap:15 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:21 urn:ietf:params:rtp-hdrext:encrypt urn:3gpp:video-orientation\r\n" +
            "a=extmap:16 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:22 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\n" +
            "a=extmap:23 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\n" +
            "a=extmap:24 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\n" +
            "a=extmap:18 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:19 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLv0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtcp-rsize\r\n" +
            "a=rtpmap:96 VP8/90000\r\n" +
            "a=rtcp-fb:96 goog-remb\r\n" +
            "a=rtcp-fb:96 transport-cc\r\n" +
            "a=rtcp-fb:96 ccm fir\r\n" +
            "a=rtcp-fb:96 nack\r\n" +
            "a=rtcp-fb:96 nack pli\r\n" +
            "a=rtpmap:97 rtx/90000\r\n" +
            "a=fmtp:97 apt=96\r\n" +
            "a=rtpmap:98 VP9/90000\r\n" +
            "a=rtcp-fb:98 goog-remb\r\n" +
            "a=rtcp-fb:98 transport-cc\r\n" +
            "a=rtcp-fb:98 ccm fir\r\n" +
            "a=rtcp-fb:98 nack\r\n" +
            "a=rtcp-fb:98 nack pli\r\n" +
            "a=rtpmap:99 rtx/90000\r\n" +
            "a=fmtp:99 apt=98\r\n" +
            "a=rtpmap:100 H264/90000\r\n" +
            "a=rtcp-fb:100 goog-remb\r\n" +
            "a=rtcp-fb:100 transport-cc\r\n" +
            "a=rtcp-fb:100 ccm fir\r\n" +
            "a=rtcp-fb:100 nack\r\n" +
            "a=rtcp-fb:100 nack pli\r\n" +
            "a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\n" +
            "a=rtpmap:101 rtx/90000\r\n" +
            "a=fmtp:101 apt=100\r\n" +
            "a=rtpmap:127 red/90000\r\n" +
            "a=rtpmap:123 rtx/90000\r\n" +
            "a=fmtp:123 apt=127\r\n" +
            "a=rtpmap:125 ulpfec/90000\r\n" +
            "a=ssrc-group:FID 2961420724 927121398\r\n" +
            "a=ssrc:2961420724 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:2961420724 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:2961420724 mslabel:3MACALL\r\n" +
            "a=ssrc:2961420724 label:3MACALLv0\r\n" +
            "a=ssrc:927121398 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:927121398 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:927121398 mslabel:3MACALL\r\n" +
            "a=ssrc:927121398 label:3MACALLv0\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:2\r\n" +
            "a=sctp-port:5000\r\n" +
            "a=max-message-size:262144\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_ANSWER_OR_REMOTE_SDP, sdp: actual))
        
        expected = "v=0\r\n" +
            "o=- 72507000979779968 2 IN IP4 127.0.0.1\r\n" +
            "s=-\r\n" +
            "t=0 0\r\n" +
            "a=group:BUNDLE 0 1 2\r\n" +
            "a=extmap-allow-mixed\r\n" +
            "a=msid-semantic: WMS 3MACALL\r\n" +
            "m=audio 9 UDP/TLS/RTP/SAVPF 111\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:0\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:2 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLa0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtpmap:111 opus/48000/2\r\n" +
            "a=rtcp-fb:111 transport-cc\r\n" +
            "a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=1\r\n" +
            "a=ssrc:3148626149 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:3148626149 msid:3MACALL 3MACALLa0\r\n" +
            "a=ssrc:3148626149 mslabel:3MACALL\r\n" +
            "a=ssrc:3148626149 label:3MACALLa0\r\n" +
            "m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 127 123 125\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=rtcp:9 IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:1\r\n" +
            "a=extmap:6 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/color-space\r\n" +
            "a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:mid\r\n" +
            "a=extmap:7 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:toffset\r\n" +
            "a=extmap:2 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n" +
            "a=extmap:8 urn:ietf:params:rtp-hdrext:encrypt urn:3gpp:video-orientation\r\n" +
            "a=extmap:1 urn:ietf:params:rtp-hdrext:encrypt http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01\r\n" +
            "a=extmap:9 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r\n" +
            "a=extmap:10 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-content-type\r\n" +
            "a=extmap:11 urn:ietf:params:rtp-hdrext:encrypt http://www.webrtc.org/experiments/rtp-hdrext/video-timing\r\n" +
            "a=extmap:4 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id\r\n" +
            "a=extmap:5 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id\r\n" +
            "a=sendrecv\r\n" +
            "a=msid:3MACALL 3MACALLv0\r\n" +
            "a=rtcp-mux\r\n" +
            "a=rtcp-rsize\r\n" +
            "a=rtpmap:96 VP8/90000\r\n" +
            "a=rtcp-fb:96 goog-remb\r\n" +
            "a=rtcp-fb:96 transport-cc\r\n" +
            "a=rtcp-fb:96 ccm fir\r\n" +
            "a=rtcp-fb:96 nack\r\n" +
            "a=rtcp-fb:96 nack pli\r\n" +
            "a=rtpmap:97 rtx/90000\r\n" +
            "a=fmtp:97 apt=96\r\n" +
            "a=rtpmap:98 VP9/90000\r\n" +
            "a=rtcp-fb:98 goog-remb\r\n" +
            "a=rtcp-fb:98 transport-cc\r\n" +
            "a=rtcp-fb:98 ccm fir\r\n" +
            "a=rtcp-fb:98 nack\r\n" +
            "a=rtcp-fb:98 nack pli\r\n" +
            "a=rtpmap:99 rtx/90000\r\n" +
            "a=fmtp:99 apt=98\r\n" +
            "a=rtpmap:100 H264/90000\r\n" +
            "a=rtcp-fb:100 goog-remb\r\n" +
            "a=rtcp-fb:100 transport-cc\r\n" +
            "a=rtcp-fb:100 ccm fir\r\n" +
            "a=rtcp-fb:100 nack\r\n" +
            "a=rtcp-fb:100 nack pli\r\n" +
            "a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f\r\n" +
            "a=rtpmap:101 rtx/90000\r\n" +
            "a=fmtp:101 apt=100\r\n" +
            "a=rtpmap:127 red/90000\r\n" +
            "a=rtpmap:123 rtx/90000\r\n" +
            "a=fmtp:123 apt=127\r\n" +
            "a=rtpmap:125 ulpfec/90000\r\n" +
            "a=ssrc-group:FID 2961420724 927121398\r\n" +
            "a=ssrc:2961420724 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:2961420724 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:2961420724 mslabel:3MACALL\r\n" +
            "a=ssrc:2961420724 label:3MACALLv0\r\n" +
            "a=ssrc:927121398 cname:xmp2nT2LrKeffKAn\r\n" +
            "a=ssrc:927121398 msid:3MACALL 3MACALLv0\r\n" +
            "a=ssrc:927121398 mslabel:3MACALL\r\n" +
            "a=ssrc:927121398 label:3MACALLv0\r\n" +
            "m=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "a=ice-ufrag:f30j\r\n" +
            "a=ice-pwd:G9GzFLlk1gthsg9uVhI3OyGv\r\n" +
            "a=ice-options:trickle renomination\r\n" +
            "a=fingerprint:sha-256 AE:86:73:4B:8A:55:BE:F1:2F:A2:8E:AA:98:8D:42:A4:D6:F8:2D:1C:CC:CD:12:C5:8E:14:BD:34:62:DA:35:8E\r\n" +
            "a=setup:actpass\r\n" +
            "a=mid:2\r\n" +
            "a=sctp-port:5000\r\n" +
            "a=max-message-size:262144\r\n"
        XCTAssertEqual(expected, try VoIPCallSdpPatcher(.ENABLE_WITH_ONE_AND_TWO_BYTE_HEADER).patch(type: .LOCAL_OFFER, sdp: actual))
    }
}
