import CocoaLumberjackSwift
import FileUtility
import Foundation

extension AudioMessageEntity: VoiceMessage {
    
    override public var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            true
        default:
            false
        }
    }
    
    public var consumed: Date? {
        Date(timeIntervalSince1970: 0)
    }
    
    // MARK: - FileMessageProvider
    
    public var fileMessageType: FileMessageType {
        .voice(self)
    }
    
    // MARK: - ThumbnailDisplayMessage

    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let audioSize = audioSize?.doubleValue {
            return .init(value: audioSize, unit: .bytes)
        }
        else {
            assertionFailure("No audio file size available")
            return .init(value: 0, unit: .bytes)
        }
    }
    
    public var caption: String? {
        // Legacy audios did not support captions
        nil
    }
    
    public var durationTimeInterval: TimeInterval? {
        duration.doubleValue
    }
    
    public func temporaryBlobDataURL() -> URL? {
        guard let audio else {
            return nil
        }
        
        let filename = "v1-audioMessage-\(UUID().uuidString)"
        let fileUtility = FileUtility.shared!
        let url = fileUtility.appTemporaryUnencryptedDirectory.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_AUDIO)"
        )
        
        guard fileUtility.write(contents: audio.data, to: url) else {
            DDLogWarn("Writing audio blob data to temporary file failed.")
            return nil
        }
        
        return url
    }
}
