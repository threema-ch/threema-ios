import CocoaLumberjackSwift

@objcMembers
public final class UTIConverter: NSObject {
    
    public static func mimeType(fromUTI uti: String) -> String? {
        UTType(uti)?.preferredMIMEType
    }

    public static func uti(fromMimeType mimeType: String) -> String? {
        UTType(mimeType: mimeType)?.identifier
    }

    public static func uti(forFileURL url: URL) -> String? {
        UTType(filenameExtension: url.pathExtension)?.identifier
    }

    public static func preferredFileExtension(forMimeType mimeType: String) -> String? {
        UTType(mimeType: mimeType)?.preferredFilenameExtension
    }

    public static func isImageMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .image) ?? false
    }

    public static func isRenderingImageMimeType(_ mimeType: String) -> Bool {
        guard let type = UTType(mimeType: mimeType) else {
            return false
        }
        return type.conforms(to: .jpeg) || type.conforms(to: .png)
    }

    public static func isPNGImageMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .png) ?? false
    }

    public static func isGifMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .gif) ?? false
    }

    public static func isAudioMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .audio) ?? false
    }

    public static func isRenderingAudioMimeType(_ mimeType: String) -> Bool {
        renderingAudioMimeTypes().contains(mimeType)
    }

    public static func isVideoMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .video) ?? false
    }

    public static func isMovieMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .movie) ?? false
    }

    public static func isRenderingVideoMimeType(_ mimeType: String) -> Bool {
        renderingVideoMimeTypes().contains(mimeType)
    }

    public static func isPDFMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .pdf) ?? false
    }

    public static func isContactMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .contact) ?? false
    }

    public static func isCalendarMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .calendarEvent) ?? false
    }

    public static func isArchiveMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .archive) ?? false
    }

    public static func isTextMimeType(_ mimeType: String) -> Bool {
        UTType(mimeType: mimeType)?.conforms(to: .text) ?? false
    }

    public static func isPassMimeType(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("application/vnd.apple.pkpass")
    }

    public static func isWordMimeType(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("application/vnd.openxmlformats-officedocument.wordprocessingml")
            || mimeType == "application/msword"
    }

    public static func isPowerpointMimeType(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("application/vnd.openxmlformats-officedocument.presentationml")
            || mimeType == "application/vnd.ms-powerpointtd"
    }

    public static func isExcelMimeType(_ mimeType: String) -> Bool {
        mimeType.hasPrefix("application/vnd.openxmlformats-officedocument.spreadsheetml")
            || mimeType == "application/vnd.ms-excel"
    }

    public static func type(_ type: String, conformsTo referenceType: String) -> Bool {
        guard
            let typeUTI = UTType(type), let refUTI = UTType(referenceType)
        else {
            return false
        }
        return typeUTI.conforms(to: refUTI)
    }

    public static func conforms(toMovieType identifier: String) -> Bool {
        type(identifier, conformsTo: UTType.movie.identifier)
    }

    public static func conforms(toImageType identifier: String) -> Bool {
        type(identifier, conformsTo: UTType.image.identifier)
    }

    public static func getDefaultThumbnail(forMimeType mimeType: String) -> UIImage {
        let rules: [(check: (String) -> Bool, name: String)] = [
            (isImageMimeType, "ThumbImageFile"),
            (isAudioMimeType, "ThumbAudioFile"),
            (isVideoMimeType, "ThumbVideoFile"),
            (isMovieMimeType, "ThumbVideoFile"),
            (isPDFMimeType, "ThumbPDF"),
            (isContactMimeType, "ThumbBusinessContact"),
            (isCalendarMimeType, "ThumbCalendar"),
            (isWordMimeType, "ThumbWord"),
            (isPowerpointMimeType, "ThumbPowerpoint"),
            (isExcelMimeType, "ThumbExcel"),
            (isTextMimeType, "ThumbDocument"),
            (isArchiveMimeType, "ThumbArchive"),
        ]

        let imageName = rules.first { $0.check(mimeType) }?.name ?? "ThumbFile"

        guard let image = BundleUtil.imageNamed(imageName) else {
            let message = "Error: image not found. Using system image fallback."
            DDLogError("\(message)")
            assertionFailure(message)
            let fallback = UIImage(systemName: "square") ?? UIImage()
            return fallback
        }

        return image
    }

    public static func renderingAudioMimeTypes() -> [String] {
        [
            "audio/aac",
            "audio/aiff",
            "audio/flac",
            "audio/m4a",
            "audio/mp4",
            "audio/mpeg",
            "audio/mpegurl",
            "audio/vnd.wave",
            "audio/wav",
            "audio/x-m4a",
        ]
    }

    public static func renderingVideoMimeTypes() -> [String] {
        [
            "video/avi",
            "video/mp4",
            "video/mpeg",
            "video/mpeg2",
            "video/mpeg4",
            "video/quicktime",
            "video/webm",
            "video/x-m4v",
            "video/x-msvideo",
        ]
    }
}
