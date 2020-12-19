//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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

import Foundation
import CocoaLumberjackSwift
#if compiler(>=5.3)
import PhotosUI
#endif

let tmpDirectory = "tmpImages/"

enum PhotosPickerError : Error {
    case fileNotFound
    case fileTooLarge
    case unknown
}

@objc class PhotosAccessHelper : NSObject {
    
    let completion : (([Any], DKImagePickerController?) -> Void)
    var pickerController : DKImagePickerController?
    
    @objc init(completion : @escaping (([Any], DKImagePickerController?) -> Void)) {
        self.completion = completion
        super.init()
    }
    
    @objc func showPicker(viewController : UIViewController, limit : Int) {
        
        #if compiler(>=5.3)
        if #available(iOS 14, *), !PhotosRightsHelper().haveFullAccess() {
            let photoLibrary = PHPhotoLibrary.shared()
            var config = PHPickerConfiguration(photoLibrary: photoLibrary)
            config.selectionLimit = limit
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            viewController.present(picker, animated: true, completion: nil)
            
            return
        }
        #endif
        
        // Show our custom picker if we have full access or if we are < iOS 14
        PHPhotoLibrary.requestAuthorization({status in
            let assetCollectionView = UITableView.appearance(whenContainedInInstancesOf: [DKImagePickerController.self])
            assetCollectionView.backgroundColor = Colors.background()
            
            DispatchQueue.main.async {
                self.pickerController = self.setupDKImagePickerController(limit: limit)
                guard let pickerController = self.pickerController else {
                    return
                }
                viewController.present(pickerController, animated: true, completion: nil)
            }
            
        })
    }
    
    @objc func setupDKImagePickerController(limit : Int) -> DKImagePickerController {
        let picker = DKImagePickerController()
        picker.assetType = .allAssets
        picker.showsCancelButton = true
        picker.showsEmptyAlbums = false
        picker.allowMultipleTypes = true
        picker.autoDownloadWhenAssetIsInCloud = false
        picker.defaultSelectedAssets = []
        picker.sourceType = .photo
        picker.maxSelectableCount = limit
        picker.UIDelegate = ThreemaImagePickerControllerDefaultUIDelegate()
        picker.allowsLandscape = true
        
        picker.didSelectAsset = self.didSelectAsset
        picker.didSelectAssets = self.didSelectAssets
        
        return picker
    }
    
    func didSelectAsset(picker : DKImagePickerController, asset : DKAsset) {
        if (asset.isVideo && asset.originalAsset!.duration > (MediaConverter.videoMaxDurationAtCurrentQuality() + 1) * 60) {
            picker.deselectAsset(asset)
            let errorTitle = BundleUtil.localizedString(forKey: "video_too_long_title")
            let errorMessage = String(format: BundleUtil.localizedString(forKey: "video_too_long_message"), MediaConverter.videoMaxDurationAtCurrentQuality())
            
            UIAlertTemplate.showAlert(owner: picker, title: errorTitle, message: errorMessage)
        }
    }
    
    func didSelectAssets(assets : [DKAsset]) {
        guard let pickerController = self.pickerController else {
            return
        }
        completion(assets, pickerController)
    }
    
    
    @objc static func cleanTemporaryDirectory() {
        let fileManager = FileManager.default
        let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(tmpDirectory)
        try? fileManager.removeItem(at: tmpDirURL)
    }
    
    @objc static func getTempDir() -> URL {
        let fileManager = FileManager.default
        let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(tmpDirectory)
        
        if !fileManager.fileExists(atPath: tmpDirURL.absoluteString) {
            do {
                try fileManager.createDirectory(at: tmpDirURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DDLogError("Error \(error.localizedDescription)")
            }
        }
        
        return tmpDirURL
    }
    
    @objc static func storeImageToTmprDir(imageData : UIImage) -> URL {
        let tmpDir = self.getTempDir()
        let fileName = FileUtility.getTemporarySendableFileName(base: "image")
        let fileUrl = tmpDir.appendingPathComponent(fileName + ".jpeg")
        let data = imageData.jpegData(compressionQuality: 1.0)
        
        do {
            try data?.write(to: fileUrl)
        } catch {
            DDLogError("Error \(error.localizedDescription)")
        }
        
        return fileUrl
    }
}

#if compiler(>=5.3)
@available(iOS 14, *)
extension PhotosAccessHelper : PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        var photos : [Any] = []
        
        let sema = DispatchSemaphore.init(value: 0)
        
        for result in results {
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier, completionHandler:  { (url, error) in
                    defer { sema.signal() }
                    photos.append(self.loadImage(from: url))
                    if(error != nil) {
                        DDLogError("Could not load item \(error!)")
                    }
                })
            } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler:  { (url, error) in
                    defer { sema.signal() }
                    photos.append(self.loadVideo(from: url))
                    if(error != nil) {
                        DDLogError("Could not load item \(error!)")
                    }
                })
            }
        }
        for _ in results {
            sema.wait()
        }
        picker.dismiss(animated: true, completion: nil)
        completion(photos, nil)
    }
    
    func loadVideo(from url : URL?) -> Any {
        guard let url = url else {
            return PhotosPickerError.fileNotFound
        }
        
        let tmpDirURL = PhotosAccessHelper.getTempDir()
        let fileManager = FileManager.default
        let filename = FileUtility.getTemporarySendableFileName(base: "video", directoryURL: tmpDirURL, pathExtension: url.pathExtension)
        
        let newUrl = tmpDirURL.appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        
        if !MediaConverter.isVideoDurationValid(at: url) {
            return PhotosPickerError.fileTooLarge
        } else {
            do { try fileManager.copyItem(at: url, to: newUrl) } catch {
                return PhotosPickerError.fileNotFound
            }
            return newUrl
        }
    }
    
    func loadImage(from url : URL?) -> Any {
        guard let url = url else {
            return PhotosPickerError.fileNotFound
        }
        let tmpDirURL = PhotosAccessHelper.getTempDir()
        let fileManager = FileManager.default
        let filename = FileUtility.getTemporarySendableFileName(base: "image", directoryURL: tmpDirURL, pathExtension: url.pathExtension)
        
        let newUrl = tmpDirURL.appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        do { try fileManager.copyItem(at: url, to: newUrl) } catch {
            DDLogError("Could not load image \(error)")
            return PhotosPickerError.fileNotFound
        }
        return newUrl
    }
}

#endif
