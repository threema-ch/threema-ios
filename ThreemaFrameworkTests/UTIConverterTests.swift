import Testing

@testable import ThreemaFramework

@MainActor
struct UTIConverterSwiftTests {
    typealias sut = UTIConverter

    @Test func utTypeIdentifiers() {
        #expect(UTType.content.identifier == "public.content")
        #expect(UTType.compositeContent.identifier == "public.composite-content")
        #expect(UTType.diskImage.identifier == "public.disk-image")
        #expect(UTType.data.identifier == "public.data")
        #expect(UTType.directory.identifier == "public.directory")
        #expect(UTType.resolvable.identifier == "com.apple.resolvable")
        #expect(UTType.symbolicLink.identifier == "public.symlink")
        #expect(UTType.executable.identifier == "public.executable")
        #expect(UTType.mountPoint.identifier == "com.apple.mount-point")
        #expect(UTType.aliasFile.identifier == "com.apple.alias-file")
        #expect(UTType.urlBookmarkData.identifier == "com.apple.bookmark")
        #expect(UTType.url.identifier == "public.url")
        #expect(UTType.fileURL.identifier == "public.file-url")
        #expect(UTType.text.identifier == "public.text")
        #expect(UTType.plainText.identifier == "public.plain-text")
        #expect(UTType.utf8PlainText.identifier == "public.utf8-plain-text")
        #expect(UTType.utf16ExternalPlainText.identifier == "public.utf16-external-plain-text")
        #expect(UTType.utf16PlainText.identifier == "public.utf16-plain-text")
        #expect(UTType.delimitedText.identifier == "public.delimited-values-text")
        #expect(UTType.commaSeparatedText.identifier == "public.comma-separated-values-text")
        #expect(UTType.tabSeparatedText.identifier == "public.tab-separated-values-text")
        #expect(UTType.utf8TabSeparatedText.identifier == "public.utf8-tab-separated-values-text")
        #expect(UTType.rtf.identifier == "public.rtf")
        #expect(UTType.html.identifier == "public.html")
        #expect(UTType.xml.identifier == "public.xml")
        #expect(UTType.yaml.identifier == "public.yaml")
        if #available(iOS 18.2, *) {
            #expect(UTType.css.identifier == "public.css")
        }
        #expect(UTType.sourceCode.identifier == "public.source-code")
        #expect(UTType.assemblyLanguageSource.identifier == "public.assembly-source")
        #expect(UTType.cSource.identifier == "public.c-source")
        #expect(UTType.objectiveCSource.identifier == "public.objective-c-source")
        #expect(UTType.swiftSource.identifier == "public.swift-source")
        #expect(UTType.cPlusPlusSource.identifier == "public.c-plus-plus-source")
        #expect(UTType.objectiveCPlusPlusSource.identifier == "public.objective-c-plus-plus-source")
        #expect(UTType.cHeader.identifier == "public.c-header")
        #expect(UTType.cPlusPlusHeader.identifier == "public.c-plus-plus-header")
        #expect(UTType.script.identifier == "public.script")
        #expect(UTType.appleScript.identifier == "com.apple.applescript.text")
        #expect(UTType.osaScript.identifier == "com.apple.applescript.script")
        #expect(UTType.osaScriptBundle.identifier == "com.apple.applescript.script-bundle")
        #expect(UTType.javaScript.identifier == "com.netscape.javascript-source")
        #expect(UTType.shellScript.identifier == "public.shell-script")
        #expect(UTType.perlScript.identifier == "public.perl-script")
        #expect(UTType.pythonScript.identifier == "public.python-script")
        #expect(UTType.rubyScript.identifier == "public.ruby-script")
        #expect(UTType.phpScript.identifier == "public.php-script")
        #expect(UTType.makefile.identifier == "public.make-source")
        #expect(UTType.json.identifier == "public.json")
        #expect(UTType.propertyList.identifier == "com.apple.property-list")
        #expect(UTType.xmlPropertyList.identifier == "com.apple.xml-property-list")
        #expect(UTType.binaryPropertyList.identifier == "com.apple.binary-property-list")
        #expect(UTType.pdf.identifier == "com.adobe.pdf")
        #expect(UTType.rtfd.identifier == "com.apple.rtfd")
        #expect(UTType.flatRTFD.identifier == "com.apple.flat-rtfd")
        #expect(UTType.webArchive.identifier == "com.apple.webarchive")
        #expect(UTType.image.identifier == "public.image")
        #expect(UTType.jpeg.identifier == "public.jpeg")
        #expect(UTType.tiff.identifier == "public.tiff")
        #expect(UTType.gif.identifier == "com.compuserve.gif")
        #expect(UTType.png.identifier == "public.png")
        #expect(UTType.icns.identifier == "com.apple.icns")
        #expect(UTType.bmp.identifier == "com.microsoft.bmp")
        #expect(UTType.ico.identifier == "com.microsoft.ico")
        #expect(UTType.rawImage.identifier == "public.camera-raw-image")
        #expect(UTType.svg.identifier == "public.svg-image")
        #expect(UTType.livePhoto.identifier == "com.apple.live-photo")
        #expect(UTType.heif.identifier == "public.heif")
        #expect(UTType.heic.identifier == "public.heic")
        if #available(iOS 18.2, *) {
            #expect(UTType.heics.identifier == "public.heics")
        }
        #expect(UTType.webP.identifier == "org.webmproject.webp")
        if #available(iOS 18.2, *) {
            #expect(UTType.exr.identifier == "com.ilm.openexr-image")
            #expect(UTType.dng.identifier == "com.adobe.raw-image")
            #expect(UTType.jpegxl.identifier == "public.jpeg-xl")
        }
        #expect(UTType.threeDContent.identifier == "public.3d-content")
        #expect(UTType.usd.identifier == "com.pixar.universal-scene-description")
        #expect(UTType.usdz.identifier == "com.pixar.universal-scene-description-mobile")
        #expect(UTType.realityFile.identifier == "com.apple.reality")
        #expect(UTType.sceneKitScene.identifier == "com.apple.scenekit.scene")
        #expect(UTType.arReferenceObject.identifier == "com.apple.arobject")
        #expect(UTType.audiovisualContent.identifier == "public.audiovisual-content")
        #expect(UTType.movie.identifier == "public.movie")
        #expect(UTType.video.identifier == "public.video")
        #expect(UTType.audio.identifier == "public.audio")
        #expect(UTType.quickTimeMovie.identifier == "com.apple.quicktime-movie")
        #expect(UTType.mpeg.identifier == "public.mpeg")
        #expect(UTType.mpeg2Video.identifier == "public.mpeg-2-video")
        #expect(UTType.mpeg2TransportStream.identifier == "public.mpeg-2-transport-stream")
        #expect(UTType.mp3.identifier == "public.mp3")
        #expect(UTType.mpeg4Movie.identifier == "public.mpeg-4")
        #expect(UTType.mpeg4Audio.identifier == "public.mpeg-4-audio")
        #expect(UTType.appleProtectedMPEG4Audio.identifier == "com.apple.protected-mpeg-4-audio")
        #expect(UTType.appleProtectedMPEG4Video.identifier == "com.apple.protected-mpeg-4-video")
        #expect(UTType.avi.identifier == "public.avi")
        #expect(UTType.aiff.identifier == "public.aiff-audio")
        #expect(UTType.wav.identifier == "com.microsoft.waveform-audio")
        #expect(UTType.midi.identifier == "public.midi-audio")
        #expect(UTType.playlist.identifier == "public.playlist")
        #expect(UTType.m3uPlaylist.identifier == "public.m3u-playlist")
        #expect(UTType.folder.identifier == "public.folder")
        #expect(UTType.volume.identifier == "public.volume")
        #expect(UTType.package.identifier == "com.apple.package")
        #expect(UTType.bundle.identifier == "com.apple.bundle")
        #expect(UTType.pluginBundle.identifier == "com.apple.plugin")
        #expect(UTType.spotlightImporter.identifier == "com.apple.metadata-importer")
        #expect(UTType.quickLookGenerator.identifier == "com.apple.quicklook-generator")
        #expect(UTType.xpcService.identifier == "com.apple.xpc-service")
        #expect(UTType.framework.identifier == "com.apple.framework")
        #expect(UTType.application.identifier == "com.apple.application")
        #expect(UTType.applicationBundle.identifier == "com.apple.application-bundle")
        #expect(UTType.applicationExtension.identifier == "com.apple.application-and-system-extension")
        #expect(UTType.unixExecutable.identifier == "public.unix-executable")
        #expect(UTType.exe.identifier == "com.microsoft.windows-executable")
        #expect(UTType.systemPreferencesPane.identifier == "com.apple.systempreference.prefpane")
        #expect(UTType.archive.identifier == "public.archive")
        #expect(UTType.gzip.identifier == "org.gnu.gnu-zip-archive")
        #expect(UTType.bz2.identifier == "public.bzip2-archive")
        #expect(UTType.zip.identifier == "public.zip-archive")
        #expect(UTType.appleArchive.identifier == "com.apple.archive")
        if #available(iOS 18.2, *) {
            #expect(UTType.tarArchive.identifier == "public.tar-archive")
        }
        #expect(UTType.spreadsheet.identifier == "public.spreadsheet")
        #expect(UTType.presentation.identifier == "public.presentation")
        #expect(UTType.database.identifier == "public.database")
        #expect(UTType.message.identifier == "public.message")
        #expect(UTType.contact.identifier == "public.contact")
        #expect(UTType.vCard.identifier == "public.vcard")
        #expect(UTType.toDoItem.identifier == "public.to-do-item")
        #expect(UTType.calendarEvent.identifier == "public.calendar-event")
        #expect(UTType.emailMessage.identifier == "public.email-message")
        #expect(UTType.internetLocation.identifier == "com.apple.internet-location")
        #expect(UTType.internetShortcut.identifier == "com.microsoft.internet-shortcut")
        #expect(UTType.font.identifier == "public.font")
        #expect(UTType.bookmark.identifier == "public.bookmark")
        #expect(UTType.pkcs12.identifier == "com.rsa.pkcs-12")
        #expect(UTType.x509Certificate.identifier == "public.x509-certificate")
        #expect(UTType.epub.identifier == "org.idpf.epub-container")
        #expect(UTType.log.identifier == "public.log")
        #expect(UTType.ahap.identifier == "com.apple.haptics.ahap")
        if #available(iOS 18.2, *) {
            #expect(UTType.geoJSON.identifier == "public.geojson")
            #expect(UTType.linkPresentationMetadata.identifier == "com.apple.linkpresentation.metadata")
        }
    }

    @Test func mimeTypeFromUTI() {
        #expect(sut.mimeType(fromUTI: "") == nil)
        #expect(sut.mimeType(fromUTI: "unknown") == nil)

        #expect(sut.mimeType(fromUTI: UTType.content.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.compositeContent.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.diskImage.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.data.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.directory.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.resolvable.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.symbolicLink.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.executable.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.mountPoint.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.aliasFile.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.urlBookmarkData.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.url.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.fileURL.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.text.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.plainText.identifier) == "text/plain")
        #expect(sut.mimeType(fromUTI: UTType.utf8PlainText.identifier) == "text/plain;charset=utf-8")
        #expect(sut.mimeType(fromUTI: UTType.utf16ExternalPlainText.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.utf16PlainText.identifier) == "text/plain;charset=utf-16")
        #expect(sut.mimeType(fromUTI: UTType.delimitedText.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.commaSeparatedText.identifier) == "text/csv")
        #expect(sut.mimeType(fromUTI: UTType.tabSeparatedText.identifier) == "text/tab-separated-values")
        #expect(sut.mimeType(fromUTI: UTType.utf8TabSeparatedText.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.rtf.identifier) == "text/rtf")
        #expect(sut.mimeType(fromUTI: UTType.html.identifier) == "text/html")
        #expect(sut.mimeType(fromUTI: UTType.xml.identifier) == "application/xml")
        #expect(sut.mimeType(fromUTI: UTType.yaml.identifier) == "application/x-yaml")
        if #available(iOS 18.2, *) {
            #expect(sut.mimeType(fromUTI: UTType.css.identifier) == "text/css")
        }
        #expect(sut.mimeType(fromUTI: UTType.sourceCode.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.assemblyLanguageSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.cSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.objectiveCSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.swiftSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.cPlusPlusSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.objectiveCPlusPlusSource.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.cHeader.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.cPlusPlusHeader.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.script.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.appleScript.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.osaScript.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.osaScriptBundle.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.javaScript.identifier) == "text/javascript")
        #expect(sut.mimeType(fromUTI: UTType.shellScript.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.perlScript.identifier) == "text/x-perl-script")
        #expect(sut.mimeType(fromUTI: UTType.pythonScript.identifier) == "text/x-python-script")
        #expect(sut.mimeType(fromUTI: UTType.rubyScript.identifier) == "text/x-ruby-script")
        #expect(sut.mimeType(fromUTI: UTType.phpScript.identifier) == "text/php")
        #expect(sut.mimeType(fromUTI: UTType.makefile.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.json.identifier) == "application/json")
        #expect(sut.mimeType(fromUTI: UTType.propertyList.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.xmlPropertyList.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.binaryPropertyList.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.pdf.identifier) == "application/pdf")
        #expect(sut.mimeType(fromUTI: UTType.rtfd.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.flatRTFD.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.webArchive.identifier) == "application/x-webarchive")
        #expect(sut.mimeType(fromUTI: UTType.image.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.jpeg.identifier) == "image/jpeg")
        #expect(sut.mimeType(fromUTI: UTType.tiff.identifier) == "image/tiff")
        #expect(sut.mimeType(fromUTI: UTType.gif.identifier) == "image/gif")
        #expect(sut.mimeType(fromUTI: UTType.png.identifier) == "image/png")
        #expect(sut.mimeType(fromUTI: UTType.icns.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.bmp.identifier) == "image/bmp")
        #expect(sut.mimeType(fromUTI: UTType.ico.identifier) == "image/vnd.microsoft.icon")
        #expect(sut.mimeType(fromUTI: UTType.rawImage.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.svg.identifier) == "image/svg+xml")
        #expect(sut.mimeType(fromUTI: UTType.livePhoto.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.heif.identifier) == "image/heif")
        #expect(sut.mimeType(fromUTI: UTType.heic.identifier) == "image/heic")
        if #available(iOS 18.2, *) {
            #expect(sut.mimeType(fromUTI: UTType.heics.identifier) == "image/heic-sequence")
        }
        #expect(sut.mimeType(fromUTI: UTType.webP.identifier) == "image/webp")
        if #available(iOS 18.2, *) {
            #expect(sut.mimeType(fromUTI: UTType.exr.identifier) == nil)
            #expect(sut.mimeType(fromUTI: UTType.dng.identifier) == "image/x-adobe-dng")
            #expect(sut.mimeType(fromUTI: UTType.jpegxl.identifier) == "image/jxl")
        }
        #expect(sut.mimeType(fromUTI: UTType.threeDContent.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.usd.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.usdz.identifier) == "model/vnd.usdz+zip")
        #expect(sut.mimeType(fromUTI: UTType.realityFile.identifier) == "model/vnd.reality")
        #expect(sut.mimeType(fromUTI: UTType.sceneKitScene.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.arReferenceObject.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.audiovisualContent.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.movie.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.video.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.audio.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.quickTimeMovie.identifier) == "video/quicktime")
        #expect(sut.mimeType(fromUTI: UTType.mpeg.identifier) == "video/mpeg")
        #expect(sut.mimeType(fromUTI: UTType.mpeg2Video.identifier) == "video/mpeg2")
        #expect(sut.mimeType(fromUTI: UTType.mpeg2TransportStream.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.mp3.identifier) == "audio/mpeg")
        #expect(sut.mimeType(fromUTI: UTType.mpeg4Movie.identifier) == "video/mp4")
        #expect(sut.mimeType(fromUTI: UTType.mpeg4Audio.identifier) == "audio/mp4")
        #expect(sut.mimeType(fromUTI: UTType.appleProtectedMPEG4Audio.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.appleProtectedMPEG4Video.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.avi.identifier) == "video/avi")
        #expect(sut.mimeType(fromUTI: UTType.aiff.identifier) == "audio/aiff")
        #expect(sut.mimeType(fromUTI: UTType.wav.identifier) == "audio/vnd.wave")
        #expect(sut.mimeType(fromUTI: UTType.midi.identifier) == "audio/midi")
        #expect(sut.mimeType(fromUTI: UTType.playlist.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.m3uPlaylist.identifier) == "audio/mpegurl")
        #expect(sut.mimeType(fromUTI: UTType.folder.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.volume.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.package.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.bundle.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.pluginBundle.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.spotlightImporter.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.quickLookGenerator.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.xpcService.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.framework.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.application.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.applicationBundle.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.applicationExtension.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.unixExecutable.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.exe.identifier) == "application/x-msdownload")
        #expect(sut.mimeType(fromUTI: UTType.systemPreferencesPane.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.archive.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.gzip.identifier) == "application/x-gzip")
        #expect(sut.mimeType(fromUTI: UTType.bz2.identifier) == "application/x-bzip2")
        #expect(sut.mimeType(fromUTI: UTType.zip.identifier) == "application/zip")
        #expect(sut.mimeType(fromUTI: UTType.appleArchive.identifier) == nil)
        if #available(iOS 18.2, *) {
            #expect(sut.mimeType(fromUTI: UTType.tarArchive.identifier) == "application/x-tar")
        }
        #expect(sut.mimeType(fromUTI: UTType.spreadsheet.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.presentation.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.database.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.message.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.contact.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.vCard.identifier) == "text/vcard")
        #expect(sut.mimeType(fromUTI: UTType.toDoItem.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.calendarEvent.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.emailMessage.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.internetLocation.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.internetShortcut.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.font.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.bookmark.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.pkcs12.identifier) == "application/x-pkcs12")
        #expect(sut.mimeType(fromUTI: UTType.x509Certificate.identifier) == "application/x-x509-ca-cert")
        #expect(sut.mimeType(fromUTI: UTType.epub.identifier) == "application/epub+zip")
        #expect(sut.mimeType(fromUTI: UTType.log.identifier) == nil)
        #expect(sut.mimeType(fromUTI: UTType.ahap.identifier) == nil)
        if #available(iOS 18.2, *) {
            #expect(sut.mimeType(fromUTI: UTType.geoJSON.identifier) == "application/geo+json")
            #expect(sut.mimeType(fromUTI: UTType.linkPresentationMetadata.identifier) == nil)
        }
    }

    @Test func utiFromMimeType() {
        // Unknown or empty
        #expect(sut.uti(fromMimeType: "") == nil)
        #expect(sut.uti(fromMimeType: "unknown") == nil)

        // Text
        #expect(sut.uti(fromMimeType: "text/plain") == "public.plain-text")
        #expect(sut.uti(fromMimeType: "text/html") == "public.html")
        #expect(sut.uti(fromMimeType: "text/css") == "public.css")
        #expect(sut.uti(fromMimeType: "text/csv") == "public.comma-separated-values-text")
        #expect(sut.uti(fromMimeType: "text/rtf") == "public.rtf")
        #expect(sut.uti(fromMimeType: "text/vcard") == "public.vcard")

        // Images
        #expect(sut.uti(fromMimeType: "image/jpeg") == "public.jpeg")
        #expect(sut.uti(fromMimeType: "image/png") == "public.png")
        #expect(sut.uti(fromMimeType: "image/gif") == "com.compuserve.gif")
        #expect(sut.uti(fromMimeType: "image/tiff") == "public.tiff")
        #expect(sut.uti(fromMimeType: "image/heic") == "public.heic")
        #expect(sut.uti(fromMimeType: "image/heif") == "public.heif")
        #expect(sut.uti(fromMimeType: "image/webp") == "org.webmproject.webp")
        #expect(sut.uti(fromMimeType: "image/svg+xml") == "public.svg-image")

        // Audio
        #expect(sut.uti(fromMimeType: "audio/mpeg") == "public.mp3")
        #expect(sut.uti(fromMimeType: "audio/wav") == "com.microsoft.waveform-audio")
        #expect(sut.uti(fromMimeType: "audio/aac") == "public.aac-audio")
        #expect(sut.uti(fromMimeType: "audio/flac") == "org.xiph.flac")

        // Video
        #expect(sut.uti(fromMimeType: "video/mp4") == "public.mpeg-4")
        #expect(sut.uti(fromMimeType: "video/quicktime") == "com.apple.quicktime-movie")
        #expect(sut.uti(fromMimeType: "video/x-msvideo") == "public.avi")
        #expect(sut.uti(fromMimeType: "video/mpeg") == "public.mpeg")
        #expect(sut.uti(fromMimeType: "video/webm") == "org.webmproject.webm")

        // Application formats
        #expect(sut.uti(fromMimeType: "application/octet-stream") == "public.data")
        #expect(sut.uti(fromMimeType: "application/json") == "public.json")
        #expect(sut.uti(fromMimeType: "application/xml") == "public.xml")
        #expect(sut.uti(fromMimeType: "application/pdf") == "com.adobe.pdf")
        #expect(sut.uti(fromMimeType: "application/zip") == "public.zip-archive")
        #expect(sut.uti(fromMimeType: "application/gzip") == "org.gnu.gnu-zip-archive")
        #expect(sut.uti(fromMimeType: "application/x-tar") == "public.tar-archive")

        // Office formats
        #expect(sut.uti(fromMimeType: "application/msword") == "com.microsoft.word.doc")
        #expect(
            UTIConverter
                .uti(fromMimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document") ==
                "org.openxmlformats.wordprocessingml.document"
        )

        #expect(sut.uti(fromMimeType: "application/vnd.ms-excel") == "com.microsoft.excel.xls")
        #expect(
            UTIConverter
                .uti(fromMimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") ==
                "org.openxmlformats.spreadsheetml.sheet"
        )

        #expect(sut.uti(fromMimeType: "application/vnd.ms-powerpoint") == "com.microsoft.powerpoint.ppt")
        #expect(
            UTIConverter
                .uti(fromMimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation") ==
                "org.openxmlformats.presentationml.presentation"
        )
    }

    @Test func utiForFileURL() {
        #expect(sut.uti(forFileURL: URL(fileURLWithPath: "test.jpg")) == "public.jpeg")
        #expect(sut.uti(forFileURL: URL(fileURLWithPath: "test.png")) == "public.png")
        #expect(sut.uti(forFileURL: URL(fileURLWithPath: "test.pdf")) == "com.adobe.pdf")

        // Unknown
        #expect(sut.uti(forFileURL: URL(fileURLWithPath: "")) == nil)
        #expect(sut.uti(forFileURL: URL(fileURLWithPath: "unknown")) == nil)
    }

    @Test func preferredFileExtension() {
        #expect(sut.preferredFileExtension(forMimeType: "image/jpeg") == "jpeg")
        #expect(sut.preferredFileExtension(forMimeType: "image/png") == "png")
        #expect(sut.preferredFileExtension(forMimeType: "application/pdf") == "pdf")

        // Unknown
        #expect(sut.preferredFileExtension(forMimeType: "") == nil)
        #expect(sut.preferredFileExtension(forMimeType: "unknown") == nil)
    }

    @Test func isImageMimeType() {
        #expect(sut.isImageMimeType("image/jpeg") == true)
        #expect(sut.isImageMimeType("image/png") == true)
        #expect(sut.isImageMimeType("text/plain") == false)
        #expect(sut.isImageMimeType("") == false)
    }

    @Test func isRenderingImageMimeType() {
        #expect(sut.isRenderingImageMimeType("image/jpeg") == true)
        #expect(sut.isRenderingImageMimeType("image/png") == true)
        #expect(sut.isRenderingImageMimeType("image/gif") == false)
        #expect(sut.isRenderingImageMimeType("") == false)
    }

    @Test func isPNGImageMimeType() {
        #expect(sut.isPNGImageMimeType("image/png") == true)
        #expect(sut.isPNGImageMimeType("image/jpeg") == false)
        #expect(sut.isPNGImageMimeType("") == false)
    }

    @Test func isGifMimeType() {
        #expect(sut.isGifMimeType("image/gif") == true)
        #expect(sut.isGifMimeType("image/png") == false)
        #expect(sut.isGifMimeType("") == false)
    }

    @Test func isAudioMimeType() {
        #expect(sut.isAudioMimeType("audio/mpeg") == true)
        #expect(sut.isAudioMimeType("audio/flac") == true)
        #expect(sut.isAudioMimeType("image/jpeg") == false)
        #expect(sut.isAudioMimeType("") == false)
    }

    @Test func isVideoMimeType() {
        #expect(sut.isVideoMimeType("video/mpeg2") == true)
        #expect(sut.isVideoMimeType("video/mp4") == false)
        #expect(sut.isVideoMimeType("video/mpeg") == false)
        #expect(sut.isVideoMimeType("video/quicktime") == false)
        #expect(sut.isVideoMimeType("image/jpeg") == false)
        #expect(sut.isVideoMimeType("") == false)
    }

    @Test func isMovieMimeType() {
        #expect(sut.isMovieMimeType("video/mpeg2") == true)
        #expect(sut.isMovieMimeType("video/mp4") == true)
        #expect(sut.isMovieMimeType("video/mpeg") == true)
        #expect(sut.isMovieMimeType("video/quicktime") == true)
        #expect(sut.isMovieMimeType("text/plain") == false)
        #expect(sut.isMovieMimeType("") == false)
    }

    @Test func isPDFMimeType() {
        #expect(sut.isPDFMimeType("application/pdf") == true)
        #expect(sut.isPDFMimeType("text/plain") == false)
        #expect(sut.isPDFMimeType("") == false)
    }

    @Test func isContactMimeType() {
        #expect(sut.isContactMimeType("text/vcard") == true)
        #expect(sut.isContactMimeType("application/json") == false)
        #expect(sut.isContactMimeType("") == false)
    }

    @Test func isCalendarMimeType() {
        #expect(sut.isCalendarMimeType("text/calendar") == true)
        #expect(sut.isCalendarMimeType("application/json") == false)
        #expect(sut.isCalendarMimeType("") == false)
    }

    @Test func isArchiveMimeType() {
        #expect(sut.isArchiveMimeType("application/zip") == true)
        #expect(sut.isArchiveMimeType("application/x-gzip") == true)
        #expect(sut.isArchiveMimeType("text/plain") == false)
        #expect(sut.isArchiveMimeType("") == false)
    }

    @Test func isTextMimeType() {
        #expect(sut.isTextMimeType("text/plain") == true)
        #expect(sut.isTextMimeType("text/html") == true)
        #expect(sut.isTextMimeType("image/png") == false)
        #expect(sut.isTextMimeType("") == false)
    }

    @Test func isPassMimeType() {
        #expect(sut.isPassMimeType("application/vnd.apple.pkpass") == true)
        #expect(sut.isPassMimeType("application/vnd.apple.pkpass.apple") == true)
        #expect(sut.isPassMimeType("application/json") == false)
        #expect(sut.isPassMimeType("") == false)
    }

    @Test func isWordMimeType() {
        #expect(sut.isWordMimeType("application/msword") == true)
        #expect(
            UTIConverter
                .isWordMimeType("application/vnd.openxmlformats-officedocument.wordprocessingml.document") == true
        )
        #expect(sut.isWordMimeType("text/plain") == false)
        #expect(sut.isWordMimeType("") == false)
    }

    @Test func isPowerpointMimeType() {
        #expect(sut.isPowerpointMimeType("application/vnd.ms-powerpointtd") == true)
        #expect(
            UTIConverter
                .isPowerpointMimeType("application/vnd.openxmlformats-officedocument.presentationml.presentation") ==
                true
        )
        #expect(sut.isPowerpointMimeType("text/plain") == false)
        #expect(sut.isPowerpointMimeType("") == false)
    }

    @Test func isExcelMimeType() {
        #expect(sut.isExcelMimeType("application/vnd.ms-excel") == true)
        #expect(
            UTIConverter
                .isExcelMimeType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") == true
        )
        #expect(sut.isExcelMimeType("text/plain") == false)
        #expect(sut.isExcelMimeType("") == false)
    }

    @Test func typeConformsTo() {
        #expect(sut.type("public.jpeg", conformsTo: "public.image") == true)
        #expect(sut.type("public.png", conformsTo: "public.image") == true)
        #expect(sut.type("public.jpeg", conformsTo: "public.audio") == false)

        // Invalid identifiers
        #expect(sut.type("invalid.type", conformsTo: "public.image") == false)
        #expect(sut.type("public.jpeg", conformsTo: "invalid.type") == false)

        #expect(sut.type("", conformsTo: "invalid.type") == false)
        #expect(sut.type("public.jpeg", conformsTo: "") == false)
    }

    @Test func conformsToMovieType() {
        #expect(sut.conforms(toMovieType: "public.mpeg-4") == true)
        #expect(sut.conforms(toMovieType: "public.jpeg") == false)
        #expect(sut.conforms(toMovieType: "") == false)
    }

    @Test func conformsToImageType() {
        #expect(sut.conforms(toImageType: "public.jpeg") == true)
        #expect(sut.conforms(toImageType: "public.mpeg-4") == false)
        #expect(sut.conforms(toImageType: "") == false)
    }

    @Test func renderingAudioMimeTypes() {
        let list = sut.renderingAudioMimeTypes()
        #expect(list.contains("audio/aac"))
        #expect(list.contains("audio/aiff"))
        #expect(list.contains("audio/aiff"))
        #expect(list.contains("audio/flac"))
        #expect(list.contains("audio/m4a"))
        #expect(list.contains("audio/mp4"))
        #expect(list.contains("audio/mpeg"))
        #expect(list.contains("audio/mpegurl"))
        #expect(list.contains("audio/vnd.wave"))
        #expect(list.contains("audio/wav"))
        #expect(list.contains("audio/x-m4a"))
    }

    @Test func renderingVideoMimeTypes() {
        let list = sut.renderingVideoMimeTypes()
        #expect(list.contains("video/avi"))
        #expect(list.contains("video/mp4"))
        #expect(list.contains("video/mpeg"))
        #expect(list.contains("video/mpeg2"))
        #expect(list.contains("video/mpeg4"))
        #expect(list.contains("video/quicktime"))
        #expect(list.contains("video/webm"))
        #expect(list.contains("video/x-m4v"))
        #expect(list.contains("video/x-msvideo"))
    }

    @Test(arguments: ["srf", "sr2", "raf", "pef", "orf", "nef", "mrw", "erf", "dng", "dcr", "crw", "cr2", "arw", "raw"])
    func testGetRawImageMimeType(ext: String) {
        let testBundle = Bundle(for: BundleClass.self)
        let rawFilename = "Bild-7"

        guard let testImageURL = testBundle.url(forResource: rawFilename, withExtension: ext) else {
            Issue.record("Expected a valid url for resource \(rawFilename).\(ext)")
            return
        }

        guard let uti = sut.uti(forFileURL: testImageURL) else {
            Issue.record("Expected a valid UTType identifier, got nil instead.")
            return
        }
        guard let mimeType = sut.mimeType(fromUTI: uti) else {
            Issue.record("Expected a mimeType, got nil instead.")
            return
        }

        #expect(
            sut.type(uti, conformsTo: UTType.image.identifier),
            "\(ext) with uti \(String(describing: uti)) should conform to image but does not"
        )

        #expect(
            sut.isImageMimeType(mimeType),
            "\(ext) with mime type \(String(describing: mimeType)) should conform to image"
        )
    }

    @Test func getDefaultThumbnail() {
        test(
            [
                "image/bmp",
                "image/gif",
                "image/heic",
                "image/heic-sequence",
                "image/heif",
                "image/jpeg",
                "image/jxl",
                "image/png",
                "image/svg+xml",
                "image/tiff",
                "image/vnd.microsoft.icon",
                "image/webp",
                "image/x-adobe-dng",
            ],
            BundleUtil.imageNamed("ThumbImageFile"),
            #_sourceLocation
        )

        test(
            [
                "audio/aiff",
                "audio/midi",
                "audio/mp4",
                "audio/mpeg",
                "audio/vnd.wave",
            ],
            BundleUtil.imageNamed("ThumbAudioFile"),
            #_sourceLocation
        )

        test(
            [
                "video/avi",
                "video/mp4",
                "video/mpeg",
                "video/mpeg2",
                "video/quicktime",
            ],
            BundleUtil.imageNamed("ThumbVideoFile"),
            #_sourceLocation
        )

        test(
            ["application/pdf"],
            BundleUtil.imageNamed("ThumbPDF"),
            #_sourceLocation
        )

        test(
            ["text/vcard"],
            BundleUtil.imageNamed("ThumbBusinessContact"),
            #_sourceLocation
        )

        test(
            [
                "application/msword",
                "application/vnd.openxmlformats-officedocument.wordprocessingml",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ],
            BundleUtil.imageNamed("ThumbWord"),
            #_sourceLocation
        )

        test(
            [
                "application/vnd.ms-powerpointtd",
                "application/vnd.openxmlformats-officedocument.presentationml",
                "application/vnd.openxmlformats-officedocument.presentationml.document",
            ],
            BundleUtil.imageNamed("ThumbPowerpoint"),
            #_sourceLocation
        )

        test(
            [
                "application/vnd.ms-excel",
                "application/vnd.openxmlformats-officedocument.spreadsheetml",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.document",
            ],
            BundleUtil.imageNamed("ThumbExcel"),
            #_sourceLocation
        )

        test(
            [
                "application/geo+json",
                "application/json",
                "application/x-yaml",
                "application/xml",
                "audio/mpegurl",
                "text/css",
                "text/csv",
                "text/html",
                "text/javascript",
                "text/php",
                "text/plain",
                "text/plain;charset=utf-16",
                "text/plain;charset=utf-8",
                "text/rtf",
                "text/tab-separated-values",
                "text/x-perl-script",
                "text/x-python-script",
                "text/x-ruby-script",
            ],
            BundleUtil.imageNamed("ThumbDocument"),
            #_sourceLocation
        )

        test(
            [
                "application/x-bzip2",
                "application/x-gzip",
                "application/x-tar",
                "application/zip",
            ],
            BundleUtil.imageNamed("ThumbArchive"),
            #_sourceLocation
        )

        test(
            ["unknown/type"],
            BundleUtil.imageNamed("ThumbFile"), // fallback icon
            #_sourceLocation
        )
    }

    // MARK: - Helpers

    func test(
        _ mimes: [String],
        _ icon: UIImage?,
        _ location: SourceLocation
    ) {
        for mime in mimes {
            #expect(
                sut.getDefaultThumbnail(forMimeType: mime) == icon,
                "Icon for \(mime) should be \(icon.debugDescription)",
                sourceLocation: location
            )
        }
    }
}

private final class BundleClass { }
