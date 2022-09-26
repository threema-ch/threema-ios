//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import Photos
import UIKit

@objc public class AlbumManager: NSObject {
    static let albumName = "Threema Media"
    let successMessage = "Successfully saved image to Camera Roll."
    let permissionNotGrantedMessage = "Permission to save images not granted"
    let writeErrorMessage = "Error writing to image library:"
    let generalError = "Could not create error message"
    
    @objc public static let shared = AlbumManager()
    
    override private init() {
        super.init()
    }
    
    private func checkAuthorizationWithHandler(completion: @escaping ((_ authorizationState: PhotosRights) -> Void)) {
        let accessAllowed = PhotosRightsHelper.checkAccessAllowed(rightsHelper: PhotosRightsHelper())
        completion(accessAllowed)
    }
    
    private func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", AlbumManager.albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let _: AnyObject = collection.firstObject {
            return collection.firstObject
        }
        return nil
    }
    
    @objc func savedImage(_ im: UIImage, error: Error?, context: UnsafeMutableRawPointer?) {
        if error != nil {
            guard let err = error else {
                DDLogError(generalError)
                return
            }
            DDLogError(writeErrorMessage + "\(err.localizedDescription)")
        }
        else {
            DDLogNotice(successMessage)
        }
    }
    
    @objc public func save(image: UIImage) {
        func saveIt(_ validAssets: PHAssetCollection) {
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset {
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: validAssets) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
            }, completionHandler: { success, error in
                if success {
                    DDLogNotice(self.successMessage)
                }
                else {
                    guard let err = error else {
                        DDLogError(self.generalError)
                        return
                    }
                    DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                }
            })
        }
        checkAuthorizationWithHandler { authorizationState in
            if authorizationState == .full {
                if let validAssets = self.fetchAssetCollectionForAlbum() { // Album already exists
                    saveIt(validAssets)
                }
                else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest
                            .creationRequestForAssetCollection(
                                withTitle: AlbumManager
                                    .albumName
                            ) // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            saveIt(validAssets)
                        }
                        else {
                            DDLogError(self.writeErrorMessage + " \(error!.localizedDescription)")
                        }
                    }
                }
            }
            else if authorizationState == .write || authorizationState == .potentialWrite {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.savedImage), nil)
            }
            else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
    
    @objc public func save(url: URL, isVideo: Bool, completionHandler: @escaping ((_ success: Bool) -> Void)) {
        func saveIt(_ validAssets: PHAssetCollection) {
            PHPhotoLibrary.shared().performChanges({
                var assetChangeRequest: PHAssetChangeRequest?
                if isVideo == true {
                    assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                else {
                    assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
                
                if let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset {
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: validAssets) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
            }, completionHandler: { success, error in
                if success {
                    DDLogNotice(self.successMessage)
                    completionHandler(true)
                }
                else {
                    guard let err = error else {
                        DDLogError(self.generalError)
                        return
                    }
                    DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                    completionHandler(false)
                }
            })
        }
        checkAuthorizationWithHandler { authorizationState in
            if authorizationState == .full {
                if let validAssets = self.fetchAssetCollectionForAlbum() { // Album already exists
                    saveIt(validAssets)
                }
                else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest
                            .creationRequestForAssetCollection(
                                withTitle: AlbumManager
                                    .albumName
                            ) // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            saveIt(validAssets)
                        }
                        else {
                            guard let err = error else {
                                DDLogError(self.generalError)
                                return
                            }
                            DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                        }
                    }
                }
            }
            else if authorizationState == .write || authorizationState == .potentialWrite {
                if isVideo {
                    self.saveMovieFromURL(movieURL: url)
                }
                else {
                    guard let data = try? Data(contentsOf: url) else {
                        DDLogError(self.writeErrorMessage)
                        return
                    }
                    let image = UIImage(data: data)!
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.savedImage), nil)
                }
            }
            else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
    
    @objc func saveMovieFromURL(movieURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
        }) { success, error in
            if success {
                DDLogInfo(self.successMessage)
            }
            else {
                guard let err = error else {
                    DDLogError(self.generalError)
                    return
                }
                DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
            }
        }
    }
    
    @objc public func saveMovieToLibrary(movieURL: URL, completionHandler: @escaping ((_ success: Bool) -> Void)) {
        func saveIt(_ validAssets: PHAssetCollection) {
            PHPhotoLibrary.shared().performChanges({
                
                if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL) {
                    guard let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset else {
                        DDLogError("Could not create placeholder")
                        return
                    }
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: validAssets) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
                
            }, completionHandler: { success, error in
                if success {
                    completionHandler(true)
                    DDLogNotice("Successfully saved video to Camera Roll.")
                }
                else {
                    completionHandler(false)
                    DDLogError("Error writing to movie library: \(error!.localizedDescription)")
                }
            })
        }
        checkAuthorizationWithHandler { authorizationState in
            if authorizationState == .full {
                if let validAssets = self.fetchAssetCollectionForAlbum() { // Album already exists
                    saveIt(validAssets)
                }
                else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest
                            .creationRequestForAssetCollection(
                                withTitle: AlbumManager
                                    .albumName
                            ) // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            saveIt(validAssets)
                        }
                        else {
                            guard let err = error else {
                                DDLogError(self.generalError)
                                return
                            }
                            DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                        }
                    }
                }
            }
            else if authorizationState == .write || authorizationState == .potentialWrite {
                self.saveMovieFromURL(movieURL: movieURL)
            }
            else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
}
