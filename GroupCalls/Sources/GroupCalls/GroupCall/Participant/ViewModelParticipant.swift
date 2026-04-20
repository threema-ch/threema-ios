import Foundation
import ThreemaEssentials
import UIKit

@GlobalGroupCallActor
protocol ViewModelParticipant: Participant {
    nonisolated var threemaIdentity: ThreemaIdentity { get }
    nonisolated var dependencies: Dependencies { get }

    nonisolated var displayName: String { get }
    nonisolated var profilePicture: UIImage { get }
    nonisolated var idColor: UIColor { get }

    var audioMuteState: MuteState { get }
    var screenMuteState: MuteState { get }
    var videoMuteState: MuteState { get }
    
    func setVideoMuteState(to state: MuteState) async
    func setScreenMuteState(to state: MuteState) async
    func setAudioMuteState(to state: MuteState) async

    func cellAccessibilityLabel() -> String
}

@GlobalGroupCallActor
extension ViewModelParticipant {

    public func cellAccessibilityLabel() -> String {
        "\(displayName), \(cellAccessibilityAudioString()), \(cellAccessibilityVideoString())"
    }
    
    private func cellAccessibilityVideoString() -> String {
        switch videoMuteState {
        case .muted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_disabled")
        case .unmuted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_video_enabled")
        }
    }
    
    private func cellAccessibilityAudioString() -> String {
        switch audioMuteState {
        case .muted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_disabled")
        case .unmuted:
            dependencies.groupCallBundleUtil.localizedString(for: "group_call_accessibility_audio_enabled")
        }
    }
}
