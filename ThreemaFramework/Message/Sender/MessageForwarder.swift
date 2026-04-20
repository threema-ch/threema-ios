import CocoaLumberjackSwift
import CoreLocation
import Foundation

@MainActor
public final class MessageForwarder {

    // MARK: - Public types

    public enum AdditionalContent {
        case caption(String)
        case text(String)
    }

    private let businessInjector = BusinessInjector.ui

    // MARK: - Lifecycle

    public init() { }
    
    // MARK: - Forwarding

    /// Forwards a given base message to a conversation and adds additional text as caption or additional text message.
    /// - Parameters:
    ///   - message: Base message to be forwarded.
    ///   - conversation: ConversationEntity which message should be forwarded to.
    ///   - additionalContent: Additional content to be send as caption or as normal text message.
    ///
    ///   - Note: Caption content can only be sent for for file messages.
    public func forward(
        _ message: BaseMessageEntity,
        to conversation: ConversationEntity,
        sendAsFile: Bool,
        additionalContent: MessageForwarder.AdditionalContent?,
    ) {
        switch message {
        case let textMessage as TextMessageEntity:
            Task {
                await businessInjector.messageSender.sendTextMessage(containing: textMessage.text, in: conversation)
                if case let .text(additionalText) = additionalContent {
                    await businessInjector.messageSender.sendTextMessage(containing: additionalText, in: conversation)
                }
            }

        case let locationMessage as LocationMessageEntity:
            Task {
                let coordinates = CLLocationCoordinate2DMake(
                    locationMessage.latitude.doubleValue,
                    locationMessage.longitude.doubleValue
                )
                let accuracy = locationMessage.accuracy?.doubleValue ?? 0.0

                await businessInjector.messageSender.sendLocationMessage(
                    coordinates: coordinates,
                    accuracy: accuracy,
                    poiName: locationMessage.poiName,
                    poiAddress: locationMessage.poiAddress,
                    in: conversation
                )

                if case let .text(additionalText) = additionalContent {
                    await businessInjector.messageSender.sendTextMessage(containing: additionalText, in: conversation)
                }
            }

        case let fileMessage as FileMessageEntity:
            
            guard let item = URLSenderItem(
                data: fileMessage.data?.data,
                fileName: fileMessage.fileName,
                type: fileMessage.blobUTTypeIdentifier,
                renderType: sendAsFile ? 0 : fileMessage.type,
                sendAsFile: sendAsFile
            ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }

            if case let .caption(caption) = additionalContent {
                item.caption = caption
            }

            if let duration = fileMessage.duration {
                item.duration = duration as NSNumber
            }
            
            Task {
                do {
                    try await businessInjector.messageSender.sendBlobMessage(for: item, in: conversation.objectID)
                    if case let .text(additionalText) = additionalContent {
                        await businessInjector.messageSender.sendTextMessage(
                            containing: additionalText,
                            in: conversation
                        )
                    }
                }
                catch {
                    DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                }
            }

        case let audioMessage as AudioMessageEntity:
            guard let audioDataEntity = audioMessage.audio,
                  let item = URLSenderItem(
                      data: audioDataEntity.data,
                      fileName: audioDataEntity.getFilename(),
                      type: UTType.audio.identifier,
                      renderType: sendAsFile ? 0 : 1,
                      sendAsFile: sendAsFile
                  ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            Task {
                do {
                    try await businessInjector.messageSender.sendBlobMessage(for: item, in: conversation.objectID)
                    if case let .text(additionalText) = additionalContent {
                        await businessInjector.messageSender.sendTextMessage(
                            containing: additionalText,
                            in: conversation
                        )
                    }
                }
                catch {
                    DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                }
            }

        case let imageMessage as ImageMessageEntity:
            guard let image = imageMessage.image,
                  let item = URLSenderItem(
                      data: image.data,
                      fileName: image.getFilename(),
                      type: imageMessage.blobUTTypeIdentifier,
                      renderType: sendAsFile ? 0 : 1,
                      sendAsFile: sendAsFile
                  ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if case let .caption(caption) = additionalContent {
                item.caption = caption
            }

            Task {
                do {
                    try await businessInjector.messageSender.sendBlobMessage(for: item, in: conversation.objectID)
                    if case let .text(additionalText) = additionalContent {
                        await businessInjector.messageSender.sendTextMessage(
                            containing: additionalText,
                            in: conversation
                        )
                    }
                }
                catch {
                    DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                }
            }
            
        case let videoMessage as VideoMessageEntity:
            guard let video = videoMessage.video,
                  let item = URLSenderItem(
                      data: video.data,
                      fileName: video.getFilename(),
                      type: videoMessage.blobUTTypeIdentifier,
                      renderType: sendAsFile ? 0 : 1,
                      sendAsFile: sendAsFile
                  ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if case let .caption(caption) = additionalContent {
                item.caption = caption
            }

            Task {
                do {
                    try await businessInjector.messageSender.sendBlobMessage(for: item, in: conversation.objectID)
                    if case let .text(additionalText) = additionalContent {
                        await businessInjector.messageSender.sendTextMessage(
                            containing: additionalText,
                            in: conversation
                        )
                    }
                }
                catch {
                    DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                }
            }
            
        default:
            DDLogError("[MessageForwarder] Unsupported message type received.")
        }
    }
}
