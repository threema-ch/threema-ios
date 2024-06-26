// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  DKAssetGroupDetailVC.swift
//  DKImagePickerController
//
//  Created by ZhangAo on 15/8/10.
//  Copyright (c) 2015年 ZhangAo. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

private extension UICollectionView {
    
    func indexPathsForElements(in rect: CGRect, _ hidesCamera: Bool) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        
        if hidesCamera {
            return allLayoutAttributes.map { $0.indexPath }
        } else {
            return allLayoutAttributes.compactMap { $0.indexPath.item == 0 ? nil : IndexPath(item: $0.indexPath.item - 1, section: $0.indexPath.section) }
        }
    }
    
}

// Show all images in the asset group
open class DKAssetGroupDetailVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, DKGroupDataManagerObserver {
    	
    public lazy var selectGroupButton: UIButton = {
        let button = UIButton()
		
        let globalTitleColor = self.imagePickerController.UIDelegate.imagePickerControllerGlobalTitleColor()
		button.setTitleColor(globalTitleColor ?? UIColor.black, for: .normal)
		
        let globalTitleFont = self.imagePickerController.UIDelegate.imagePickerControllerGlobalTitleFont()
		button.titleLabel!.font = globalTitleFont ?? UIFont.boldSystemFont(ofSize: 18.0)
		
		button.addTarget(self, action: #selector(DKAssetGroupDetailVC.showGroupSelector), for: .touchUpInside)
        return button
    }()
		
    internal var collectionView: UICollectionView!
    internal weak var imagePickerController: DKImagePickerController!
    public var selectedGroupId: String?
	private var groupListVC: DKAssetGroupListVC!
    private var hidesCamera: Bool = false
	private var footerView: UIView?
    private var currentViewSize: CGSize!
    private var registeredCellIdentifiers = Set<String>()
    private var thumbnailSize = CGSize.zero
	
	override open func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		if let currentViewSize = self.currentViewSize, currentViewSize.equalTo(self.view.bounds.size) {
			return
		} else {
			currentViewSize = self.view.bounds.size
		}

		self.collectionView?.collectionViewLayout.invalidateLayout()
	}
    
    override open func viewDidLoad() {
        super.viewDidLoad()
		
		let layout = self.imagePickerController.UIDelegate.layoutForImagePickerController(self.imagePickerController).init()
		self.collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        self.collectionView.backgroundColor = self.imagePickerController.UIDelegate.imagePickerControllerCollectionViewBackgroundColor()
        self.collectionView.allowsMultipleSelection = true
		self.collectionView.delegate = self
		self.collectionView.dataSource = self
		self.view.addSubview(self.collectionView)
		
		self.footerView = self.imagePickerController.UIDelegate.imagePickerControllerFooterView(self.imagePickerController)
		if let footerView = self.footerView {
			self.view.addSubview(footerView)
		}
        		
		self.hidesCamera = self.imagePickerController.sourceType == .photo
		self.checkPhotoPermission()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updateCachedAssets()
    }
	
	override open func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		if let footerView = self.footerView {
			footerView.frame = CGRect(x: 0, y: self.view.bounds.height - footerView.bounds.height, width: self.view.bounds.width, height: footerView.bounds.height)
			self.collectionView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - footerView.bounds.height)
			
		} else {
			self.collectionView.frame = self.view.bounds
		}
	}
	
	internal func checkPhotoPermission() {
		func photoDenied() {
			self.view.addSubview(DKPermissionView.permissionView(.photo))
			self.view.backgroundColor = UIColor.black
			self.collectionView?.isHidden = true
		}
		
		func setup() {
            self.resetCachedAssets()
			getImageManager().groupDataManager.addObserver(self)
			self.groupListVC = DKAssetGroupListVC(selectedGroupDidChangeBlock: { [unowned self] groupId in
				self.selectAssetGroup(groupId)
                }, imagePickerController: self.imagePickerController)
			self.groupListVC.loadGroups()
		}
		
		DKImageManager.checkPhotoPermission { granted in
			granted ? setup() : photoDenied()
		}
	}
	
    func selectAssetGroup(_ groupId: String?) {
        if self.selectedGroupId == groupId {
            self.updateTitleView()
            return
        }
        
        self.selectedGroupId = groupId
		self.updateTitleView()
        
        /***** BEGIN THREEMA MODIFICATION: add reload data *********/
        let group = getImageManager().groupDataManager.fetchGroupWithGroupId(self.selectedGroupId!)
        if ((group.momentsResult != nil) && !group.momentsLoaded) {
            groupListVC.showLoadingForMoments()
            
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.main.async {
                    getImageManager().groupDataManager.loadMomentsGroup(group, completion: { [weak self] in
                        self?.groupListVC.hideLoadingForMoments()
                        group.momentsLoaded = true
                        self?.collectionView?.reloadData()
                    })
                }
            }
        } else {
            self.collectionView?.reloadData()
        }
        /***** END THREEMA MODIFICATION: add reload data *********/
    }
	
	open func updateTitleView() {
		let group = getImageManager().groupDataManager.fetchGroupWithGroupId(self.selectedGroupId!)
		self.title = group.groupName
		
		let groupsCount = getImageManager().groupDataManager.groupIds?.count ?? 0
		self.selectGroupButton.setTitle(group.groupName + (groupsCount > 1 ? "  \u{25be}" : "" ), for: .normal)
		self.selectGroupButton.sizeToFit()
		self.selectGroupButton.isEnabled = groupsCount > 1
		
		self.navigationItem.titleView = self.selectGroupButton
	}
    
    @objc func showGroupSelector() {
        DKPopoverViewController.popoverViewController(self.groupListVC, fromView: self.selectGroupButton)
    }
    
    func fetchAsset(for index: Int) -> DKAsset? {
        if !self.hidesCamera && index == 0 {
            return nil
        }
        let assetIndex = (index - (self.hidesCamera ? 0 : 1))
        let group = getImageManager().groupDataManager.fetchGroupWithGroupId(self.selectedGroupId!)
        return getImageManager().groupDataManager.fetchAsset(group, index: assetIndex)
    }
    
    func isCameraCell(indexPath: IndexPath) -> Bool {
        return indexPath.row == 0 && !self.hidesCamera
    }
	
    // MARK: - Cells
    
    func registerCellIfNeeded(cellClass: DKAssetGroupDetailBaseCell.Type) {
        let cellReuseIdentifier = cellClass.cellReuseIdentifier()
        
        if !self.registeredCellIdentifiers.contains(cellReuseIdentifier) {
            self.collectionView.register(cellClass, forCellWithReuseIdentifier: cellReuseIdentifier)
            self.registeredCellIdentifiers.insert(cellReuseIdentifier)
        }
    }
    
    func dequeueReusableCell(for indexPath: IndexPath) -> DKAssetGroupDetailBaseCell {
        let asset = self.fetchAsset(for: indexPath.row)!
        
        let cellClass: DKAssetGroupDetailBaseCell.Type!
        if asset.isVideo {
            cellClass = self.imagePickerController.UIDelegate.imagePickerControllerCollectionVideoCell()
        } else {
            cellClass = self.imagePickerController.UIDelegate.imagePickerControllerCollectionImageCell()
        }
        self.registerCellIfNeeded(cellClass: cellClass)
        
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: cellClass.cellReuseIdentifier(), for: indexPath) as! DKAssetGroupDetailBaseCell
        self.setup(assetCell: cell, for: indexPath, with: asset)
        
        return cell
    }
    
    func dequeueReusableCameraCell(for indexPath: IndexPath) -> DKAssetGroupDetailBaseCell {
        let cellClass = self.imagePickerController.UIDelegate.imagePickerControllerCollectionCameraCell()
        self.registerCellIfNeeded(cellClass: cellClass)
        
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: cellClass.cellReuseIdentifier(), for: indexPath)
        return cell as! DKAssetGroupDetailBaseCell
    }
	
    func setup(assetCell cell: DKAssetGroupDetailBaseCell, for indexPath: IndexPath, with asset: DKAsset) {
        cell.asset = asset
		let tag = indexPath.row + 1
		cell.tag = tag
		
        if self.thumbnailSize.equalTo(CGSize.zero) {
            self.thumbnailSize = self.collectionView!.collectionViewLayout.layoutAttributesForItem(at: indexPath)!.size.toPixel()
        }
        
        asset.fetchImageWithSize(self.thumbnailSize, options: nil, contentMode: .aspectFill) { (image, info) in
            if cell.tag == tag {
                cell.thumbnailImage = image
            }
        }
        
        cell.accessibilityLabel = asset.accessibilityLabel

		if let index = self.imagePickerController.selectedAssets.firstIndex(of: asset) {
			cell.isSelected = true
			cell.index = index
			self.collectionView!.selectItem(at: indexPath, animated: false, scrollPosition: [])
		} else {
			cell.isSelected = false
			self.collectionView!.deselectItem(at: indexPath, animated: false)
		}
	}

    // MARK: - UICollectionViewDelegate, UICollectionViewDataSource methods

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let selectedGroupId = self.selectedGroupId else { return 0 }
		
		let group = getImageManager().groupDataManager.fetchGroupWithGroupId(selectedGroupId)
        return (group.totalCount ?? 0) + (self.hidesCamera ? 0 : 1)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: DKAssetGroupDetailBaseCell!
        if self.isCameraCell(indexPath: indexPath) {
            cell = self.dequeueReusableCameraCell(for: indexPath)
        } else {
            cell = self.dequeueReusableCell(for: indexPath)
        }
        
        /***** BEGIN THREEMA MODIFICATION: add gesture recognizer *********/
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
        cell.addGestureRecognizer(longPressGesture)
        /***** END THREEMA MODIFICATION: add gesture recognizer *********/

        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let firstSelectedAsset = self.imagePickerController.selectedAssets.first,
            let selectedAsset = (collectionView.cellForItem(at: indexPath) as? DKAssetGroupDetailBaseCell)?.asset, self.imagePickerController.allowMultipleTypes == false && firstSelectedAsset.isVideo != selectedAsset.isVideo {

            /***** BEGIN THREEMA MODIFICATION: add gesture recognizer *********/
            UIAlertTemplate.showAlert(owner: self.imagePickerController, title: DKImageLocalizedStringWithKey("selectPhotosOrVideos"), message: DKImageLocalizedStringWithKey("selectPhotosOrVideosError"))
            /***** END THREEMA MODIFICATION: add gesture recognizer *********/

            return false
        }
        
        let shouldSelect = self.imagePickerController.selectedAssets.count < self.imagePickerController.maxSelectableCount
        if !shouldSelect {
            self.imagePickerController.UIDelegate.imagePickerControllerDidReachMaxLimit(self.imagePickerController)
        }
        
        if let selectedAsset = (collectionView.cellForItem(at: indexPath) as? DKAssetGroupDetailBaseCell)?.asset, !self.imagePickerController.UIDelegate.imagePickerController(self.imagePickerController, willSelectAssets: [selectedAsset]) {
            return false
        }
        
		return shouldSelect
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.isCameraCell(indexPath: indexPath) {
            collectionView .deselectItem(at: indexPath, animated: false)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.imagePickerController.presentCamera()
            }
        } else {
            let selectedAsset = (collectionView.cellForItem(at: indexPath) as? DKAssetGroupDetailBaseCell)?.asset
            self.imagePickerController.selectImage(selectedAsset!)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? DKAssetGroupDetailBaseCell {
                cell.index = self.imagePickerController.selectedAssets.count - 1
            }
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
		if let removedAsset = (collectionView.cellForItem(at: indexPath) as? DKAssetGroupDetailBaseCell)?.asset {
			let removedIndex = self.imagePickerController.selectedAssets.firstIndex(of: removedAsset)!
			
			/// Minimize the number of cycles.
			let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems!
			let indexPathsForVisibleItems = collectionView.indexPathsForVisibleItems
			
			let intersect = Set(indexPathsForVisibleItems).intersection(Set(indexPathsForSelectedItems))
			
			for selectedIndexPath in intersect {
                if let selectedCell = (collectionView.cellForItem(at: selectedIndexPath) as? DKAssetGroupDetailBaseCell), let selectedCellAsset = selectedCell.asset, let selectedIndex = self.imagePickerController.selectedAssets.firstIndex(of: selectedCellAsset) {
					if selectedIndex > removedIndex {
						selectedCell.index = selectedCell.index - 1
					}
				}
			}
			
			self.imagePickerController.deselectImage(removedAsset)
		}
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateCachedAssets()
    }
    
    // MARK: - Asset Caching
    
    var previousPreheatRect = CGRect.zero
    
    fileprivate func resetCachedAssets() {
        getImageManager().stopCachingForAllAssets()
        self.previousPreheatRect = .zero
    }

    func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil && self.selectedGroupId != nil else { return }
        
        // The preheat window is twice the height of the visible rect.
        let preheatRect = view!.bounds.insetBy(dx: 0, dy: -0.5 * view!.bounds.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - self.previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        let group = getImageManager().groupDataManager.fetchGroupWithGroupId(self.selectedGroupId!)
        
        // Compute the assets to start caching and to stop caching.
        let (addedRects, removedRects) = self.differencesBetweenRects(self.previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in self.collectionView!.indexPathsForElements(in: rect, self.hidesCamera) }
            .map { indexPath in getImageManager().groupDataManager.fetchOriginalAsset(group, index: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in self.collectionView!.indexPathsForElements(in: rect, self.hidesCamera) }
            .map { indexPath in getImageManager().groupDataManager.fetchOriginalAsset(group, index: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        getImageManager().startCachingAssets(for: addedAssets,
                                             targetSize: self.thumbnailSize, contentMode: .aspectFill, options: nil)
        getImageManager().stopCachingAssets(for: removedAssets,
                                            targetSize: self.thumbnailSize, contentMode: .aspectFill, options: nil)
        
        // Store the preheat rect to compare against in the future.
        self.previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
	
	// MARK: - DKGroupDataManagerObserver methods
	
	func groupDidUpdate(_ groupId: String) {
		if self.selectedGroupId == groupId {
			self.updateTitleView()
		}
	}
	
	func group(_ groupId: String, didRemoveAssets assets: [DKAsset]) {
		for (_, selectedAsset) in self.imagePickerController.selectedAssets.enumerated() {
			for removedAsset in assets {
				if selectedAsset.isEqual(removedAsset) {
					self.imagePickerController.deselectImage(selectedAsset)
				}
			}
		}
	}
    
    func groupDidUpdateComplete(_ groupId: String) {
        if self.selectedGroupId == groupId {
            self.resetCachedAssets()
            self.collectionView?.reloadData()
        }
    }
    
    /***** BEGIN THREEMA MODIFICATION: add gesture recognizer *********/
    @objc func longPressed(_ sender: UITapGestureRecognizer) {
        guard let selectedGroupId = self.selectedGroupId else {
            return
        }
        
        if self.navigationController!.topViewController! is DKAssetGroupDetailVC {
            let selectedIndex = self.collectionView.indexPath(for: sender.view as! UICollectionViewCell)
            
            let group = getImageManager().groupDataManager.fetchGroupWithGroupId(selectedGroupId)
            if group.totalCount > 0 {
                var assets = [DKAsset]()
                for index in 0...group.totalCount - 1 {
                    let asset: DKAsset = self.fetchAsset(for: index)!
                    assets.append(asset)
                }
                
                self.imagePickerController.UIDelegate.imagePickerControllerLongPress(self.imagePickerController, (selectedIndex?.row)!, assets)
            }
        }
    }
    /***** END THREEMA MODIFICATION: add gesture recognizer *********/
}
