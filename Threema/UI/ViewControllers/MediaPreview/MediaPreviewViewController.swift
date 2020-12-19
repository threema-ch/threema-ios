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

import UIKit
import CocoaLumberjackSwift

class MediaPreviewViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var largeCollectionView: UICollectionView!
    @IBOutlet weak var smallCollectionView: UICollectionView!
    @IBOutlet weak var middeStackView: UIStackView!
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var navigationBar: UINavigationBar!
    
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    @IBOutlet weak var moreButton: UIBarButtonItem!
    @IBOutlet weak var largeCollectionViewContainerView: MediaPreviewCarouselContainerView!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    var mediaData: [MediaPreviewItem] = []
    let mediaFetchQueue = DispatchQueue(label: "MediaDataFetchQueue", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    
    var completion: (([Any], Bool, [String]) -> Void)?
    var returnToMe: (([DKAsset], [MediaPreviewItem]) -> Void)?
    var addMore: (([DKAsset], [MediaPreviewItem]) -> Void)?
    weak var delegate: SendMediaAction?
    @objc var backIsCancel : Bool = false
    
    var mainCollectionViewController : MainCollectionViewController?
    var miniController: ThumbnailCollectionViewController?
    
    var currentItem : IndexPath = IndexPath(item: 0, section: 0)
    var errorList : [PhotosPickerError] = []
    
    var selection : IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.hideKeyboardOnTap()
        
        self.textField.placeholder = BundleUtil.localizedString(forKey:"add_caption_to_image")
        self.textField.delegate = self
        
        if backIsCancel {
            self.backButton.title = BundleUtil.localizedString(forKey:"cancel")
        } else {
            self.backButton.title = BundleUtil.localizedString(forKey:"back")
        }
        self.sendButton.setTitle(BundleUtil.localizedString(forKey:"send"), for: .normal)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.updateLayoutForKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        
        self.largeCollectionView.delegate = mainCollectionViewController
        self.largeCollectionView.dataSource = mainCollectionViewController
        let layout = MediaPreviewFlowLayout()
        layout.scrollDirection = .horizontal
        self.largeCollectionView.collectionViewLayout = layout
        self.largeCollectionView.isPagingEnabled = true
        self.largeCollectionView.allowsMultipleSelection = false
        
        self.smallCollectionView.delegate = miniController!
        self.smallCollectionView.dataSource = miniController!
        self.smallCollectionView.allowsMultipleSelection = false
        
        self.largeCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .centeredHorizontally)
        self.smallCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .left)
        
        if #available(iOS 11.0, *) {
            self.smallCollectionView.dragInteractionEnabled = true
            self.smallCollectionView.dragDelegate = miniController!
            self.smallCollectionView.dropDelegate = miniController!
        }
        
        self.largeCollectionViewContainerView.delegate = self
        self.addAccessibilityLabels()
        self.updateTextForIndex(indexPath: IndexPath(item: 0, section: 0), animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.largeCollectionView.collectionViewLayout.invalidateLayout()
        if self.errorList.count > 0 {
            showError(errorList: self.errorList)
            self.errorList = []
        }
        if self.mediaData.count > 1 {
            self.navigationBar.topItem?.title = String(format: BundleUtil.localizedString(forKey:"multiple_media_items"), self.mediaData.count)
        } else {
            self.navigationBar.topItem?.title = BundleUtil.localizedString(forKey:"media_item")
        }
    }
    
    func hideKeyboardOnTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == self.sendButton {
            return false
        }
        if touch.view == self.addButton {
            return false
        }
        return true
    }
    
    @objc override func dismissKeyboard() {
        self.textField.resignFirstResponder()
    }
    
    func addAccessibilityLabels() {
        self.sendButton.accessibilityLabel = BundleUtil.localizedString(forKey:"send")
        self.addButton.accessibilityLabel = BundleUtil.localizedString(forKey:"add_more_images")
        self.textField.accessibilityLabel = BundleUtil.localizedString(forKey:"add_caption_to_image")
        self.deleteButton.accessibilityLabel = BundleUtil.localizedString(forKey:"remove_current_image_from_selected_images")
        self.moreButton.accessibilityLabel = BundleUtil.localizedString(forKey:"send_options")
        if backIsCancel {
            self.backButton.accessibilityLabel = BundleUtil.localizedString(forKey:"back_to_media_selection")
        } else {
            self.backButton.accessibilityLabel = BundleUtil.localizedString(forKey:"cancel")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func initWithMedia(dataArray: [Any], delegate: SendMediaAction, completion: (([Any], Bool, [String]) -> Void)?, returnToMe: (([DKAsset], [MediaPreviewItem]) -> Void)?, addMore: (([DKAsset], [MediaPreviewItem]) -> Void)?) {
        self.completion = completion
        self.returnToMe = returnToMe
        self.addMore = addMore
        self.delegate = delegate
        
        mainCollectionViewController = MainCollectionViewController(delegate: self)
        miniController = ThumbnailCollectionViewController()
        miniController?.parent = self
        
        self.resetMediaTo(dataArray: dataArray, reloadData: false)
    }
    
    private func addDataItemFrom(url: URL) {
        let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
        if UTIConverter.isImageMimeType(mimeType) {
            let item = ImagePreviewItem(itemUrl: url)
            self.mediaData.append(item)
        } else if UTIConverter.isMovieMimeType(mimeType) || UTIConverter.isVideoMimeType(mimeType) {
            let item = VideoPreviewItem(itemUrl: url)
            self.mediaData.append(item)
        } else {
            self.errorList.append(PhotosPickerError.unknown)
        }
    }
    
    private func requestAssets() {
        self.mediaFetchQueue.async {
            for index in 0..<self.mediaData.count {
                self.mediaData[index].requestAsset()
            }
        }
    }
    
    @objc func resetMediaTo(dataArray: [Any], reloadData : Bool) {
        self.mediaData = []
        for index in 0..<dataArray.count {
            switch dataArray[index] {
            case is MediaPreviewItem:
                let mediaItem = dataArray[index] as! MediaPreviewItem
                self.mediaData.append(mediaItem)
            case is DKAsset:
                let data = dataArray[index] as! DKAsset
                let mediaItem = self.mediaPreviewItemFromDKAsset(asset: data)
                
                self.mediaData.append(mediaItem)
            case is PHAsset:
                guard let phasset = dataArray[index] as? PHAsset else {
                    continue
                }
                self.mediaData.append(self.mediaPreviewItemFromDKAsset(asset: DKAsset(originalAsset: phasset)))
            case is URL, is NSURL:
                let url = dataArray[index] as! URL
                self.addDataItemFrom(url: url)
            case is PhotosPickerError:
                guard let err = dataArray[index] as? PhotosPickerError else {
                    continue
                }
                self.errorList.append(err)
            default:
                continue
            }
        }
        
        self.requestAssets()
        
        if reloadData {
            self.reloadData()
            if self.errorList.count > 0 {
                showError(errorList: self.errorList)
                self.errorList = []
            }
        }
    }
    
    private func showError(errorList : [PhotosPickerError]) {
        let items = errorList.count
        
        var title = BundleUtil.localizedString(forKey:"could_not_add_items_title")
        var message = String(format: BundleUtil.localizedString(forKey:"multiple_media_items_could_not_be_processed"), items)
        
        if items == 1 {
            title = BundleUtil.localizedString(forKey:"could_not_add_all_items_title")
            message = BundleUtil.localizedString(forKey:"one_media_item_could_not_be_processed")
        }
        
        UIAlertTemplate.showAlert(owner: self, title: title, message: message, actionOk: {_ in
            if self.mediaData.count == 0 {
                self.backButtonPressed(self)
            }
        })
    }
    
    func reloadData() {
        self.largeCollectionView.reloadData()
        self.smallCollectionView.reloadData()
        
        self.updateSelection()
    }
    
    func mediaPreviewItemFromDKAsset(asset : DKAsset) -> MediaPreviewItem {
        var mediaItem : MediaPreviewItem
        if asset.isVideo {
            mediaItem = VideoPreviewItem.init(originalAsset: asset)
        } else {
            mediaItem = ImagePreviewItem.init(originalAsset: asset)
        }
        return mediaItem
    }
    
    func reloadCollectionViewData() {
        self.largeCollectionView.reloadData()
        self.smallCollectionView.reloadData()
        DispatchQueue.main.async {
            self.smallCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
        }
    }
    
    func initProgress() {
        DispatchQueue.main.async(execute: {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            
            if hud.progressObject == nil {
                hud.mode = .annularDeterminate
                
                let po = Progress(totalUnitCount: Int64(self.mediaData.count))
                hud.progressObject = po
                
                hud.label.text = String(format: BundleUtil.localizedString(forKey:"processing_items_progress"), po.completedUnitCount, po.totalUnitCount)
            }
        })
    }
    
    func incrementProgress() {
        DispatchQueue.main.async(execute: {
            guard let hud = MBProgressHUD(for: self.view) else {
                return
            }
            if hud.progressObject != nil {
                guard let po = hud.progressObject else {
                    return
                }
                hud.mode = .annularDeterminate
                po.completedUnitCount += 1
                hud.label.text = String(format: BundleUtil.localizedString(forKey:"processing_items_progress"), po.completedUnitCount, po.totalUnitCount)
            }
        })
    }
    
    func presentSizeAlertWithSize(size : Int64) {
        let size = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let allowed = ByteCountFormatter.string(fromByteCount: Int64(kMaxFileSize), countStyle: .file)
        
        let title = BundleUtil.localizedString(forKey:"item_too_large_title")
        let message = String(format: BundleUtil.localizedString(forKey:"maximum_file_size_exceeded"), allowed, size)
        
        UIAlertTemplate.showAlert(owner: self, title: title, message: message)
    }
    
    
    @IBAction func sendButtonPressed(_ sender: Any) {
        self.initProgress()
        DispatchQueue.global(qos: .userInitiated).async {
            var returnVal: [Any] = []
            var captions: [String] = []
            for item in self.mediaData {
                if item is ImagePreviewItem {
                    if item.originalAsset != nil {
                        guard let originalAsset = item.originalAsset else {
                            continue
                        }
                        guard let asset = originalAsset.originalAsset else {
                            DDLogError("Original Asset is unavailable.")
                            continue
                        }
                        returnVal.append(asset)
                        
                    } else {
                        guard let assetUrl = item.itemUrl else {
                            continue
                        }
                        returnVal.append(assetUrl)
                    }
                }
                
                if item is VideoPreviewItem {
                    guard let videoItem = item as? VideoPreviewItem else {
                        continue
                    }
                    guard let assetUrl : URL = videoItem.getTranscodedItem() else {
                        continue
                    }
                    returnVal.append(assetUrl)
                }
                captions.append(item.caption ?? "")
                
                self.incrementProgress()
            }
            
            let deadlineTime = DispatchTime.now() + .seconds(1)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.hideProgressHud()
                self.completion?(returnVal, self.mediaData[0].sendAsFile, captions)
            }
        }
    }
    
    func hideProgressHud() {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.view, animated: true)
        }
    }
    
    
    @IBAction func trashTapped(_ sender: Any) {
        guard let indexPath =  self.getCurrentlyVisibleItem() else {
            return
        }
        
        self.mediaData[indexPath.item].removeItem()
        
        _ = self.mediaData.remove(at: indexPath.item)
        
        self.largeCollectionView.deleteItems(at: [indexPath])
        self.smallCollectionView.deleteItems(at: [indexPath])
        
        if self.mediaData.count == 0 {
            self.backButtonPressed(self)
        } else {
            let newItem = min(indexPath.item, self.mediaData.count - 1)
            self.currentItem = IndexPath(item:newItem, section: indexPath.section)
            
            self.updateSelection()
        }
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        selection = self.getCurrentlyVisibleItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration / 2, execute: {
            self.largeCollectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func updateSelection() {
        guard let indexPath = self.getCurrentlyVisibleItem()  else {
            return
        }
        
        self.updateTextForIndex(indexPath: indexPath, animated: true)
        self.largeCollectionViewContainerView.currentImage = self.mediaData[min(indexPath.item, self.mediaData.count - 1)]
        
        DispatchQueue.main.async {
            self.smallCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: UICollectionView.ScrollPosition.centeredHorizontally)
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        }
    }
    
    @IBAction func moreButtonPressed(_ sender: Any) {
        let sb = UIStoryboard(name: "MediaShareStoryboard", bundle: nil)
        let moreOptionsNavigationController = sb.instantiateViewController(withIdentifier: "moreOptionsNavigationController")
        
        (moreOptionsNavigationController.children.first as? MediaShareOptionsViewController)?.setupOptions(options: MediaShareOptionsViewController.ImageSendOptions(sendAsFile: self.mediaData[0].sendAsFile , imageQuality: ""))
        
        self.present(moreOptionsNavigationController, animated: true, completion: {
            (moreOptionsNavigationController.children.first as? MediaShareOptionsViewController)?.delegate = self
        })
    }
    
    func updateOptions(imageSendOptions: MediaShareOptionsViewController.ImageSendOptions) {
        for index in 0...self.mediaData.count - 1 {
            let item = self.mediaData[index]
            item.sendAsFile = imageSendOptions.sendAsFile
        }
        
    }
    @IBAction func smallAddButtonPressed(_ sender: Any) {
        var returnVal: [DKAsset] = []
        for item in self.mediaData {
            guard let originalAsset = item.originalAsset else {
                continue
            }
            returnVal.append(originalAsset)
        }
        self.addMore?(returnVal, self.mediaData)
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        var returnVal: [DKAsset] = []
        for item in self.mediaData {
            guard let originalAsset = item.originalAsset else {
                continue
            }
            returnVal.append(originalAsset)
        }
        self.returnToMe?(returnVal, self.mediaData)
    }
    
    @objc static func equals(asset: DKAsset, item: MediaPreviewItem) -> Bool {
        return item.originalAsset == asset
    }
    
    @objc static func isURLItem(item : MediaPreviewItem) -> Bool {
        return item.itemUrl != nil
    }
    
    @objc static func contains(asset: DKAsset, itemList: [MediaPreviewItem]) -> Int {
        for index in 0..<itemList.count {
            if equals(asset: asset, item: itemList[index]) {
                return index
            }
        }
        return -1
    }
    
    func shouldScrollTo(indexPath : IndexPath, animated : Bool = true) {
        self.currentItem = indexPath
        DispatchQueue.main.async {
            self.largeCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .centeredHorizontally)
        }
        self.updateTextForIndex(indexPath: self.currentItem, animated: true)
        UIAccessibility.post(notification: .pageScrolled, argument: "Item \(self.currentItem.item) of \(mediaData.count)")
    }
    
    func getCurrentlyVisibleItem() -> IndexPath? {
        return self.currentItem
    }
    
    @IBAction func captionEditingChanged(_ sender: Any) {
        guard let indexPath  = self.getCurrentlyVisibleItem()  else {
            return
        }
        self.mediaData[indexPath.item].caption = self.textField.text
    }
    
    func updateTextForIndex(indexPath: IndexPath, animated: Bool) {
        if self.mediaData.count - 1 < indexPath.item {
            return
        }
        DispatchQueue.main.async {
            let index = indexPath.item
            let textColor = Colors.fontNormal()
            let tintColor = Colors.main()
            
            if !animated {
                self.textField.text = self.mediaData[index].caption
            } else {
                self.textField.text = self.mediaData[index].caption
                let fadeOut = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: {
                    self.textField.textColor = self.textField.backgroundColor
                    self.textField.tintColor = .clear
                    self.textField.text = ""
                })
                
                let fadeIn = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: {
                    self.textField.textColor = textColor
                    self.textField.tintColor = tintColor
                    let index = indexPath.item
                    self.textField.text = self.mediaData[index].caption
                })
                
                fadeOut.addCompletion({_ in
                    fadeIn.startAnimation()
                })
                fadeOut.startAnimation()
            }
        }
    }
    
    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        let prevConst = self.bottomLayoutConstraint?.constant
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let endFrameY = endFrame?.origin.y ?? 0
            let duration: TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve: UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
            if endFrameY >= UIScreen.main.bounds.size.height {
                self.bottomLayoutConstraint?.constant = 0.0
            } else {
                if let keyBoardHeight = endFrame?.size.height {
                    let safeInset: CGFloat
                    if #available(iOS 11.0, *) {
                        safeInset = self.view.safeAreaInsets.bottom
                    } else {
                        safeInset = 0.0
                    }
                    self.bottomLayoutConstraint?.constant = -(keyBoardHeight - smallCollectionView.frame.height - safeInset)
                } else {
                    self.bottomLayoutConstraint?.constant = 0.0
                }
                
            }
            
            let layout = UICollectionViewFlowLayout()
            layout.minimumLineSpacing = 0.0
            layout.minimumInteritemSpacing = 0.0
            layout.scrollDirection = .horizontal
            layout.itemSize = self.largeCollectionView.frame.size
            if self.bottomLayoutConstraint.constant != 0.0 {
                layout.itemSize.height = self.largeCollectionView.frame.height + self.bottomLayoutConstraint.constant
            } else {
                layout.itemSize.height = self.largeCollectionView.frame.height - (prevConst ?? 0.0)
            }
            
            
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: {
                            self.view.layoutIfNeeded()
                            self.largeCollectionView.setCollectionViewLayout(layout, animated: false)
                           },
                           completion:nil)
        }
    }
}

extension MediaPreviewViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}
