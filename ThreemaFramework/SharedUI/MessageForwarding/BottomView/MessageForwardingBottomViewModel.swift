import Foundation
import Observation
import ThreemaMacros

@MainActor @Observable
final class MessageForwardingBottomViewModel {
    
    // MARK: - Public types
    
    enum ForwardType {
        case text(String)
        case location(symbol: String?, description: String)
        case data(symbol: String?, description: String, thumbnail: Data?, caption: String?)
    }

    enum ForwardError: Error, LocalizedError {
        case unknownMessage

        var errorDescription: String? {
            switch self {
            case .unknownMessage:
                #localize("message_forwarding_error_message_unknown_type")
            }
        }
    }

    // MARK: - Public properties
    
    let forwardingLabel = #localize("message_forwarding_input_heading")
    let placeholderLabel = #localize("message_forwarding_input_placeholder")
    let sendAsFileLabel = #localize("send_as_file")
    var forwardType = ForwardType.text("")
    var isSendingAsFile = false
    var isForwardingCaption = true
    
    var hasAdditionalText: Bool {
        !additionalText.isEmpty
    }

    // MARK: - Private properties
    
    /// Forwarded message
    private let message: BaseMessageEntity

    /// Current text field additional message to send along forwarded message
    private var additionalText = ""

    // MARK: - Lifecycle
    
    init(message: BaseMessageEntity) throws {
        self.message = message
        self.forwardType = try determineForwardType()
    }
    
    // MARK: - Public methods

    func updateAdditionalText(_ text: String) {
        additionalText = text
    }

    func getAdditionalContent() -> MessageForwarder.AdditionalContent? {
        if isForwardingCaption, case let .data(_, _, _, caption) = forwardType, let caption {
            MessageForwarder.AdditionalContent.caption(caption)
        }
        else if additionalText.isEmpty {
            nil
        }
        else {
            .text(additionalText)
        }
    }

    // MARK: - Private methods

    private func determineForwardType() throws -> ForwardType {
        if let forwardType = processTextMessage()
            ?? processLocationMessage()
            ?? processLegacyMessages()
            ?? processFileMessage() {
            return forwardType
        }
        throw ForwardError.unknownMessage
    }

    private func processTextMessage() -> ForwardType? {
        guard let message = message as? any(TextMessageEntity & PreviewableMessage) else {
            return nil
        }
        return .text(message.previewText)
    }

    private func processLocationMessage() -> ForwardType? {
        guard let message = message as? any(LocationMessageEntity & PreviewableMessage) else {
            return nil
        }
        return .location(symbol: message.previewSymbolName ?? "", description: message.previewText)
    }

    private func processLegacyMessages() -> ForwardType? {
        if let message = message as? AudioMessageEntity {
            let fileMessageType = FileMessageType.voice(message)
            return .data(
                symbol: fileMessageType.symbolName,
                description: fileMessageType.localizedDescription,
                thumbnail: message.blobThumbnail,
                caption: message.caption
            )
        }
        else if let message = message as? ImageMessageEntity {
            let fileMessageType = FileMessageType.image(message)
            return .data(
                symbol: fileMessageType.symbolName,
                description: fileMessageType.localizedDescription,
                thumbnail: message.blobThumbnail,
                caption: message.caption
            )
        }
        else if let message = message as? VideoMessageEntity {
            let fileMessageType = FileMessageType.video(message)
            return .data(
                symbol: fileMessageType.symbolName,
                description: fileMessageType.localizedDescription,
                thumbnail: message.blobThumbnail,
                caption: message.caption
            )
        }
        else {
            return nil
        }
    }

    private func processFileMessage() -> ForwardType? {
        guard let provider = message as? any(FileMessageProvider & PreviewableMessage) else {
            return nil
        }

        let symbol = provider.previewSymbolName ?? ""
        let description = provider.fileMessageType.localizedDescription
        let thumbnail: Data?
        let caption: String?

        switch provider.fileMessageType {

        case let .image(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .sticker(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .animatedImage(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .animatedSticker(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .video(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .voice(data):
            thumbnail = data.blobThumbnail
            caption = data.caption

        case let .file(data):
            thumbnail = data.blobThumbnail
            caption = data.caption
        }

        return .data(
            symbol: symbol,
            description: description,
            thumbnail: thumbnail,
            caption: caption
        )
    }
}
