import Foundation
import ThreemaFramework

final class ThreemaImagePickerControllerDefaultUIDelegate: DKImagePickerControllerDefaultUIDelegate,
    MWPhotoBrowserDelegate {
    
    var photosArray = [MWPhoto]()
    var photoAssets = [DKAsset]()
    public var controller: DKImagePickerController?
    
    override public func imagePickerControllerCollectionViewBackgroundColor() -> UIColor {
        Colors.backgroundViewController
    }
    
    override public func imagePickerControllerGlobalTitleColor() -> UIColor? {
        .tintColor
    }
    
    override public func createDoneButtonIfNeeded() -> UIButton {
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

    override public func updateDoneButtonTitle(_ button: UIButton) {
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
    
    func updateButton() {
        updateDoneButtonTitle(createDoneButtonIfNeeded())
    }
    
    override public func imagePickerControllerCollectionImageCell() -> DKAssetGroupDetailBaseCell.Type {
        CustomGroupDetailImageCell.self
    }
    
    override public func imagePickerControllerCollectionVideoCell() -> DKAssetGroupDetailBaseCell.Type {
        CustomGroupDetailVideoCell.self
    }
    
    override public func imagePickerControllerLongPress(
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
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
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
    
    public func photoBrowser(_ photoBrowser: MWPhotoBrowser!, objectIDAt index: UInt) -> NSManagedObjectID? {
        nil
    }
    
    public func mediaSelectionCount() -> UInt {
        if controller != nil {
            return UInt(controller!.selectedAssets.count)
        }
        return 0
    }
}
