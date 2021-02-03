//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2021 Threema GmbH
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
import ThreemaFramework

@objc open class ThreemaImagePickerControllerDefaultUIDelegate: DKImagePickerControllerDefaultUIDelegate, MWPhotoBrowserDelegate {
    
    var photosArray = [MWPhoto]()
    var photoAssets = [DKAsset]()
    open var controller: DKImagePickerController?
    
    override open func imagePickerControllerCollectionViewBackgroundColor() -> UIColor {
        return Colors.background()
    }
    
    override open func imagePickerControllerGlobalTitleColor() -> UIColor? {
        return Colors.main()
    }
    
    override open func createDoneButtonIfNeeded() -> UIButton {
        if self.doneButton == nil {
            self.doneButton = super.createDoneButtonIfNeeded()
            self.doneButton!.removeTarget(self.imagePickerController, action: #selector(DKImagePickerController.done), for: UIControl.Event.touchUpInside)
            self.doneButton!.addTarget(self.imagePickerController, action: #selector(DKImagePickerController.doneWithoutDismiss), for: UIControl.Event.touchUpInside)
        }
        return self.doneButton!
    }

    override open func updateDoneButtonTitle(_ button: UIButton) {
        if self.imagePickerController.selectedAssets.count > 0 {
            button.setTitle(String(format: DKImageLocalizedStringWithKey("select"), self.imagePickerController.selectedAssets.count), for: .normal)
            button.isHidden = false
        } else {
            button.isHidden = true
        }
        
        button.sizeToFit()
    }
    
    @objc func updateButton() {
        updateDoneButtonTitle(self.createDoneButtonIfNeeded())
    }
    
    open override func imagePickerControllerCollectionImageCell() -> DKAssetGroupDetailBaseCell.Type {
        return CustomGroupDetailImageCell.self
    }
    
    open override func imagePickerControllerCollectionVideoCell() -> DKAssetGroupDetailBaseCell.Type {
        return CustomGroupDetailVideoCell.self
    }
    
    open override func imagePickerControllerLongPress(_ imagePickerController: DKImagePickerController, _ selectedRow: Int, _ assets: [DKAsset]) {
        self.controller = imagePickerController
        
        let photoBrowser = MWPhotoBrowser.init(delegate: self)
        photoBrowser?.displayActionButton = false
        photoBrowser?.displayDeleteButton = false
        photoBrowser?.enableGrid = false
        photoBrowser?.enableSwipeToDismiss = true
        photoBrowser?.displaySelectionButtons = true
        photoBrowser?.alwaysShowControls = true
        photoBrowser?.zoomPhotosToFill = false
        photoBrowser?.customImageSelectedIcon = StyleKit.check
        
        photosArray.removeAll()
        photoAssets = assets
        
        for asset:DKAsset in assets {
            let width = UIScreen.main.bounds.size.width * UIScreen.main.scale
            let height = UIScreen.main.bounds.size.height * UIScreen.main.scale
            let photo = MWPhoto(asset: asset.originalAsset, targetSize: CGSize(width: width, height: height))
            self.photosArray.append(photo!)
        }
        
        photoBrowser?.setCurrentPhotoIndex(UInt(selectedRow))
        imagePickerController.pushViewController(photoBrowser!, animated: true)
    }
    
    // MARK: MWPhotoBrowserDelegate
    
    public func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(self.photosArray.count)
    }
    
    open func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        return self.photosArray[Int(index)]
        
    }
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, isPhotoSelectedAt index: UInt) -> Bool {
        if (controller?.selectedAssets.contains(self.photoAssets[Int(index)]))! {
            return true
        }
        return false
    }
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt, selectedChanged selected: Bool) {
        if selected {
            controller?.selectImage(self.photoAssets[Int(index)])
        } else {
            controller?.deselectImage(self.photoAssets[Int(index)])
        }
        controller?.refreshView()
    }
    
    public func mediaSelectionCount() -> UInt {
        if controller != nil {
            return UInt(controller!.selectedAssets.count)
        }
        return 0
    }
}
