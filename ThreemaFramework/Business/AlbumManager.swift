//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
    
    public struct SaveMediaItem {
        let url: URL
        let type: PHAssetResourceType
        let filename: String
    }
    
    static let albumName = "Threema Media"
    
    @objc public static let shared = AlbumManager()
    
    override private init() {
        super.init()
    }
    
    // MARK: - Public Functions
    
    /// Tries to save media to the Photos app on device. Requests for access if not yet granted.
    /// - Parameter item: SaveMediaItem created from ThumbnailDisplayMessage to be saved
    public func save(_ item: SaveMediaItem, showNotifications: Bool = true, autosave: Bool = false) {
        
        defer {
            FileUtility.shared.delete(at: item.url)
        }
        
        // Check access, requests if not yet granted
        let accessType = PhotosRightsHelper.checkAccessAllowed(rightsHelper: PhotosRightsHelper())
        
        guard accessType != .none else {
            DDLogNotice("[AlbumManager] Insufficient permissions to save media to photos.")
            
            if showNotifications {
                NotificationPresenterWrapper.shared.present(type: .saveToPhotosError)
            }
            if autosave {
                NotificationPresenterWrapper.shared.present(type: .autosaveMediaError)
            }
            
            return
        }
        
        // If we can load the Threema Album we save the media there, else we just save to photos
        if let threemaMediaCollection = threemaMediaCollection() {
            DDLogNotice("[AlbumManager] Saving to Threema Media album.")
            saveToAlbum(
                item,
                collection: threemaMediaCollection,
                showNotifications: showNotifications,
                autosave: autosave
            )
        }
        else {
            DDLogNotice("[AlbumManager] Threema Media album could not be fetched/created. Saving to default photos.")
            saveToPhotos(item, showNotifications: showNotifications, autosave: autosave)
        }
    }
    
    // MARK: - Private Functions
    
    /// Save to Threema Media album
    private func saveToAlbum(
        _ item: SaveMediaItem,
        collection: PHAssetCollection,
        showNotifications: Bool,
        autosave: Bool = false
    ) {
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                // Create asset creation request with options
                let assetCreationRequest = self.phAssetCreationRequest(for: item)
                
                // Create collection change request
                let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: collection)
                
                guard let assetCollectionChangeRequest,
                      let placeholderAsset = assetCreationRequest.placeholderForCreatedAsset else {
                    return
                }
                
                // Save
                assetCollectionChangeRequest.addAssets([placeholderAsset] as NSFastEnumeration)
            }
            
            if showNotifications {
                NotificationPresenterWrapper.shared.present(type: .saveToPhotosSuccess)
            }
            
            DDLogNotice("[AlbumManager] Media saved to Threema Media album.")
        }
        catch {
            if showNotifications {
                NotificationPresenterWrapper.shared.present(type: .saveToPhotosError)
            }
            if autosave {
                NotificationPresenterWrapper.shared.present(type: .autosaveMediaError)
            }
            
            DDLogError(
                "[AlbumManager] Could not save media to Threema Media album. Error: \(error.localizedDescription)"
            )
        }
    }
    
    /// Save to general photos
    private func saveToPhotos(_ item: SaveMediaItem, showNotifications: Bool, autosave: Bool = false) {
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                self.phAssetCreationRequest(for: item)
            }
            
            if showNotifications {
                NotificationPresenterWrapper.shared.present(type: .saveToPhotosSuccess)
            }
            
            DDLogNotice("[AlbumManager] Media saved to general photos.")
        }
        catch {
            if showNotifications {
                NotificationPresenterWrapper.shared.present(type: .saveToPhotosError)
            }
            if autosave {
                NotificationPresenterWrapper.shared.present(type: .autosaveMediaError)
            }
            
            DDLogError(
                "[AlbumManager] Could not save media to general photos. Error: \(error.localizedDescription)"
            )
        }
    }
    
    @discardableResult
    private func phAssetCreationRequest(for item: SaveMediaItem) -> PHAssetCreationRequest {
        // Create asset creation request with options
        let assetCreationRequest = PHAssetCreationRequest.forAsset()
        
        let options = PHAssetResourceCreationOptions()

        options.originalFilename = item.filename
        options.shouldMoveFile = true
        
        assetCreationRequest.addResource(with: item.type, fileURL: item.url, options: options)
        return assetCreationRequest
    }
    
    // MARK: - Collection
    
    /// Retrieve, or create the Threema Media collection, returns nil if we do not have permissions
    private func threemaMediaCollection() -> PHAssetCollection? {
        // We first try to fetch the album, if not found we create it
        
        // Fetch
        if let collection = loadExistingThreemaMediaCollection() {
            return collection
        }
        
        // Not found, create
        if let collection = createThreemaMediaCollection() {
            return collection
        }
        
        // We do not have full photos access permission
        return nil
    }
    
    private func loadExistingThreemaMediaCollection() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", AlbumManager.albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        // If there is our Album, we return it
        if let foundAlbum = collection.firstObject {
            return foundAlbum
        }
        
        DDLogNotice("[AlbumManager] Threema Media album not found.")
        return nil
    }
    
    private func createThreemaMediaCollection() -> PHAssetCollection? {
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: AlbumManager.albumName)
            }
            
            DDLogNotice("[AlbumManager] Threema Media album created.")
            return loadExistingThreemaMediaCollection()
        }
        catch {
            // Normally we do not have full photos permissions if this happens
            DDLogError(
                "[AlbumManager] Could not create Threema Media album in photos. Error: \(error.localizedDescription)"
            )
            return nil
        }
    }
    
    // MARK: - Deprecated

    let successMessage = "[AlbumManager] Successfully saved image to Camera Roll."
    let permissionNotGrantedMessage = "[AlbumManager] Permission to save images not granted"
    let writeErrorMessage = "[AlbumManager] Error writing to image library:"
    let generalError = "[AlbumManager] Could not create error message"
    
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
    
    @available(*, deprecated, message: "Use `saveMediaItem(_ item: SaveMediaItem)` instead")
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
    
    @available(*, deprecated, message: "Use `saveMediaItem(_ item: SaveMediaItem)` instead")
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
    
    @available(*, deprecated, message: "Use `saveMediaItem(_ item: SaveMediaItem)` instead")
    @objc public func save(url: URL, isVideo: Bool, completionHandler: @escaping ((_ success: Bool) -> Void)) {
        func saveIt(_ validAssets: PHAssetCollection) {
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest: PHAssetChangeRequest? =
                    if isVideo == true {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    }
                    else {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
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
    
    @available(*, deprecated, message: "Use `saveMediaItem(_ item: SaveMediaItem)` instead")
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
    
    @available(*, deprecated, message: "Use `saveMediaItem(_ item: SaveMediaItem)` instead")
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
