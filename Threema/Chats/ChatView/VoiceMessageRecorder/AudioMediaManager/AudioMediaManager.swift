import AVFoundation
import CocoaLumberjackSwift
import FileUtility
import ThreemaFramework

final class AudioMediaManager: AudioMediaManagerProtocol {

    static func newRecordingAudioURL() -> URL {
        let fullFileName = "voice_recording_\(DateFormatter.getDateForExport(.now))"
        let url = FileUtility.shared.appTemporaryUnencryptedDirectory
            .appendingPathComponent(fullFileName)
            .appendingPathExtension(MEDIA_EXTENSION_AUDIO)

        DDLogInfo("[Voice Recorder] New audio url: \(url)")
        return url
    }

    static func cleanupFile(_ url: URL) {
        Task(priority: .background) {
            FileUtility.shared.deleteIfExists(at: url)
        }
    }

    static func concatenateRecordingsAndSave(combine urls: [URL], to audioFile: URL) async throws -> AVAsset {
        struct LoadedMetadata: Sendable {
            let index: Int
            let url: URL
            let duration: CMTime
        }

        // Load asset durations in parallel
        let loaded: [LoadedMetadata] = try await withThrowingTaskGroup(of: LoadedMetadata.self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    let asset = AVURLAsset(url: url)
                    let duration = try await asset.load(.duration)
                    return LoadedMetadata(index: index, url: url, duration: duration)
                }
            }
            var result: [LoadedMetadata] = []
            for try await item in group {
                result.append(item)
            }
            return result
        }

        // Restore initial order
        let ordered = loaded.sorted { $0.index < $1.index }

        let composition = AVMutableComposition()

        for item in ordered {
            let asset = AVURLAsset(url: item.url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)

            guard let track = tracks.first else {
                continue
            }

            let timeRange = CMTimeRange(start: .zero, duration: item.duration)

            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }

            try compositionTrack.insertTimeRange(timeRange, of: track, at: composition.duration)
        }

        try await save(composition, to: audioFile)

        for url in urls {
            FileUtility.shared.deleteIfExists(at: url)
        }

        return composition
    }

    static func copy(source: URL, destination: URL) throws {
        do {
            try FileUtility.shared.copy(from: source, to: destination)
        }
        catch {
            throw VoiceMessageError.fileOperationFailed
        }
    }

    static func moveToDocumentsDir(from url: URL) throws -> URL {
        guard let persistentDir = FileUtility.shared.appDocumentsDirectory
        else {
            throw VoiceMessageError.fileOperationFailed
        }

        let newURL = persistentDir.appendingPathComponent(url.lastPathComponent)

        do {
            if !FileUtility.shared.fileExists(at: newURL) {
                try FileUtility.shared.move(from: url, to: newURL)
            }
        }
        catch {
            throw VoiceMessageError.fileOperationFailed
        }

        return newURL
    }

    // MARK: - Private functions

    private static func save(_ asset: AVAsset, to url: URL) async throws {
        // Remove old file
        FileUtility.shared.deleteIfExists(at: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceMessageError.assetNotFound
        }
        exportSession.outputURL = url
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()

        if exportSession.status != .completed {
            assertionFailure()
            DDLogError(
                "[Voice Recorder] ExportSession: \(url.absoluteString), status: \(String(describing: exportSession.status))"
            )
            throw VoiceMessageError.exportFailed
        }
    }
}
