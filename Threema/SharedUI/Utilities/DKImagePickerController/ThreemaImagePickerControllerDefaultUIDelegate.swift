//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2022 Threema GmbH
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

@objc open class ThreemaImagePickerControllerDefaultUIDelegate: DKImagePickerControllerDefaultUIDelegate,
    MWPhotoBrowserDelegate {
    
    var photosArray = [MWPhoto]()
    var photoAssets = [DKAsset]()
    open var controller: DKImagePickerController?
    
    override open func imagePickerControllerCollectionViewBackgroundColor() -> UIColor {
        Colors.backgroundViewController
    }
    
    override open func imagePickerControllerGlobalTitleColor() -> UIColor? {
        Colors.primary
    }
    
    override open func createDoneButtonIfNeeded() -> UIButton {
        if doneButton == nil {
            doneButton = super.createDoneButtonIfNeeded()
            doneButton!.removeTarget(
                imagePickerController,
                action: #selector(DKImagePickerController.done),
                for: UIControl.Event.touchUpInside
            )
            doneButton!.addTarget(
                imagePickerController,
                action: #selector(DKImagePickerController.doneWithoutDismiss),
                for: UIControl.Event.touchUpInside
            )
        }
        return doneButton!
    }

    override open func updateDoneButtonTitle(_ button: UIButton) {
        if !imagePickerController.selectedAssets.isEmpty {
            button.setTitle(
                String.localizedStringWithFormat(
                    DKImageLocalizedStringWithKey("select"),
                    imagePickerController.selectedAssets.count
                ),
                for: .normal
            )
            button.isHidden = false
        }
        else {
            button.isHidden = true
        }
        
        button.sizeToFit()
    }
    
    @objc func updateButton() {
        updateDoneButtonTitle(createDoneButtonIfNeeded())
    }
    
    override open func imagePickerControllerCollectionImageCell() -> DKAssetGroupDetailBaseCell.Type {
        CustomGroupDetailImageCell.self
    }
    
    override open func imagePickerControllerCollectionVideoCell() -> DKAssetGroupDetailBaseCell.Type {
        CustomGroupDetailVideoCell.self
    }
    
    override open func imagePickerControllerLongPress(
        _ imagePickerController: DKImagePickerController,
        _ selectedRow: Int,
        _ assets: [DKAsset]
    ) {
        controller = imagePickerController
        
        let photoBrowser = MWPhotoBrowser(delegate: self)
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
        
        for asset: DKAsset in assets {
            let width = UIScreen.main.bounds.size.width * UIScreen.main.scale
            let height = UIScreen.main.bounds.size.height * UIScreen.main.scale
            let photo = MWPhoto(asset: asset.originalAsset, targetSize: CGSize(width: width, height: height))
            photosArray.append(photo!)
        }
        
        photoBrowser?.setCurrentPhotoIndex(UInt(selectedRow))
        imagePickerController.pushViewController(photoBrowser!, animated: true)
    }
    
    // MARK: MWPhotoBrowserDelegate
    
    public func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        UInt(photosArray.count)
    }
    
    open func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        photosArray[Int(index)]
    }
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, isPhotoSelectedAt index: UInt) -> Bool {
        if (controller?.selectedAssets.contains(photoAssets[Int(index)]))! {
            return true
        }
        return false
    }
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt, selectedChanged selected: Bool) {
        if selected {
            controller?.selectImage(photoAssets[Int(index)])
        }
        else {
            controller?.deselectImage(photoAssets[Int(index)])
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
