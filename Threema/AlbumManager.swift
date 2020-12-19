//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

import Photos
import UIKit
import CocoaLumberjackSwift

@objc class AlbumManager: NSObject {
    static let albumName = "Threema Media"
    let successMessage = "Successfully saved image to Camera Roll."
    let permissionNotGrantedMessage = "Permission to save images not granted"
    let writeErrorMessage = "Error writing to image library:"
    let generalError = "Could not create error message"
    
    @objc static let shared = AlbumManager()
    
    private var assetCollection: PHAssetCollection!
    
    private override init() {
        super.init()
        
        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
            return
        }
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
    
    @objc func save_ori(image: UIImage) {
        self.checkAuthorizationWithHandler { (authorizationState) in
            if authorizationState == .full, self.assetCollection != nil {
                PHPhotoLibrary.shared().performChanges({
                    let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    guard let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset else {
                        DDLogError("Could not create placeholder")
                        return
                    }
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                    
                }, completionHandler: { (success, error) in
                    if success {
                        DDLogNotice(self.successMessage)
                    } else {
                        guard let err = error else {
                            DDLogError(self.generalError)
                            return
                        }
                        DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                    }
                })
            } else if authorizationState == .write || authorizationState == .potentialWrite {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.savedImage), nil)
            } else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
    
    @objc func savedImage(_ im:UIImage, error:Error?, context:UnsafeMutableRawPointer?) {
        if ((error) != nil) {
            guard let err = error else {
                DDLogError(self.generalError)
                return
            }
            DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
        } else {
            DDLogNotice(successMessage)
        }
    }
    
    @objc func save(image: UIImage) {
        func saveIt(_ validAssets: PHAssetCollection){
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset {
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
            }, completionHandler: { (success, error) in
                if success {
                    DDLogNotice(self.successMessage)
                } else {
                    guard let err = error else {
                        DDLogError(self.generalError)
                        return
                    }
                    DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                }
            })
        }
        self.checkAuthorizationWithHandler { (authorizationState) in
            if authorizationState == .full {
                if let validAssets = self.assetCollection { // Album already exists
                    saveIt(validAssets)
                } else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: AlbumManager.albumName)   // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            self.assetCollection = validAssets
                            saveIt(validAssets)
                        } else {
                            DDLogError(self.writeErrorMessage + " \(error!.localizedDescription)")
                        }
                    }
                }
            } else if authorizationState == .write || authorizationState == .potentialWrite {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.savedImage), nil)
            } else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
    
    @objc func save(url: URL, isVideo: Bool, completionHandler: @escaping ((_ success: Bool) -> Void)) {
        func saveIt(_ validAssets: PHAssetCollection){
            PHPhotoLibrary.shared().performChanges({
                var assetChangeRequest: PHAssetChangeRequest? = nil
                if isVideo == true {
                    assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else {
                    assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
                
                if let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset {
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                }
            }, completionHandler: { (success, error) in
                if success {
                    DDLogNotice(self.successMessage)
                    completionHandler(true)
                } else {
                    guard let err = error else {
                        DDLogError(self.generalError)
                        return
                    }
                    DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                    completionHandler(false)
                }
            })
        }
        self.checkAuthorizationWithHandler { (authorizationState) in
            if authorizationState == .full {
                if let validAssets = self.assetCollection { // Album already exists
                    saveIt(validAssets)
                } else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: AlbumManager.albumName)   // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            self.assetCollection = validAssets
                            saveIt(validAssets)
                        } else {
                            guard let err = error else {
                                DDLogError(self.generalError)
                                return
                            }
                            DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                        }
                    }
                }
            } else if authorizationState == .write || authorizationState == .potentialWrite {
                if isVideo {
                    self.saveMovieFromURL(movieURL: url)
                } else {
                    guard let data = try? Data(contentsOf: url) else {
                        DDLogError(self.writeErrorMessage)
                        return
                    }
                    let image = UIImage(data: data)!
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.savedImage), nil)
                }
            } else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
    
    @objc func saveMovieFromURL(movieURL: URL) {
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(movieURL.absoluteString) {
            UISaveVideoAtPathToSavedPhotosAlbum(movieURL.absoluteString, self, #selector(self.savedImage), nil)
        }
    }
    
    @objc func saveMovieToLibrary(movieURL: URL, completionHandler: @escaping ((_ success: Bool) -> Void)) {
        func saveIt(_ validAssets: PHAssetCollection){
            PHPhotoLibrary.shared().performChanges({
                
                if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL) {
                    guard let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset else {
                        DDLogError("Could not create placeholder")
                        return
                    }
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection) {
                        let enumeration: NSArray = [assetPlaceHolder]
                        albumChangeRequest.addAssets(enumeration)
                    }
                    
                }
                
            }, completionHandler:  { (success, error) in
                if success {
                    completionHandler(true)
                    DDLogNotice("Successfully saved video to Camera Roll.")
                } else {
                    completionHandler(false)
                    DDLogError("Error writing to movie library: \(error!.localizedDescription)")
                }
            })
        }
        self.checkAuthorizationWithHandler { (authorizationState) in
            if authorizationState == .full {
                if let validAssets = self.assetCollection { // Album already exists
                    saveIt(validAssets)
                } else {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: AlbumManager.albumName)   // create an asset collection with the album name
                    }) { success, error in
                        if success, let validAssets = self.fetchAssetCollectionForAlbum() {
                            self.assetCollection = validAssets
                            saveIt(validAssets)
                        } else {
                            guard let err = error else {
                                DDLogError(self.generalError)
                                return
                            }
                            DDLogError(self.writeErrorMessage + "\(err.localizedDescription)")
                        }
                    }
                }
            } else if authorizationState == .write || authorizationState == .potentialWrite {
                self.saveMovieFromURL(movieURL: movieURL)
            } else {
                DDLogNotice(self.permissionNotGrantedMessage)
            }
        }
    }
}
