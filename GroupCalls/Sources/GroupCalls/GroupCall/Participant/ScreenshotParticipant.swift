import Foundation
import ThreemaEssentials
import UIKit

/// Only use for screenshots
final class ScreenshotParticipant: ViewModelParticipant {
    
    nonisolated let participantID: ParticipantID
    nonisolated let threemaIdentity: ThreemaIdentity
    let dependencies: Dependencies
    
    nonisolated lazy var displayName: String = dependencies.groupCallParticipantInfoFetcher
        .fetchDisplayName(for: threemaIdentity)
    
    nonisolated lazy var profilePicture: UIImage = dependencies.groupCallParticipantInfoFetcher
        .fetchProfilePicture(for: threemaIdentity)
    
    nonisolated lazy var idColor: UIColor = dependencies.groupCallParticipantInfoFetcher
        .fetchIDColor(for: threemaIdentity)
    
    var audioMuteState: MuteState = .muted
    var videoMuteState: MuteState = .muted
    var screenMuteState: MuteState = .muted
    
    func setVideoMuteState(to state: MuteState) async {
        videoMuteState = state
    }
    
    func setScreenMuteState(to state: MuteState) async {
        screenMuteState = state
    }
    
    func setAudioMuteState(to state: MuteState) async {
        audioMuteState = state
    }
    
    // MARK: - Lifecycle

    init(
        participantID: ParticipantID,
        threemaIdentity: ThreemaIdentity,
        dependencies: Dependencies,
        audioMuteState: MuteState,
        videoMuteState: MuteState
    ) {
        guard dependencies.isRunningForScreenshots else {
            fatalError(
                "[GroupCall] Tried to initialize ScreenshotParticipant even though we are not running for screenshots"
            )
        }
        
        self.participantID = participantID
        self.threemaIdentity = threemaIdentity
        self.dependencies = dependencies
        self.audioMuteState = audioMuteState
        self.videoMuteState = videoMuteState
    }
}
