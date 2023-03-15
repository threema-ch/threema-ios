// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  DKAssetGroupListVC.swift
//  DKImagePickerController
//
//  Created by ZhangAo on 15/8/8.
//  Copyright (c) 2015年 ZhangAo. All rights reserved.
//

import Photos

let DKImageGroupCellIdentifier = "DKImageGroupCellIdentifier"

class DKAssetGroupCell: UITableViewCell {

    class DKAssetGroupSeparator: UIView {

        override var backgroundColor: UIColor? {
            get {
                return super.backgroundColor
            }
            set {
                if newValue != UIColor.clear {
                    super.backgroundColor = newValue
                }
            }
        }
    }

    fileprivate let thumbnailImageView: UIImageView = {
        let thumbnailImageView = UIImageView()
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true

        return thumbnailImageView
    }()

    var groupNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        return label
    }()

    var totalCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = UIColor.gray
        return label
    }()

    lazy var customSeparator: DKAssetGroupSeparator = {
        let separator = DKAssetGroupSeparator(frame: CGRect(x: 10, y: self.bounds.height - 1, width: self.bounds.width, height: 0.5))

        separator.backgroundColor = UIColor.lightGray
        separator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        return separator
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectedBackgroundView = self.customSelectedBackgroundView(DKImageResource.blueTickImage().withTint(.primary))
        
        self.isAccessibilityElement = true;
        
        self.contentView.addSubview(thumbnailImageView)
        self.contentView.addSubview(groupNameLabel)
        self.contentView.addSubview(totalCountLabel)

        self.addSubview(self.customSeparator)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let imageViewY = CGFloat(10)
        let imageViewHeight = self.contentView.bounds.height - 2 * imageViewY
        self.thumbnailImageView.frame = CGRect(x: imageViewY,
                                               y: imageViewY,
                                               width: imageViewHeight,
                                               height: imageViewHeight)

        self.groupNameLabel.frame = CGRect(
            x: self.thumbnailImageView.frame.maxX + 10,
            y: self.thumbnailImageView.frame.minY + 5,
            width: 200,
            height: 20)

        self.totalCountLabel.frame = CGRect(
            x: self.groupNameLabel.frame.minX,
            y: self.thumbnailImageView.frame.maxY - 20,
            width: 200,
            height: 20)
    }
    
    func customSelectedBackgroundView(_ image: UIImage!) -> UIView {
        let selectedBackgroundView = UIView()
        let selectedFlag = UIImageView(image: image)
        selectedFlag.frame = CGRect(x: (selectedBackgroundView.bounds.width) - selectedFlag.bounds.width - 20,
                                    y: ((selectedBackgroundView.bounds.width) - selectedFlag.bounds.width) / 2,
                                    width: selectedFlag.bounds.width, height: selectedFlag.bounds.height)
        selectedFlag.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleBottomMargin]
        selectedBackgroundView.addSubview(selectedFlag)
        
        return selectedBackgroundView
    }
}

class DKAssetGroupListVC: UITableViewController, DKGroupDataManagerObserver {
    
    convenience init(selectedGroupDidChangeBlock: @escaping (_ groupId: String?) -> (), imagePickerController: DKImagePickerController?) {
		self.init(style: .plain)
		
		self.defaultAssetGroup = imagePickerController?.defaultAssetGroup
		self.selectedGroupDidChangeBlock = selectedGroupDidChangeBlock
        self.imagePickerController = imagePickerController
	}
    
    internal weak var imagePickerController: DKImagePickerController!
	
	fileprivate var groups: [String]?
	
	fileprivate var selectedGroup: String?
	
	fileprivate var defaultAssetGroup: PHAssetCollectionSubtype?
	
    fileprivate var selectedGroupDidChangeBlock:((_ group: String?)->())?

    fileprivate lazy var groupThumbnailRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact

        return options
    }()

    override var preferredContentSize: CGSize {
        get {
            if let groups = self.groups {
                return CGSize(width: UIView.noIntrinsicMetric,
                              height: CGFloat(groups.count) * self.tableView.rowHeight)
            } else {
                return super.preferredContentSize
            }
        }
        set {
            super.preferredContentSize = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(DKAssetGroupCell.self, forCellReuseIdentifier: DKImageGroupCellIdentifier)
        self.tableView.rowHeight = 70
        self.tableView.separatorStyle = .none

        self.clearsSelectionOnViewWillAppear = false
        
        self.tableView.backgroundColor = self.imagePickerController.UIDelegate.imagePickerControllerAssetGroupListBackgroundColor()

        getImageManager().groupDataManager.addObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (tableView.indexPathForSelectedRow == nil && selectedGroup != nil) {
            let index = groups?.firstIndex(of: selectedGroup!)
            tableView.selectRow(at: IndexPath.init(row: index!, section: 0), animated: false, scrollPosition: .none)
        }
        
        self.view.accessibilityViewIsModal = true
    }

    internal func loadGroups() {
        getImageManager().groupDataManager.fetchGroups { [weak self] groups, error in
            guard let groups = groups, let strongSelf = self, error == nil else { return }

            strongSelf.groups = groups
            strongSelf.selectedGroup = strongSelf.defaultAssetGroupOfAppropriate()
            if let selectedGroup = strongSelf.selectedGroup,
                let row =  groups.firstIndex(of: selectedGroup)
            {
                strongSelf.tableView.selectRow(
                    at: IndexPath(row: row, section: 0),
                    animated: false,
                    scrollPosition: .none)
            }

            strongSelf.selectedGroupDidChangeBlock?(strongSelf.selectedGroup)
        }
    }

    fileprivate func defaultAssetGroupOfAppropriate() -> String? {
        guard let groups = self.groups else { return nil }
        if let defaultAssetGroup = self.defaultAssetGroup {
            for groupId in groups {
                let group = getImageManager().groupDataManager.fetchGroupWithGroupId(groupId)
                if defaultAssetGroup == group.originalCollection.assetCollectionSubtype {
                    return groupId
                }
            }
        }
        return groups.first
    }
    
    public func showLoadingForMoments() {
        let cell = tableView.cellForRow(at: tableView.indexPathForSelectedRow!) as? DKAssetGroupCell
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.style = .gray
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        activityIndicator.startAnimating()
        cell?.accessoryView = activityIndicator
        cell?.selectedBackgroundView?.isHidden = true
        tableView.reloadData()
    }
    
    public func hideLoadingForMoments() {
        let index = groups?.firstIndex(of: selectedGroup!)
        let cell = self.tableView.cellForRow(at: IndexPath.init(row: index!, section: 0)) as? DKAssetGroupCell
        cell?.accessoryView = nil
        cell?.selectedBackgroundView?.isHidden = false
        tableView.reloadData()
        DKPopoverViewController.dismissPopoverViewController()
    }

    // MARK: - UITableViewDelegate, UITableViewDataSource methods

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let groups = groups,
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DKImageGroupCellIdentifier,
                for: indexPath) as? DKAssetGroupCell else
        {
            assertionFailure("Expect groups and cell")
            return UITableViewCell()
        }
        
        let tickImage = self.imagePickerController.UIDelegate.imagePickerControllerAssetGroupListCellTickImage()
        if tickImage != nil {
            cell.selectedBackgroundView = cell.customSelectedBackgroundView(tickImage)
        }
        
        let assetGroup = getImageManager().groupDataManager.fetchGroupWithGroupId(groups[indexPath.row])
        cell.groupNameLabel.text = assetGroup.groupName

        let tag = indexPath.row + 1
        cell.tag = tag

        if assetGroup.totalCount == 0 {
            cell.thumbnailImageView.image = DKImageResource.emptyAlbumIcon()
        } else {
            getImageManager().groupDataManager.fetchGroupThumbnailForGroup(
                assetGroup.groupId,
                size: CGSize(width: tableView.rowHeight, height: tableView.rowHeight).toPixel(),
                options: self.groupThumbnailRequestOptions) { image, info in
                    if cell.tag == tag {
                        cell.thumbnailImageView.image = image
                    }
            }
        }
        cell.totalCountLabel.text = String(assetGroup.totalCount)
        
        cell.backgroundColor = self.imagePickerController.UIDelegate.imagePickerControllerAssetGroupListCellBackgroundColor()
        cell.groupNameLabel.textColor = self.imagePickerController.UIDelegate.imagePickerControllerAssetGroupListCellTitleColor()
        cell.totalCountLabel.textColor = self.imagePickerController.UIDelegate.imagePickerControllerAssetGroupListCellSubTitleColor()
        /***** BEGIN THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = true
        cell.tintColor = .primary
        /***** END THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let groups = self.groups, groups.count > indexPath.row else {
            assertionFailure("Expect groups with count > \(indexPath.row)")
            return
        }
        
        let assetGroup = getImageManager().groupDataManager.fetchGroupWithGroupId(groups[indexPath.row])
        if ((assetGroup.momentsResult == nil) || assetGroup.momentsLoaded) {
            DKPopoverViewController.dismissPopoverViewController()
        }
        
        self.selectedGroup = groups[indexPath.row]
        selectedGroupDidChangeBlock?(self.selectedGroup)
    }
    
    // MARK: - DKGroupDataManagerObserver methods
    
    func groupDidUpdate(_ groupId: String) {
        self.tableView.reloadData()
    }
    
    func groupsDidInsert(_ groupIds: [String]) {
        self.groups! += groupIds
        
        self.willChangeValue(forKey: "preferredContentSize")
        
        let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow
        self.tableView.reloadData()
        self.tableView.selectRow(at: indexPathForSelectedRow, animated: false, scrollPosition: .none)
        
        self.didChangeValue(forKey: "preferredContentSize")
    }
    
    func groupDidRemove(_ groupId: String) {
        guard let row = self.groups?.firstIndex(of: groupId) else { return }
        
        self.willChangeValue(forKey: "preferredContentSize")
        
        self.groups?.remove(at: row)
        
        self.tableView.reloadData()
        if self.selectedGroup == groupId {
            self.selectedGroup = self.groups?.first
            selectedGroupDidChangeBlock?(self.selectedGroup)
            self.tableView.selectRow(at: IndexPath(row: 0, section: 0),
                                     animated: false,
                                     scrollPosition: .none)
        }
        
        self.didChangeValue(forKey: "preferredContentSize")
    }
}
