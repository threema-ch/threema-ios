//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

import UIKit
import ThreemaFramework
import WebRTC

class CallDiagnosticViewController: UIViewController, RTCPeerConnectionDelegate {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var copyButton: UIButton!
    @IBOutlet weak var diagnosticTextView: UITextView!
    @IBOutlet weak var finishLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var connection:RTCPeerConnection?
    var factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var isDiagnosticRunning: Bool = false
    
    internal var kCANDIDATE_ATTRIBUTE: NSRegularExpression?
    internal var kSP: String = "\\s"
    internal var kICE_CHAR: String = "[a-zA-Z\\d\\+\\/]"
    internal var kFOUNDATION: String
    internal var kCOMPONENT_ID: String = "\\d{1,5}"
    internal var kTRANSPORT: String = "[uU][dD][pP]"
    internal var kPRIORITY: String = "\\d{1,10}"
    internal var kCANDIDATE_TYPES: String = "(host|srflx|prflx|relay)"
    internal var kCAND_TYPE: String
    internal var kCONNECTION_ADDRESS: String = "\\S+"
    internal var kREL_ADDR: String
    internal var kPORT: String = "\\d{1,5}"
    internal var kREL_PORT: String
    internal var kBYTE_STRING: String = "\\S+"
    internal var kEXTENSION_ATT_NAME: String
    internal var kEXTENSION_ATT_VALUE: String

    required init?(coder aDecoder: NSCoder) {
        kFOUNDATION = String.init(format: "%@{1,32}", kICE_CHAR)
        kCAND_TYPE = String.init(format: "typ%@%@", kSP, kCANDIDATE_TYPES)
        kREL_ADDR = String.init(format: "raddr%@(%@)", kSP, kCONNECTION_ADDRESS)
        kREL_PORT = String.init(format: "rport%@(%@)", kSP, kPORT)
        kEXTENSION_ATT_NAME = kBYTE_STRING
        kEXTENSION_ATT_VALUE = kBYTE_STRING
        do {
        kCANDIDATE_ATTRIBUTE = try NSRegularExpression(pattern: String.init(format: "candidate:(%@)%@(%@)%@(%@)%@(%@)%@(%@)%@(%@)%@%@(%@%@)?(%@%@)?((%@%@%@%@)*)", kFOUNDATION, kSP, kCOMPONENT_ID, kSP, kTRANSPORT, kSP, kPRIORITY, kSP, kCONNECTION_ADDRESS, kSP, kPORT, kSP, kCAND_TYPE, kSP, kREL_ADDR, kSP, kREL_PORT, kSP, kEXTENSION_ATT_NAME, kSP, kEXTENSION_ATT_VALUE), options: [])
        }
        catch {
            
        }
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupColors()
        setupLocalizables()
        
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        
        if diagnosticTextView.text.count == 0 {
            finishLabel.isHidden = true
            diagnosticTextView.isHidden = true
            copyButton.isHidden = true
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        DispatchQueue.main.async {
            if self.isDiagnosticRunning {
                self.printStatus("Diagnostic cancelled")
            }
            
            if self.connection != nil {
                self.connection?.close()
                self.connection = nil
            }
        }
    }
    
    
    // MARK: Private functions
    
    private func setupColors() {
        descriptionLabel.font = UIFont.systemFont(ofSize: 17.0)
        finishLabel.font = UIFont.systemFont(ofSize: 17.0)
        descriptionLabel.textColor = Colors.fontNormal()
        finishLabel.textColor = Colors.fontNormal()
        
        startButton.setTitleColor(Colors.main(), for: .normal)
        startButton.setTitleColor(Colors.main(), for: .highlighted)
        startButton.setTitleColor(Colors.main(), for: .selected)
        
        copyButton.setTitleColor(Colors.main(), for: .normal)
        copyButton.setTitleColor(Colors.main(), for: .highlighted)
        copyButton.setTitleColor(Colors.main(), for: .selected)
        
        self.view.backgroundColor = Colors.background()
        
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            diagnosticTextView.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            activityIndicator.style = .white
            break
        case ColorThemeUndefined, ColorThemeLight, ColorThemeLightWork:
            diagnosticTextView.textColor = Colors.fontLight()
            activityIndicator.style = .gray
            break
        default:
            diagnosticTextView.textColor = Colors.fontLight()
            activityIndicator.style = .gray
            break
        }
        
        diagnosticTextView.font = UIFont.systemFont(ofSize: 15.0)
        
        diagnosticTextView.layer.borderWidth = 1.0
        diagnosticTextView.layer.borderColor = Colors.fontVeryLight().cgColor
    }
    
    private func setupLocalizables() {
        self.title = NSLocalizedString("webrtc_diagnostics.title", comment: "")
        descriptionLabel.text = NSLocalizedString("webrtc_diagnostics.description", comment: "")
        finishLabel.text = NSLocalizedString("webrtc_diagnostics.done", comment: "")
        
        startButton.setTitle(NSLocalizedString("webrtc_diagnostics.start", comment: ""), for: .normal)
        copyButton.setTitle(NSLocalizedString("webrtc_diagnostics.copyToClipboard", comment: ""), for: .normal)
    }
    
    private func startDiagnostic() {
        isDiagnosticRunning = true
        diagnosticTextView.text = ""
        
        let ipv6 = UserSettings.shared().enableIPv6 ? "IPv6 enabled" : "IPv6 disabled"
        let relay = UserSettings.shared().alwaysRelayCalls ? "Always relay enabled" : "Always relay disabled"
        printStatus("Start diagnostic (\(ipv6), \(relay))")
        
        let constraints = defaultPeerConnectionConstraints()
        defaultRTCConfiguration { [self] (result) in
            
            guard case .success(let configuration) = result else {
                printStatus("Cannot obtain TURN servers: \(result)")
                return
            }
            
            connection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self)
            let localStream = createLocalMediaStreamWithFactory(factory: factory)
            connection?.add(localStream)
            
            connection?.offer(for: constraints) { (sdp, error) in
                if (sdp != nil) {
                    self.connection?.setLocalDescription(sdp!, completionHandler: { (error) in
                    })
                }
            }
        }
    }
    
    private func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let optionalConstraints = ["DtlsSrtpKeyAgreement": "true"]
        let constraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
        return constraints
    }
    
    private func defaultAudioConstraints() -> RTCMediaConstraints {
        let constraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: nil)
        return constraints
    }
    
    private func defaultRTCConfiguration(completion: @escaping (Result<RTCConfiguration, Error>) -> Void) {
        VoIPIceServerSource.obtainIceServers(dualStack: false) { (result) in
            
            do {
                let configuration = RTCConfiguration()
                configuration.iceServers = [try result.get()]
                configuration.iceTransportPolicy = .all
                configuration.bundlePolicy = .maxBundle
                configuration.rtcpMuxPolicy = .require
                configuration.tcpCandidatePolicy = .disabled
                configuration.continualGatheringPolicy = .gatherOnce
                
                completion(.success(configuration))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    private func createLocalMediaStreamWithFactory(factory:RTCPeerConnectionFactory) -> RTCMediaStream {
        let source = factory.audioSource(with: defaultAudioConstraints())
        let localStream = factory.mediaStream(withStreamId: "AMACALL")
        localStream.addAudioTrack(factory.audioTrack(with: source, trackId: "AMACALLa0"))
        return localStream
    }
    
    private func printCandidate(candidate: RTCIceCandidate) {
        DispatchQueue.main.sync {
            var diagnosticString = ""
            if diagnosticTextView.text.count > 0 {
                diagnosticString = diagnosticTextView.text + "\n" + "--------------------" + "\n"
            }

            
            let candidateDatas = self.parseCandidates(sdp: candidate.sdp)
            for candidateData in candidateDatas {
                diagnosticString = diagnosticString + "[" + candidateData.candType + "] " + candidateData.transport + " " + candidateData.connectionAddress + ":"
                if candidateData.port != nil {
                    diagnosticString = diagnosticString + String(candidateData.port!)
                }
                
                if candidateData.relAddr != nil && candidateData.relPort != nil {
                    diagnosticString = diagnosticString + " via " + candidateData.relAddr! + ":" + String(candidateData.relPort!)
                }
                
                diagnosticTextView.text = diagnosticString
            }
        }
    }
    
    private func parseCandidates(sdp: String) -> [CandidateData] {
        if kCANDIDATE_ATTRIBUTE != nil {
            let matches = kCANDIDATE_ATTRIBUTE!.matches(in: sdp, options: [], range: NSRange(location: 0, length: sdp.count))
            let candidateData = matches.map { result -> CandidateData in
                var foundation: String
                var componentId: Int?
                var transport: String
                var priority: Int?
                var connectionAddress: String
                var port: Int?
                var candType: String
                var relAddr: String?
                var relPort: Int?
                var extensions: [String: String] = [String: String]()
                
                var range = result.range(at:1)
                var swiftRange = Range(range, in: sdp)
                foundation = String(sdp[swiftRange!])
                    
                range = result.range(at:2)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    componentId = Int(String(sdp[swiftRange!]))
                }
                
                range = result.range(at:3)
                swiftRange = Range(range, in: sdp)
                transport = String(sdp[swiftRange!])

                range = result.range(at:4)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    priority = Int(String(sdp[swiftRange!]))
                }
                
                range = result.range(at:5)
                swiftRange = Range(range, in: sdp)
                connectionAddress = String(sdp[swiftRange!])
                
                range = result.range(at:6)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    port = Int(String(sdp[swiftRange!]))
                }
                
                range = result.range(at:7)
                swiftRange = Range(range, in: sdp)
                candType = String(sdp[swiftRange!])
                
                range = result.range(at:9)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    relAddr = String(sdp[swiftRange!])
                }
                
                range = result.range(at:11)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    relPort = Int(String(sdp[swiftRange!]))!
                }
                
                range = result.range(at:12)
                swiftRange = Range(range, in: sdp)
                if swiftRange != nil {
                    let extensionsString = String(sdp[swiftRange!])
                    let extensionsArray = extensionsString.components(separatedBy: " ")
                    var key: String? = nil
                    for extensionValue in extensionsArray {
                        if extensionValue.count > 0 {
                            if key == nil {
                                key = extensionValue
                            } else {
                                extensions.updateValue(extensionValue, forKey: key!)
                                key = nil
                            }
                        }
                    }
                }
                
                return CandidateData.init(theFoundation: foundation, theComponentId: componentId, theTransport: transport, thePriority: priority, theConnectionAddress: connectionAddress, thePort: port, theCandType: candType, theRelAddr: relAddr, theRelPort: relPort, theExtensions: extensions)
                
            }
            return candidateData
        } else {
            return []
        }
    }
    
    private func printStatus(_ status: String) {
        var diagnosticString = ""
        if diagnosticTextView.text.count > 0 {
            diagnosticString = diagnosticTextView.text + "\n\n"
        }
        
        diagnosticTextView.text = diagnosticString + status
    }
    
    
    // MARK: IBActions
    
    @IBAction func startButtonTapped(_ sender: AnyObject) {
        diagnosticTextView.isHidden = false
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        startButton.isHidden = true
        startDiagnostic()
    }
    
    @IBAction func copyButtonTapped(_ sender: AnyObject) {
        UIPasteboard.general.string = self.diagnosticTextView.text
        
        UIAlertTemplate.showAlert(owner: self, title: nil, message: NSLocalizedString("webrtc_diagnostics.copy", comment: ""))
    }
    
    
    // MARK: RTCPeerConnectionDelegate
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        if newState == .complete {
            isDiagnosticRunning = false
            DispatchQueue.main.async {
                self.printStatus("IceGathering complete")
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                self.finishLabel.isHidden = false
                self.copyButton.isHidden = false
            }
        }
        if newState == .gathering {
            DispatchQueue.main.async {
                self.printStatus("IceGathering start")
            }
        }

    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        printCandidate(candidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    }
}

struct CandidateData {
    var foundation: String
    var componentId: Int?
    var transport: String
    var priority: Int?
    var connectionAddress: String
    var port: Int?
    var candType: String
    var relAddr: String?
    var relPort: Int?
    var extensions: [String: String]
    
    init(theFoundation: String, theComponentId: Int?, theTransport: String, thePriority: Int?, theConnectionAddress: String, thePort: Int?, theCandType: String, theRelAddr: String?, theRelPort: Int?, theExtensions:[String: String]) {
        foundation = theFoundation
        componentId = theComponentId
        transport = theTransport
        priority = thePriority
        connectionAddress = theConnectionAddress
        port = thePort
        candType = theCandType
        relAddr = theRelAddr
        relPort = theRelPort
        extensions = theExtensions
    }
}
