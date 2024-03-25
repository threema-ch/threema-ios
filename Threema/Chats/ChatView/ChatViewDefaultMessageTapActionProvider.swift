//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// Default interaction for messages
///
/// Depending on the message type different things might happen: e.g. a video playing inline or a photo shown in the
/// photo browser
class ChatViewDefaultMessageTapActionProvider: NSObject {
    
    private weak var chatViewController: ChatViewController?
    private let entityManager: EntityManager
    // This needs to be a class property to work
    var fileMessagePreview: FileMessagePreview?

    private lazy var photoBrowserWrapper = MWPhotoBrowserWrapper(
        for: chatViewController!.conversation,
        in: chatViewController,
        entityManager: entityManager,
        delegate: self
    )
    
    /// Temporary file that might have ben used to show/play the cell content and should be deleted when it is not shown
    /// anymore
    private var temporaryFileToCleanUp: URL?
    
    // Video playing state
    
    /// Keeps track of the set audio session category before playing a video (if no VoIP call is active)
    private var previousAudioSessionCategory: AVAudioSession.Category?
    /// Keeps track if the video is shown picture in picture
    private var videoIsPictureInPicture = false
    
    // MARK: - Lifecycle
    
    /// Create a new copy that uses the provided ChatViewController to show details on
    /// - Parameters:
    ///   - chatViewController: ChatViewController to show details on
    ///   - entityManager: Entity Manager used for fetching any related data
    init(
        chatViewController: ChatViewController?,
        entityManager: EntityManager
    ) {
        self.chatViewController = chatViewController
        self.entityManager = entityManager
    }
    
    // MARK: - Run
    
    /// Run default action depending on the provided message
    /// - Parameter message: Message to run default action for
    func run(for message: BaseMessage, customDefaultAction: (() -> Void)? = nil) {
        switch message {
        
        case let fileMessageProvider as FileMessageProvider:
            switch fileMessageProvider.blobDisplayState {
            case .remote:
                // Start download if possible
                syncBlobsAction(objectID: message.objectID)
                
            case .processed, .pending, .uploading, .uploaded, .sendingError:
                // TODO: (IOS-4252) Cleanup by also setting state to remote for this case
                if case .outgoing(.pendingDownload) = fileMessageProvider.dataState {
                    // Start download if possible
                    syncBlobsAction(objectID: message.objectID)
                    return
                }

                switch fileMessageProvider.fileMessageType {
                case let .file(fileMessage):
                    guard let fileMessageEntity = fileMessage as? FileMessageEntity else {
                        return
                    }
                    
                    fileMessagePreview = FileMessagePreview(for: fileMessageEntity)
                    fileMessagePreview?.show(on: chatViewController?.navigationController)
                    
                case let .video(videoMessage):
                    play(videoMessage: videoMessage)
                case .animatedImage, .animatedSticker:
                    customDefaultAction?()
                default:
                    photoBrowserWrapper.openPhotoBrowser(for: message)
                }
            case .downloading:
                cancelBlobSyncAction(objectID: message.objectID)
            case .dataDeleted, .fileNotFound:
                return
            }
            
        case let locationMessage as LocationMessage:
            showLocationDetails(locationMessage: locationMessage)
        
        case let ballotMessage as BallotMessage:
            showBallot(ballotMessage: ballotMessage)
        
        case let systemMessage as SystemMessage:
            switch systemMessage.systemMessageType {
            case .callMessage:
                startVoIPCall(callMessage: systemMessage)
            case .systemMessage, .workConsumerInfo:
                return
            }
        
        default:
            DDLogNotice("[ChatViewDefaultMessageTapActionProvider] Tapped on cell with no default action.")
        }
    }
    
    // MARK: - Actions
    
    private func play(videoMessage: VideoMessage) {
        // This plays a video directly using the default UI.
        // This should be revised when a more coherent interface for file cell interactions is implemented
        // (e.g. a replacement of the current MWPhotoBrowser (IOS-559))
        guard let temporaryBlobDataURL = videoMessage.temporaryBlobDataURL() else {
            DDLogError("Unable to play video")
            NotificationPresenterWrapper.shared.present(type: .playingError)
            return
        }
        
        temporaryFileToCleanUp = temporaryBlobDataURL
        
        let player = AVPlayer(url: temporaryBlobDataURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.delegate = self
        let voipCallState = VoIPCallStateManager.shared.currentCallState()
        if voipCallState == .idle {
            previousAudioSessionCategory = AVAudioSession.sharedInstance().category
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
                
        chatViewController?.present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    private func showLocationDetails(locationMessage: LocationMessage) {
        // Opens the location of a location message in a modal
        guard let locationVC = LocationViewController(locationMessage: locationMessage) else {
            return
        }
        let modalNavController = ModalNavigationController(rootViewController: locationVC)
        modalNavController.showLeftDoneButton = true
        chatViewController?.present(modalNavController, animated: true)
    }
    
    private func showBallot(ballotMessage: BallotMessage) {
        // Opens the ballot of a ballot message in a modal
        entityManager.performBlock {
            if let ballot = ballotMessage.ballot,
               let fetchedBallot = self.entityManager.entityFetcher.ballot(for: ballot.id) {
                BallotDispatcher.showViewController(
                    for: fetchedBallot,
                    on: self.chatViewController?.navigationController
                )
            }
        }
    }
    
    private func startVoIPCall(callMessage: SystemMessage) {
        // Starts a VoIP Call if contact supports it
        if UserSettings.shared()?.enableThreemaCall == true,
           let contact = callMessage.conversation?.contact {
            let contactSet = Set<ContactEntity>([contact])
            FeatureMask.check(contacts: contactSet, for: Int(FEATURE_MASK_VOIP)) { unsupportedContacts in
                if unsupportedContacts.isEmpty == true {
                    self.chatViewController?.startOneToOneCall()
                }
                else {
                    NotificationPresenterWrapper.shared.present(type: .callCreationError)
                }
            }
        }
        else {
            NotificationPresenterWrapper.shared.present(type: .callDisabledError)
        }
    }
    
    private func syncBlobsAction(objectID: NSManagedObjectID) {
        Task {
            await BlobManager.shared.syncBlobs(for: objectID)
        }
    }
    
    private func cancelBlobSyncAction(objectID: NSManagedObjectID) {
        Task {
            await BlobManager.shared.cancelBlobsSync(for: objectID)
        }
    }
}

// MARK: - AVPlayerViewControllerDelegate

extension ChatViewDefaultMessageTapActionProvider: AVPlayerViewControllerDelegate {
    
    // We support basic picture in picture (pip). Exiting pip will close the player thus we don't need to keep
    // track of this transition. We will only keep track when we enter pip and cleanup whenever pip is exited.
    //
    // Note: Most `AVPlayerViewControllerDelegate` methods are only called on tvOS!
    
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        // This resolve the issue of scrubbing accidentally stopping the AudioSession
        coordinator.animateAlongsideTransition(in: nil, animation: nil) { _ in
            if !self.videoIsPictureInPicture {
                self.resetAudioSessionAndCleanUpVideoFile()
            }
        }
    }
    
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        // This is called before `playerViewController(_:willEndFullScreenPresentationWithAnimationCoordinator:)`
        // (in iOS 16)
        videoIsPictureInPicture = true
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        resetAudioSessionAndCleanUpVideoFile()
        videoIsPictureInPicture = false
    }
    
    private func resetAudioSessionAndCleanUpVideoFile() {
        // Reset audio category and resume other playing audio
        let currentCallState = VoIPCallStateManager.shared.currentCallState()
        if currentCallState == .idle {
            do {
                try AVAudioSession.sharedInstance().setCategory(previousAudioSessionCategory ?? .soloAmbient)
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            catch {
                DDLogError("Unable to reset audio session: \(error)")
            }
            previousAudioSessionCategory = nil
        }
        
        // Delete temporary file that was played if there was any
        FileUtility.delete(at: temporaryFileToCleanUp)
        temporaryFileToCleanUp = nil
    }
}

// MARK: - MWPhotoBrowserWrapperDelegate

extension ChatViewDefaultMessageTapActionProvider: MWPhotoBrowserWrapperDelegate {
    func willDeleteMessages(with objectIDs: [NSManagedObjectID]) {
        chatViewController?.willDeleteMessages(with: objectIDs)
    }
}
