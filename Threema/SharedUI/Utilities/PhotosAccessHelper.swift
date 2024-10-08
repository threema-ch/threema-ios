//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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
import Foundation
import MBProgressHUD
import PhotosUI

let tmpDirectory = "tmpImages/"

@objc class PhotosAccessHelper: NSObject {
    
    let completion: ([Any], DKImagePickerController?) -> Void
    weak var pickerController: DKImagePickerController?
    weak var parentViewController: UIViewController?
    
    @objc init(completion: @escaping (([Any], DKImagePickerController?) -> Void)) {
        self.completion = completion
        super.init()
    }
    
    @objc func showPicker(viewController: UIViewController, limit: Int) {
        if !PhotosRightsHelper().haveFullAccess() {
            parentViewController = viewController
            let photoLibrary = PHPhotoLibrary.shared()
            var config = PHPickerConfiguration(photoLibrary: photoLibrary)
            config.selectionLimit = limit
            config.preferredAssetRepresentationMode = .current
            config.selection = .ordered
                
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            viewController.present(picker, animated: true)
            
            return
        }
        
        // Show our custom picker if we have full access
        PHPhotoLibrary.requestAuthorization { _ in
            let assetCollectionView = UITableView.appearance(whenContainedInInstancesOf: [DKImagePickerController.self])
            assetCollectionView.backgroundColor = Colors.backgroundGroupedViewController
            
            DispatchQueue.main.async {
                self.pickerController = self.setupDKImagePickerController(limit: limit)
                guard let pickerController = self.pickerController else {
                    return
                }
                viewController.present(pickerController, animated: true, completion: nil)
            }
        }
    }
    
    @objc func setupDKImagePickerController(limit: Int) -> DKImagePickerController {
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
        
        picker.didSelectAsset = didSelectAsset
        picker.didSelectAssets = didSelectAssets
        
        return picker
    }
    
    func didSelectAsset(picker: DKImagePickerController, asset: DKAsset) {
        if asset.isVideo, asset.originalAsset!
            .duration > (MediaConverter.videoMaxDurationAtCurrentQuality() + 1) * 60 {
            picker.deselectAsset(asset)
            let errorTitle = BundleUtil.localizedString(forKey: "video_too_long_title")
            let errorMessage = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "video_too_long_message"),
                MediaConverter.videoMaxDurationAtCurrentQuality()
            )
            
            UIAlertTemplate.showAlert(owner: picker, title: errorTitle, message: errorMessage)
        }
    }
    
    func didSelectAssets(assets: [DKAsset]) {
        guard let pickerController else {
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
            }
            catch {
                DDLogError("Error \(error.localizedDescription)")
            }
        }
        
        return tmpDirURL
    }
    
    @objc static func storeImageToTmprDir(imageData: UIImage) -> URL {
        let tmpDir = getTempDir()
        let fileName = FileUtility.shared.getTemporarySendableFileName(base: "image")
        let fileURL = tmpDir.appendingPathComponent(fileName + ".jpeg")
        let data = MediaConverter.jpegRepresentation(for: imageData)
        
        do {
            try data?.write(to: fileURL)
        }
        catch {
            DDLogError("Error \(error.localizedDescription)")
        }
        
        return fileURL
    }
    
    @objc static func storePDFToTmpDir(pdfData: Data) -> URL {
        let tmpDir = getTempDir()
        let fileName = FileUtility.shared.getTemporarySendableFileName(base: "Scanned-Documents")
        let fileURL = tmpDir.appendingPathComponent(fileName + ".pdf")
        
        do {
            try pdfData.write(to: fileURL)
        }
        catch {
            DDLogError("Error \(error.localizedDescription)")
        }
        
        return fileURL
    }
}

// MARK: - PHPickerViewControllerDelegate

extension PhotosAccessHelper: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        var hud: MBProgressHUD?
        if let view = parentViewController?.view {
            hud = MBProgressHUD(view: view)
            hud?.graceTime = 0.25
            hud?.mode = .indeterminate
            hud?.label.text = BundleUtil.localizedString(forKey: "loading_files_takes_time_title")
            DispatchQueue.main.async {
                view.addSubview(hud!)
                hud?.show(animated: true)
                picker.dismiss(animated: true)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [(Int, Any)] = []
            let sema = DispatchSemaphore(value: 0)
            
            for (index, result) in results.enumerated() {
                // Looping live photos have three type identifiers, but in iOS 15.5. only the movie identifier can be
                // loaded.
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    DispatchQueue.main.async {
                        hud?.detailsLabel.text = BundleUtil
                            .localizedString(forKey: "loading_files_takes_time_description")
                    }
                    // Unfortunately the progress object returned here immediately shows 100% progress
                    result.itemProvider
                        .loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                            defer { sema.signal() }
                            let item = self.loadVideo(from: url)
                            items.append((index, item))
                            if let error {
                                DDLogError("Could not load item \(error)")
                            }
                        }
                }
                else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    // Unfortunately the progress object returned here immediately shows 100% progress
                    result.itemProvider.loadFileRepresentation(
                        forTypeIdentifier: UTType.image.identifier,
                        completionHandler: { url, error in
                            defer { sema.signal() }
                            let item = self.loadImage(from: url)
                            items.append((index, item))
                            if error != nil {
                                DDLogError("Could not load item \(error!)")
                            }
                        }
                    )
                }
                else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.rawImage.identifier) {
                    // Unfortunately the progress object returned here immediately shows 100% progress
                    result.itemProvider.loadFileRepresentation(
                        forTypeIdentifier: UTType.rawImage.identifier,
                        completionHandler: { url, error in
                            defer { sema.signal() }
                            let item = self.loadImage(from: url)
                            items.append((index, item))
                            if error != nil {
                                DDLogError("Could not load item \(error!)")
                            }
                        }
                    )
                }
                else {
                    DDLogError(
                        "Tried to load item but item had invalid registeredTypeIdentifiers: \(result.itemProvider.registeredTypeIdentifiers)"
                    )
                }
            }
            for _ in results {
                sema.wait()
            }
            
            let sortedItems = items.sorted {
                $0.0 < $1.0
            }
            
            let onlyItems: [Any] = sortedItems.map { _, item in
                item
            }
            
            DispatchQueue.main.async {
                hud?.hide(animated: true)
                self.completion(onlyItems, nil)
            }
        }
    }
    
    func loadVideo(from url: URL?) -> Any {
        guard let url else {
            return PhotosPickerError.fileNotFound
        }
        
        let tmpDirURL = PhotosAccessHelper.getTempDir()
        let fileManager = FileManager.default
        let filename = FileUtility.shared.getTemporarySendableFileName(
            base: "video",
            directoryURL: tmpDirURL,
            pathExtension: url.pathExtension
        )
        
        let newURL = tmpDirURL.appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        
        if !MediaConverter.isVideoDurationValid(at: url) {
            return PhotosPickerError.fileTooLargeForSending
        }
        else {
            do { try fileManager.copyItem(at: url, to: newURL) } catch {
                return PhotosPickerError.fileNotFound
            }
            return newURL
        }
    }
    
    func loadImage(from url: URL?) -> Any {
        guard let url else {
            return PhotosPickerError.fileNotFound
        }
        let tmpDirURL = PhotosAccessHelper.getTempDir()
        let fileManager = FileManager.default
        let filename = FileUtility.shared.getTemporarySendableFileName(
            base: "image",
            directoryURL: tmpDirURL,
            pathExtension: url.pathExtension
        )
        
        let newURL = tmpDirURL.appendingPathComponent(filename).appendingPathExtension(url.pathExtension)
        do { try fileManager.copyItem(at: url, to: newURL) } catch {
            DDLogError("Could not load image \(error)")
            return PhotosPickerError.fileNotFound
        }
        return newURL
    }
}
