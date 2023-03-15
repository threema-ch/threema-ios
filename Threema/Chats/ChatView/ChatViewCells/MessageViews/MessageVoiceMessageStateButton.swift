//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

final class MessageVoiceMessageStateButton: ThemedCodeButton {
    typealias config = ChatViewConfiguration.VoiceMessage.PlaybackStateButton

    // MARK: - Internal Properties

    /// `VoiceMessage` whose messsage state is shown
    var voiceMessage: VoiceMessage? {
        didSet {
            updateView(with: voiceMessage)
        }
    }
    
    /// Indicates whether the `voiceMessage` set in the field above is currently playing
    /// Updates the button to reflect the any changes
    var isPlaying: Bool {
        didSet {
            updateView(with: voiceMessage, isPlaying: isPlaying)
        }
    }
    
    // MARK: - Lifecycle
    
    override public init(frame: CGRect = .zero, action: @escaping Action) {
        self.isPlaying = false
        
        super.init(frame: frame, action: action)
    }
    
    // MARK: - Updates
    
    /// Sets the correct icon for the current blob state of the voiceMessage and the play state indicated in isPlaying
    /// - Parameters:
    ///   - voiceMessage: used to determine the blob state
    ///   - isPlaying: used to determine the playback state
    private func updateView(with voiceMessage: VoiceMessage?, isPlaying: Bool = false) {
        guard let voiceMessage = voiceMessage else {
            setBackgroundImage(nil, for: .normal)
            return
        }
        
        let currentBlobDisplayState = voiceMessage.blobDisplayState
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: config.circleFillSymbolSize)
        let symbolName: String
        
        switch currentBlobDisplayState {
        case .remote, .downloading, .fileNotFound, .dataDeleted, .sendingError:
            if let fillSymbolName = currentBlobDisplayState.circleFillSymbolName {
                symbolName = fillSymbolName
            }
            else {
                symbolName = "play.slash.fill"
            }
            
        case .processed, .pending, .uploading, .uploaded:
            if isPlaying {
                symbolName = "pause.circle.fill"
            }
            else {
                symbolName = "play.circle.fill"
            }
        }
        
        let image = UIImage(
            systemName: symbolName,
            withConfiguration: symbolConfig
        )?.withAlignmentRectInsets(UIEdgeInsets(
            top: -config.circleFillSymbolInset,
            left: -config.circleFillSymbolInset,
            bottom: -config.circleFillSymbolInset,
            right: -config.circleFillSymbolInset
        ))
        setImage(image, for: .normal)
    }
    
    override func updateColors() {
        tintColor = Colors.textLight
    }
}
