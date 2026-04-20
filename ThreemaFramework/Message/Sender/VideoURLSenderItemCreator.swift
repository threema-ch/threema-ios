import CocoaLumberjackSwift
import FileUtility
import PromiseKit
import UIKit

enum VideoURLSenderItemCreatorError: Error {
    case thumbnailCreationFailed
    case couldNotCreateExportSession
    case generalError
}

public protocol VideoConversionProgressDelegate {
    func videoExportSession(exportSession: AVAssetExportSession)
}

public final class VideoURLSenderItemCreator: NSObject {
    
    public static let temporaryDirectory = "tmpVideoCreator"
    
    public var encodeProgressDelegate: VideoConversionProgressDelegate?
    var exportSession: AVAssetExportSession?
    var timer: Timer? = nil

    private let videoConversionHelper: VideoConversionHelper

    @objc override public init() {
        self.videoConversionHelper = VideoConversionHelper()
    }

    #if DEBUG
        init(videoConversionHelper: VideoConversionHelper) {
            self.videoConversionHelper = videoConversionHelper
        }
    #endif

    func getThumbnail(asset: AVAsset) -> Promise<UIImage> {
        Promise { seal in
            guard let thumbnail = MediaConverter.getThumbnailForVideo(asset) else {
                seal.reject(VideoURLSenderItemCreatorError.thumbnailCreationFailed)
                return
            }
            seal.resolve(thumbnail, nil)
        }
    }

    func getExportSession(asset: AVAsset) -> Promise<AVAssetExportSession> {
        Promise { seal in
            guard let outputURL = MediaConverter.getAssetOutputURL() else {
                DDLogError("Could not get output URL for asset \(asset.debugDescription)")
                seal.reject(VideoURLSenderItemCreatorError.couldNotCreateExportSession)
                return
            }

            Task {
                guard let session = await self.videoConversionHelper
                    .getAVAssetExportSession(from: asset, outputURL: outputURL)
                else {
                    seal.reject(VideoURLSenderItemCreatorError.couldNotCreateExportSession)
                    return
                }

                self.exportSession = session

                DispatchQueue.main.async {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                        guard let progress = self.exportSession?.progress else {
                            timer.invalidate()
                            return
                        }

                        self.encodeProgressDelegate?.videoExportSession(exportSession: session)

                        if progress > 0.9 {
                            timer.invalidate()
                        }
                    }
                }

                seal.fulfill(session)
            }
        }
    }

    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if let exportSession = object as? AVAssetExportSession {
            encodeProgressDelegate?.videoExportSession(exportSession: exportSession)
        }
    }
    
    public func getExportSession(for asset: AVAsset) -> AVAssetExportSession? {
        var newExportSession: AVAssetExportSession?
        let sema = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.getExportSession(asset: asset).done { session in
                newExportSession = session
                sema.signal()
            }.catch { error in
                sema.signal()
                DDLogError("Encountered an error: \(error)")
            }
        }
        sema.wait()
        return newExportSession
    }
    
    func convertVideo(asset: AVAsset) -> Promise<URL> {
        getExportSession(asset: asset).then { exportSession in
            self.convertVideo(on: exportSession, asset: asset)
        }
    }
    
    func convertVideo(on exportSession: AVAssetExportSession, asset: AVAsset) -> Promise<URL> {
        self.exportSession = exportSession
        return Promise { seal in
            MediaConverter.convertVideo(with: exportSession, onCompletion: { completionURL in
                guard let url = completionURL else {
                    seal.reject(VideoURLSenderItemCreatorError.generalError)
                    return
                }
                return seal.fulfill(url)
            }, onError: { completionError in
                guard let error = completionError else {
                    seal.reject(VideoURLSenderItemCreatorError.generalError)
                    return
                }
                seal.reject(error)
            })
        }
    }
    
    public func senderItem(from asset: AVAsset) -> Promise<URLSenderItem> {
        let bgq = DispatchQueue.global(qos: .userInitiated)
        
        return getExportSession(asset: asset).then(on: bgq) { exportSession in
            self.convertVideo(on: exportSession, asset: asset)
        }.compactMap(on: bgq) { url in
            URLSenderItem(url: url, type: UTType.mpeg4Movie.identifier, renderType: 1, sendAsFile: true)
        }
    }
    
    public func senderItem(from videoURL: URL) -> URLSenderItem? {
        guard videoURL.scheme == "file" else {
            return nil
        }
        
        guard FileUtility.shared.fileExists(at: videoURL) == true else {
            return nil
        }

        let asset = AVURLAsset(url: videoURL)
        
        guard asset.loadIsExportableSynchronously() else {
            return nil
        }
        
        return senderItem(fromAsset: asset)
    }
    
    public func senderItem(fromAsset: AVAsset) -> URLSenderItem? {
        var senderItem: URLSenderItem?
        let sema = DispatchSemaphore(value: 0)
        let bgq = DispatchQueue.global(qos: .userInitiated)
        
        firstly {
            self.senderItem(from: fromAsset)
        }.done(on: bgq) { item in
            senderItem = item
            sema.signal()
        }.catch { error in
            DDLogError("Error: \(error)")
        }

        sema.wait()
        return senderItem
    }
    
    public func senderItem(from asset: AVAsset, on exportSession: AVAssetExportSession) -> URLSenderItem? {
        var senderItem: URLSenderItem?
        let sema = DispatchSemaphore(value: 0)
        
        firstly {
            self.convertVideo(on: exportSession, asset: asset)
        }.done { (url: URL) in
            senderItem = URLSenderItem(
                url: url,
                type: UTType.mpeg4Movie.identifier,
                renderType: 1,
                sendAsFile: true
            )
            sema.signal()
        }.catch { error in
            sema.signal()
            DDLogError("Error: \(error)")
        }
        
        sema.wait()
        
        return senderItem
    }
    
    public static func writeToTemporaryDirectory(data: Data) -> URL? {
        let fileUtility = FileUtility.shared!
        let tmpFolder = fileUtility.appTemporaryUnencryptedDirectory
            .appendingPathComponent(VideoURLSenderItemCreator.temporaryDirectory)
        let fileName = SwiftUtils.pseudoRandomString(length: 10)
        let fileURL = tmpFolder.appendingPathComponent(fileName).appendingPathExtension("mp4")
        
        do {
            try fileUtility.mkDir(
                at: tmpFolder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        catch {
            DDLogError("Could not create temporary directory \(error)")
            return nil
        }
        
        guard fileUtility.write(contents: data, to: fileURL) else {
            DDLogError("Could not write video file to temporary directory.")
            return nil
        }
        
        return fileURL
    }
    
    public static func cleanTemporaryDirectory() -> Bool {
        let fileUtility = FileUtility.shared!
        let tmpFolder = fileUtility.appTemporaryDirectory
            .appendingPathComponent(VideoURLSenderItemCreator.temporaryDirectory)
        do {
            if fileUtility.fileExists(at: tmpFolder) {
                try fileUtility.delete(at: tmpFolder)
            }
        }
        catch {
            DDLogError("Could not clean temporary directory \(error)")
            return false
        }
        return true
    }
    
    /// Returns a pseudorandom string
    /// - Parameter length: the length of the returned String
    /// - Returns: A pseudorandom string of the given length
    private static func pseudoRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
