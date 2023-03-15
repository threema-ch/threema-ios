// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

// Copyright (c) 2016 Pavel Pantus <pantusp@gmail.com>
// See Resources/License.html for original license

import UIKit

protocol PPOptionsViewControllerDelegate: class {
    func optionsViewControllerShouldBeDismissed(_ controller: PPOptionsViewController)
    
    func optionsViewControllerDidRequestTopOption(_ controller: PPOptionsViewController)
    
    func optionsViewControllerDidRequestOwnOption(_ controller: PPOptionsViewController)
    
    func optionsViewControllerDidRequestPreviewReplacementOption(_ controller: PPOptionsViewController)
}

/**
 Bottom part of Assets Picker Controller that consists of provided options,
 Cancel and Snap Photo or Video / Send X Items buttons.
 */
class PPOptionsViewController: UITableViewController {

    public weak var delegate: PPOptionsViewControllerDelegate?

    private var tableHeightConstraint: NSLayoutConstraint!
    private var selctionCount: Int = 0
    public var options: [PPOption] = []
    fileprivate var config: PPAssetsActionConfig!
    private var cellWidth: CGFloat?
    private var snapOption: PPOption?
    private var onlyPhotosSelected:Bool! = false
    private var onlyVideosSelected:Bool! = false
    
    private let assetManager = PPAssetManager()

    init(aConfig: PPAssetsActionConfig) {
        super.init(style: .plain)
        config = aConfig
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        snapOption = PPOption.init(withTitle: config.previewReplacementText, withIcon: config.previewReplacementIcon, handler: {
            self.delegate?.optionsViewControllerDidRequestPreviewReplacementOption(self)
        })

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "option_cell_id")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor.clear
        tableView.bounces = false
        
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
    	tableView.separatorInset = UIEdgeInsets.zero
        
        tableView.separatorInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 8.0)

        tableHeightConstraint = NSLayoutConstraint(item: tableView,
                                                   attribute: .height,
                                                   relatedBy: .equal,
                                                   toItem: nil,
                                                   attribute: .notAnAttribute,
                                                   multiplier: 1.0,
                                                   constant: 0.0)
        tableView.addConstraint(tableHeightConstraint)
        /***** BEGIN THREEMA MODIFICATION: separatorColor *********/
        tableView.separatorColor = Colors.hairLine
        /***** END THREEMA MODIFICATION: separatorColor *********/
        
        /***** BEGIN THREEMA MODIFICATION: Fix section header padding in iOS 15 *********/
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        } else {
            // Fallback on earlier versions
        }
        /***** END THREEMA MODIFICATION: Fix section header padding in iOS 15 *********/
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()

        tableHeightConstraint.constant = tableView.contentSize.height
    }
    
    public func refresh() {
        tableView.reloadData()
        updateViewConstraints()
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cellWidth = size.width - (2 * config.inset)
        tableView.reloadData()
        updateViewConstraints()
    }
    
    func set(sendItemsCount count: Int, _ onlyPhotos: Bool, _ onlyVideos: Bool) {
        selctionCount = count
        var rowsToUpdate:Array<IndexPath> = Array()
        for i in 1 ..< options.count+1 {
            rowsToUpdate.append(IndexPath(row: i, section: 0))
        }
        
        onlyPhotosSelected = onlyPhotos
        onlyVideosSelected = onlyVideos
        
        tableView.reloadData()
        updateViewConstraints()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        switch section {
        case 0:
            if selctionCount > 0 && (!config.isLandscape() || (config.isLandscape() && isIpad)) && assetManager.authorizationStatus() == .authorized  && config.showGalleryPreview {
                if config.showAdditionalOptionWhenAssetIsSelected {
                    return 2
                } else {
                    return 1
                }
            } else {
                var count = options.count + 1;
                if config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable() {
                    count += 1
                }
                return count
            }
        case 1:
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "option_cell_id", for: indexPath)

        cell.textLabel?.textColor = config.tintColor
        cell.textLabel?.font = config.font
        cell.imageView?.image = nil
        cell.contentView.alignmentRect(forFrame: CGRect(x: 100, y: 0, width: 0, height: 0))
        cell.accessibilityIdentifier = nil
        if indexPath.section == 0 {
            cell.textLabel?.textAlignment = config.textAlignment
            
            var specifiedRow = 0
            if config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable() {
                specifiedRow = 1
            }
            
            if indexPath.row == specifiedRow && (!config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable()) {
                if selctionCount > 0 && !config.showOptionsWhenAssetIsSelected {
                    cell.textLabel?.text = NSLocalizedString(selctionCount == 1 ? "add_item_caption" : "add_items_caption", comment: "")
                } else {
                    if config.useOwnSnapButton && config.ownSnapButtonText != nil {
                        cell.textLabel?.text = config.ownSnapButtonText
                        if config.ownSnapButtonIcon != nil {
                            cell.imageView?.image = config.ownSnapButtonIcon
                        }
                    } else {
                        cell.textLabel?.text = NSLocalizedString("Snap Photo or Video", comment: "Snap Photo or Video")
                    }
                }
            } else {
                if indexPath.row == 0 && (config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable()) {
                    cell.textLabel?.text = config.previewReplacementText
                    if config.previewReplacementIcon != nil {
                        cell.imageView?.image = config.previewReplacementIcon
                    }
                } else if indexPath.row == 1 && (config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable()) {
                    if config.useOwnSnapButton && config.ownSnapButtonText != nil {
                        cell.textLabel?.text = config.ownSnapButtonText
                        if config.ownSnapButtonIcon != nil {
                            cell.imageView?.image = config.ownSnapButtonIcon
                        }
                    } else {
                        cell.textLabel?.text = NSLocalizedString("Snap Photo or Video", comment: "Snap Photo or Video")
                    }
                }
                else if indexPath.row == specifiedRow + 1 && selctionCount > 0 && !config.showOptionsWhenAssetIsSelected && config.showAdditionalOptionWhenAssetIsSelected && config.additionalOptionText != nil {
                    cell.textLabel?.text = config.additionalOptionText
                    /***** BEGIN THREEMA MODIFICATION: Use custom text for additional option *********/
                    if selctionCount == 1 {
                        if (onlyPhotosSelected) {
                            cell.textLabel?.text = NSLocalizedString("send_item_immediately_photo", comment: "")
                        } else {
                            cell.textLabel?.text = NSLocalizedString("send_item_immediately_video", comment: "")
                        }
                    } else {
                        if (onlyPhotosSelected) {
                            cell.textLabel?.text = String.localizedStringWithFormat(NSLocalizedString("send_items_immediately_photo", comment: ""), selctionCount)
                        } else if (onlyVideosSelected) {
                            cell.textLabel?.text = String.localizedStringWithFormat(NSLocalizedString("send_items_immediately_video", comment: ""), selctionCount)
                        } else {
                            cell.textLabel?.text = String.localizedStringWithFormat(NSLocalizedString("send_items_immediately", comment: ""), selctionCount)
                        }
                    }
                    /***** END THREEMA MODIFICATION: Use custom text for additional option *********/
                } else {
                    let row = config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable() ? indexPath.row - 2 : indexPath.row - 1
                    cell.textLabel?.text = options[row].title
                    cell.imageView?.image = options[row].icon
                }
            }
            
            var optionsCount = options.count
            let isIpad = UIDevice.current.userInterfaceIdiom == .pad
            if selctionCount > 0 && !config.showOptionsWhenAssetIsSelected && (!config.isLandscape() || (config.isLandscape() && isIpad)) && assetManager.authorizationStatus() == .authorized && config.showGalleryPreview{
                optionsCount = 1
            } else {
                if config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable() {
                    optionsCount += 1
                }
            }
            if indexPath.row == 0 && ((config.isLandscape() && !isIpad) || UIAccessibility.isVoiceOverRunning || assetManager.authorizationStatus() != .authorized || !config.showGalleryPreview) {
                if cellWidth == nil {
                    cellWidth = cell.bounds.size.width
                }
                let cellBounds = CGRect(x: cell.bounds.origin.x, y: cell.bounds.origin.y, width: cellWidth!, height: cell.bounds.size.height)
                let maskPath = UIBezierPath(roundedRect: cellBounds,
                                            byRoundingCorners: [.topRight, .topLeft],
                                            cornerRadii: CGSize(width: config.cornerRadius, height: config.cornerRadius))
                let maskLayer = CAShapeLayer()
                maskLayer.frame = cellBounds
                maskLayer.path = maskPath.cgPath
                cell.layer.mask = maskLayer
                cell.layer.cornerRadius = 0
            } else if ((indexPath.row == optionsCount) || (selctionCount > 0 && ((config.showAdditionalOptionWhenAssetIsSelected && indexPath.row == 1) || (!config.showAdditionalOptionWhenAssetIsSelected && indexPath.row == 0)))) {
                if cellWidth == nil {
                    cellWidth = cell.bounds.size.width
                }
                let cellBounds = CGRect(x: cell.bounds.origin.x, y: cell.bounds.origin.y, width: cellWidth!, height: cell.bounds.size.height)
                let maskPath = UIBezierPath(roundedRect: cellBounds,
                                            byRoundingCorners: [.bottomRight, .bottomLeft],
                                            cornerRadii: CGSize(width: config.cornerRadius, height: config.cornerRadius))
                let maskLayer = CAShapeLayer()
                maskLayer.frame = cellBounds
                maskLayer.path = maskPath.cgPath
                cell.layer.mask = maskLayer
                cell.layer.cornerRadius = 0
            } else {
                cell.layer.cornerRadius = 0
                cell.layer.mask = nil
                cell.layer.masksToBounds = false
            }
        } else if (indexPath.section == 1) {
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.text = NSLocalizedString("cancel", comment: "")
            cell.accessibilityLabel = NSLocalizedString("cancel", comment: "")
            cell.accessibilityIdentifier = "PPOptionsViewControllerCancelCell"
            /***** BEGIN THREEMA MODIFICATION: Use bold font for cancel *********/
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 19.0)
            /***** END THREEMA MODIFICATION: Use bold font for cancel *********/
            
            /***** BEGIN THREEMA MODIFICATION: Round cancel button corners *********/
            let cellBounds = CGRect(x: cell.bounds.origin.x, y: cell.bounds.origin.y, width: cellWidth!, height: cell.bounds.size.height)
            let maskPath = UIBezierPath(roundedRect: cellBounds,
                                        byRoundingCorners: [.bottomRight, .bottomLeft, .topLeft, .topRight],
                                        cornerRadii: CGSize(width: config.cornerRadius, height: config.cornerRadius))
            let maskLayer = CAShapeLayer()
            maskLayer.frame = cellBounds
            maskLayer.path = maskPath.cgPath
            cell.layer.mask = maskLayer
            cell.layer.cornerRadius = 0
            /***** END THREEMA MODIFICATION: Round cancel button corners *********/
            
            /***** BEGIN THREEMA MODIFICATION: Hide separator on cancel cell *********/
            cell.separatorInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
            /***** END THREEMA MODIFICATION: Hide separator on cancel cell *********/
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 1:
            return config.sectionSpacing
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return config.buttonHeight
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            delegate?.optionsViewControllerShouldBeDismissed(self)
        } else {
            if indexPath.row == 0 && (config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable()) {
                delegate?.optionsViewControllerDidRequestPreviewReplacementOption(self)
            } else if indexPath.row == 0 {
                delegate?.optionsViewControllerDidRequestTopOption(self)
            } else if indexPath.row == 1 && (config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable()) {
                delegate?.optionsViewControllerDidRequestTopOption(self)
            }
            else if indexPath.row > 0 {
                if selctionCount > 0 && config.showAdditionalOptionWhenAssetIsSelected && config.additionalOptionText != nil {
                    delegate?.optionsViewControllerDidRequestOwnOption(self)
                } else {
                    if config.showReplacementOptionInLandscape() || assetManager.isUnauthorizedAndCameraAvailable() {
                        options[indexPath.row - 2].handler()
                    } else {
                        options[indexPath.row - 1].handler()
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            /***** BEGIN THREEMA MODIFICATION: clear color for header view *********/
            headerView.backgroundView = nil
            headerView.backgroundColor = .clear
            /***** END THREEMA MODIFICATION: clear color for header view *********/
        }
    }
    
    /***** BEGIN THREEMA MODIFICATION: iOS 14 fix: clear color for header view *********/
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: tableView.frame.size.width, height: config.sectionSpacing))
        view.backgroundColor = .clear
        return view
    }
    /***** END THREEMA MODIFICATION: iOS 14 fix: clear color for header view *********/
}
