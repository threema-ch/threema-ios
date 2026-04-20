import CocoaLumberjackSwift
import FileUtility
import ThreemaFramework
import UniformTypeIdentifiers

enum BaseMessageEntityMessageShareContentMapper {
    static func mapToContent(
        from entity: BaseMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        switch entity {

        case let entity as TextMessageEntity:
            makeData(for: entity, fileUtility: fileUtility)

        case let entity as AudioMessageEntity:
            makeData(for: entity, fileUtility: fileUtility)

        case let entity as ImageMessageEntity:
            makeData(for: entity, fileUtility: fileUtility)

        case let entity as VideoMessageEntity:
            makeData(for: entity, fileUtility: fileUtility)

        case let entity as FileMessageEntity:
            makeData(for: entity, fileUtility: fileUtility)

        default:
            nil
        }
    }

    // MARK: - Helpers

    private static func makeData(
        for entity: TextMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        MessageUIActivityItemSource.MessageShareContent(
            type: .text(entity.text),
            dataTypeIdentifier: UTType.plainText.identifier,
            exportURL: tmpShareDirURL(fileUtility: fileUtility)
        )
    }

    private static func makeData(
        for entity: AudioMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        guard let data = entity.audio?.data else {
            DDLogError("No audio data to export")
            return nil
        }
        return MessageUIActivityItemSource.MessageShareContent(
            type: .audio(data),
            dataTypeIdentifier: dataTypeIdentifier(for: entity),
            exportURL: tmpShareDirURL(
                fileUtility: fileUtility
            ).appendingPathExtension(MEDIA_EXTENSION_AUDIO)
        )
    }

    private static func makeData(
        for entity: ImageMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        guard let image = entity.image?.uiImage(),
              let data = image.jpegData(compressionQuality: kJPEGCompressionQualityLow)
        else {
            DDLogError("No image data to export")
            return nil
        }

        return MessageUIActivityItemSource.MessageShareContent(
            type: .image(data),
            dataTypeIdentifier: dataTypeIdentifier(for: entity),
            exportURL: tmpShareDirURL(
                fileUtility: fileUtility
            ).appendingPathExtension(MEDIA_EXTENSION_IMAGE)
        )
    }

    private static func makeData(
        for entity: VideoMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        guard let data = entity.video?.data else {
            DDLogError("No video data to export")
            return nil
        }
        return MessageUIActivityItemSource.MessageShareContent(
            type: .video(data),
            dataTypeIdentifier: dataTypeIdentifier(for: entity),
            exportURL: tmpShareDirURL(
                fileUtility: fileUtility
            ).appendingPathExtension(MEDIA_EXTENSION_VIDEO)
        )
    }

    private static func makeData(
        for entity: FileMessageEntity,
        fileUtility: FileUtilityProtocol
    ) -> MessageUIActivityItemSource.MessageShareContent? {
        guard let data = entity.blobData else {
            DDLogError("No file data to export")
            return nil
        }

        let renderType = entity.type?.intValue ?? 0
        let filename = fileUtility.getTemporaryFileName()
        let exportURL = entity.tempFileURL(fallBackFileName: filename)

        return MessageUIActivityItemSource.MessageShareContent(
            type: .file(data, renderType: renderType),
            dataTypeIdentifier: dataTypeIdentifier(for: entity),
            exportURL: exportURL
        )
    }

    private static func tmpShareDirURL(fileUtility: FileUtilityProtocol) -> URL {
        fileUtility.appTemporaryUnencryptedDirectory.appendingPathComponent(SHARE_FILE_PREFIX)
    }

    private static func dataTypeIdentifier(for entity: BaseMessageEntity) -> String {
        (entity as? BlobData)?.blobUTTypeIdentifier ?? UTType.data.identifier // Generic fallback
    }
}
