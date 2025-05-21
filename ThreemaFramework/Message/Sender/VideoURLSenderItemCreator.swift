//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

import CocoaLumberjackSwift
import PromiseKit
import UIKit

enum VideoURLSenderItemCreatorError: Error {
    case thumbnailCreationFailed
    case couldNotCreateExportSession
    case generalError
}

@objc protocol VideoConversionProgressDelegate {
    @objc func videoExportSession(exportSession: AVAssetExportSession)
}

@objc public class VideoURLSenderItemCreator: NSObject {
    
    @objc public static let temporaryDirectory = "tmpVideoCreator"
    
    @objc var encodeProgressDelegate: VideoConversionProgressDelegate?
    @objc var exportSession: AVAssetExportSession?
    
    var timer: Timer? = nil
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
            let outputURL = MediaConverter.getAssetOutputURL()
            
            guard let exportSession = MediaConverter.getAVAssetExportSession(from: asset, outputURL: outputURL) else {
                DDLogError("Could not get exportSession for asset \(asset.debugDescription)")
                seal.reject(VideoURLSenderItemCreatorError.couldNotCreateExportSession)
                return
            }
            
            self.exportSession = exportSession
            
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    
                    guard let progress = self.exportSession?.progress else {
                        timer.invalidate()
                        return
                    }
                    
                    self.encodeProgressDelegate?.videoExportSession(exportSession: exportSession)

                    if progress > 0.9 {
                        timer.invalidate()
                    }
                }
            }
            
            seal.fulfill(exportSession)
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
    
    @objc public func getExportSession(for asset: AVAsset) -> AVAssetExportSession? {
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
    
    @objc public func senderItem(from videoURL: URL) -> URLSenderItem? {
        guard let scheme = videoURL.scheme else {
            return nil
        }
        if scheme != "file", !FileManager.default.fileExists(atPath: videoURL.absoluteString) {
            return nil
        }
        
        let asset = AVURLAsset(url: videoURL)
        if !asset.isExportable {
            return nil
        }
        return senderItem(fromAsset: asset)
    }
    
    @objc public func senderItem(fromAsset: AVAsset) -> URLSenderItem? {
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
    
    @objc func senderItem(from asset: AVAsset, on exportSession: AVAssetExportSession) -> URLSenderItem? {
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
    
    @objc public static func writeToTemporaryDirectory(data: Data) -> URL? {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        let tmpFolder = tmpDirectory.appendingPathComponent(VideoURLSenderItemCreator.temporaryDirectory)
        let fileName = SwiftUtils.pseudoRandomString(length: 10)
        let fileURL = tmpFolder.appendingPathComponent(fileName).appendingPathExtension("mp4")
        
        do {
            try fileManager.createDirectory(at: tmpFolder, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            DDLogError("Could not create temporary directory \(error)")
            return nil
        }
        
        do {
            try data.write(to: fileURL)
        }
        catch {
            DDLogError("Could not write file \(error)")
            return nil
        }
        
        return fileURL
    }
    
    @objc public static func cleanTemporaryDirectory() -> Bool {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        let tmpFolder = tmpDirectory.appendingPathComponent(VideoURLSenderItemCreator.temporaryDirectory)
        do {
            if fileManager.fileExists(atPath: tmpFolder.absoluteString) {
                try fileManager.removeItem(at: tmpFolder)
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
