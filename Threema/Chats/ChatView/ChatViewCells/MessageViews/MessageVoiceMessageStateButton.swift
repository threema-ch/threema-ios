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
        
        self.tintColor = .secondaryLabel
    }
    
    // MARK: - Updates
    
    /// Sets the correct icon for the current blob state of the voiceMessage and the play state indicated in isPlaying
    /// - Parameters:
    ///   - voiceMessage: used to determine the blob state
    ///   - isPlaying: used to determine the playback state
    private func updateView(with voiceMessage: VoiceMessage?, isPlaying: Bool = false) {
        guard let voiceMessage else {
            setBackgroundImage(nil, for: .normal)
            return
        }
        
        let currentBlobDisplayState = voiceMessage.blobDisplayState
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: config.circleFillSymbolSize)
        let symbolName: String =
            switch currentBlobDisplayState {
            case .remote, .downloading, .fileNotFound, .dataDeleted:
                if let fillSymbolName = currentBlobDisplayState.circleFillSymbolName {
                    fillSymbolName
                }
                else {
                    "play.slash.fill"
                }
            
            case .processed, .pending, .uploading, .uploaded, .sendingError:
                if isPlaying {
                    "pause.circle.fill"
                }
                else {
                    "play.circle.fill"
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
}
