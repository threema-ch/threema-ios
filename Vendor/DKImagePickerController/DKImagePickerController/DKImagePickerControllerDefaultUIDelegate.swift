// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  DKImagePickerControllerDefaultUIDelegate.swift
//  DKImagePickerControllerDemo
//
//  Created by ZhangAo on 16/3/7.
//  Copyright © 2016年 ZhangAo. All rights reserved.
//

import UIKit

@objc
open class DKImagePickerControllerDefaultUIDelegate: NSObject, DKImagePickerControllerUIDelegate {
	
	open weak var imagePickerController: DKImagePickerController!
	
	open var doneButton: UIButton?
	
	open func createDoneButtonIfNeeded() -> UIButton {
        if self.doneButton == nil {
            let button = UIButton(type: UIButton.ButtonType.custom)
            button.setTitleColor(UINavigationBar.appearance().tintColor ?? self.imagePickerController.navigationBar.tintColor, for: .normal)
            button.addTarget(self.imagePickerController, action: #selector(DKImagePickerController.done), for: UIControl.Event.touchUpInside)
            button.isAccessibilityElement = true
            self.doneButton = button
            self.updateDoneButtonTitle(button)
        }
		
		return self.doneButton!
	}
    
    open func updateDoneButtonTitle(_ button: UIButton) {
        /***** BEGIN THREEMA MODIFICATION: Add accessibilityLabel to done button *********/
        if self.imagePickerController.selectedAssets.count > 0 {
            let title = String.localizedStringWithFormat(
                DKImageLocalizedStringWithKey("select"),
                self.imagePickerController.selectedAssets.count
            )
            button.setTitle(title, for: .normal)
            button.accessibilityLabel = title
        } else {
            button.setTitle(DKImageLocalizedStringWithKey("done"), for: .normal)
            button.accessibilityLabel = DKImageLocalizedStringWithKey("done")
        }
        /***** END THREEMA MODIFICATION: Add accessibilityLabel to done button *********/
        
        button.sizeToFit()
    }
	
	// Delegate methods...
	
	open func prepareLayout(_ imagePickerController: DKImagePickerController, vc: UIViewController) {
		self.imagePickerController = imagePickerController
		vc.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.createDoneButtonIfNeeded())
	}
        
    open func imagePickerControllerCreateCamera(_ imagePickerController: DKImagePickerController) -> UIViewController {
        let camera = DKImagePickerControllerCamera()
        
        self.checkCameraPermission(camera)
        
        return camera
    }
	
	open func layoutForImagePickerController(_ imagePickerController: DKImagePickerController) -> UICollectionViewLayout.Type {
		return DKAssetGroupGridLayout.self
	}
	
	open func imagePickerController(_ imagePickerController: DKImagePickerController,
	                                  showsCancelButtonForVC vc: UIViewController) {
		vc.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
		                                                      target: imagePickerController,
                                                              action: #selector(imagePickerController.dismiss as () -> Void))
	}
	
	open func imagePickerController(_ imagePickerController: DKImagePickerController,
	                                  hidesCancelButtonForVC vc: UIViewController) {
		vc.navigationItem.leftBarButtonItem = nil
	}
    
    open func imagePickerController(_ imagePickerController: DKImagePickerController, willSelectAssets: [DKAsset]) -> Bool {
        return true
    }
    
    /***** BEGIN THREEMA MODIFICATION: function to check video size *********/
    open func imagePickerController(_ imagePickerController: DKImagePickerController, didSelectAsset: DKAsset) {
        self.updateDoneButtonTitle(self.createDoneButtonIfNeeded())
    }
    /***** END THREEMA MODIFICATION: function to check video size *********/
    
    open func imagePickerController(_ imagePickerController: DKImagePickerController, didSelectAssets: [DKAsset]) {
        self.updateDoneButtonTitle(self.createDoneButtonIfNeeded())
    }
	    
    open func imagePickerController(_ imagePickerController: DKImagePickerController, didDeselectAssets: [DKAsset]) {
        self.updateDoneButtonTitle(self.createDoneButtonIfNeeded())
    }
	
	open func imagePickerControllerDidReachMaxLimit(_ imagePickerController: DKImagePickerController) {
        /***** BEGIN THREEMA MODIFICATION: add gesture recognizer *********/
        UIAlertTemplate.showAlert(
            owner: imagePickerController,
            title: DKImageLocalizedStringWithKey("maxLimitReached"),
            message: String.localizedStringWithFormat(
                DKImageLocalizedStringWithKey("maxLimitReachedMessage"),
                imagePickerController.maxSelectableCount
            )
        )
        /***** END THREEMA MODIFICATION: add gesture recognizer *********/
	}
	
	open func imagePickerControllerFooterView(_ imagePickerController: DKImagePickerController) -> UIView? {
		return nil
	}
    
    open func imagePickerControllerCollectionViewBackgroundColor() -> UIColor {
        return UIColor.white
    }
    
    open func imagePickerControllerCollectionImageCell() -> DKAssetGroupDetailBaseCell.Type {
        return DKAssetGroupDetailImageCell.self
    }
    
    open func imagePickerControllerCollectionCameraCell() -> DKAssetGroupDetailBaseCell.Type {
        return DKAssetGroupDetailCameraCell.self
    }
    
    open func imagePickerControllerCollectionVideoCell() -> DKAssetGroupDetailBaseCell.Type {
        return DKAssetGroupDetailVideoCell.self
    }
    
    open func imagePickerControllerGlobalTitleColor() -> UIColor? {
        return UINavigationBar.appearance().titleTextAttributes?[NSAttributedString.Key.foregroundColor] as? UIColor
    }
    
    open func imagePickerControllerGlobalTitleFont() -> UIFont? {
        return UINavigationBar.appearance().titleTextAttributes?[NSAttributedString.Key.font] as? UIFont
    }
    
    open func imagePickerControllerAssetGroupListBackgroundColor() -> UIColor? {
        return .white
    }
    
    open func imagePickerControllerAssetGroupListCellBackgroundColor() -> UIColor? {
        return .white
    }
    
    open func imagePickerControllerAssetGroupListCellTitleColor() -> UIColor? {
        return .black
    }
    
    open func imagePickerControllerAssetGroupListCellSubTitleColor() -> UIColor? {
        return .gray
    }
    
    open func imagePickerControllerAssetGroupListCellTickImage() -> UIImage? {
        return nil
    }
    
    /***** BEGIN THREEMA MODIFICATION: add gesture recognizer *********/
    open func imagePickerControllerLongPress(_ imagePickerController: DKImagePickerController, _ selectedRow: Int, _ assets: [DKAsset]) {
        // do nothing
    }
    /***** END THREEMA MODIFICATION: add gesture recognizer *********/

	
	// Internal
	
	public func checkCameraPermission(_ camera: DKCamera) {
		func cameraDenied() {
			DispatchQueue.main.async {
				let permissionView = DKPermissionView.permissionView(.camera)
				camera.cameraOverlayView = permissionView
			}
		}
		
		func setup() {
			camera.cameraOverlayView = nil
		}
		
		DKCamera.checkCameraPermission { granted in
			granted ? setup() : cameraDenied()
		}
	}
		
}

@objc
open class DKImagePickerControllerCamera: DKCamera, DKImagePickerControllerCameraProtocol {
    
    open func setDidFinishCapturingVideo(block: @escaping (URL) -> Void) {
        
    }

    open func setDidFinishCapturingImage(block: @escaping (UIImage) -> Void) {
        super.didFinishCapturingImage = block
    }

    open func setDidCancel(block: @escaping () -> Void) {
        super.didCancel = block
    }
    
}
