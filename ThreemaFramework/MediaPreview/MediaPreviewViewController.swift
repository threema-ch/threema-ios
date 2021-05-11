//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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
import MBProgressHUD

open class MediaPreviewViewController: UIViewController, UIGestureRecognizerDelegate {
    private let debugColors = false
    private let buttonSize : CGFloat = 24.0
    
    @IBOutlet weak var largeCollectionView: UICollectionView!
    @IBOutlet weak var smallCollectionView: UICollectionView!
    @IBOutlet weak var middeStackView: UIStackView!
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var stackView: UIStackView!
    
    @IBOutlet weak var greyBgView: UIView!
    @IBOutlet weak var greyBgViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var stackViewToolbar: UIStackView!
    @IBOutlet weak var view1: UIView!
    @IBOutlet weak var view2: UIView!
    @IBOutlet weak var view3: UIView!
    @IBOutlet weak var trashButton: UIButton!
    
    @IBOutlet weak var view1WidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var view2WidthConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var largeCollectionViewContainerView: MediaPreviewCarouselContainerView!
    
    @IBOutlet weak var backgroundView1: UIView!
    @IBOutlet weak var backgroundView2: UIView!
    
    var mediaData: [MediaPreviewItem] = []
    let mediaFetchQueue = DispatchQueue(label: "MediaDataFetchQueue", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    
    @objc public var backIsCancel : Bool = false
    var completion: (([Any], Bool, [String]) -> Void)?
    public var optionsEnabled : Bool = true
    public var sendIsChoose : Bool = false
    @objc public var disableAdd : Bool = false
    public var memoryConstrained = false
    
    var mainCollectionViewController : MainCollectionViewController?
    var miniController: ThumbnailCollectionViewController?
    
    var currentItem : IndexPath = IndexPath(item: 0, section: 0)
    var errorList : [PhotosPickerError] = []
    
    var selection : IndexPath?
    var itemDelegate : MediaPreviewURLDataProcessor?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        self.hideKeyboardOnTap()
        
        setupCollectionViews()
        setupNavigationbar()
        setupCaptionTextfield()
        setupToolbar()
        
        updateSymbols(indexPath: currentItem, animated: false)
        
        self.addAccessibilityLabels()
        
        self.largeCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .centeredHorizontally)
        self.smallCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .left)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.updateLayoutForKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        
        self.updateTextForIndex(indexPath: IndexPath(item: 0, section: 0), animated: false)
        
        // There seems to be an issue in iOS 13 where the content view of an UINavigationBar can have the wrong height.
        // The issue still persists in an iOS 13.7 Simulator.
        // Source for the fix: DaleOne in the Apple Developer Forums (https://developer.apple.com/forums/thread/121861)
        if ProcessInfo().operatingSystemVersion.majorVersion == 13 {
            navigationController?.navigationBar.setNeedsLayout()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: NSNotification.Name(rawValue: kNotificationColorThemeChanged), object: nil)
        themeChanged()
    }
    
    @objc func themeChanged() {
        greyBgView.backgroundColor = Colors.backgroundDark()
        self.largeCollectionView.backgroundColor = Colors.backgroundDark()
        self.smallCollectionView.backgroundColor = Colors.background()
        self.view.backgroundColor = Colors.background()
        
        self.textField.backgroundColor = .clear
        self.textField.textColor = Colors.fontNormal()
        
        backgroundView1.backgroundColor = Colors.bubbleSent()
        backgroundView2.backgroundColor = Colors.bubbleSent()
        
        self.stackView.backgroundColor = .clear
        setupNavigationbar()
    }
    
    private func setupCollectionViews() {
        let layout = MediaPreviewFlowLayout()
        layout.scrollDirection = .horizontal
        
        self.largeCollectionView.collectionViewLayout = layout
        self.largeCollectionView.delegate = mainCollectionViewController
        self.largeCollectionView.dataSource = mainCollectionViewController
        self.largeCollectionView.isPagingEnabled = true
        self.largeCollectionView.allowsMultipleSelection = false
        
        self.smallCollectionView.delegate = miniController!
        self.smallCollectionView.dataSource = miniController!
        self.smallCollectionView.allowsMultipleSelection = false
        self.smallCollectionView.allowsSelection = true
        
        if #available(iOS 11.0, *) {
            self.smallCollectionView.dragInteractionEnabled = true
            self.smallCollectionView.dragDelegate = miniController!
            self.smallCollectionView.dropDelegate = miniController!
        }
        
        self.largeCollectionViewContainerView.delegate = self
    }
    
    private func setupCaptionTextfield() {
        self.textField.attributedPlaceholder = NSAttributedString(string: BundleUtil.localizedString(forKey:"add_caption_to_image"), attributes: [NSAttributedString.Key.foregroundColor : UIColor.darkGray])
        self.textField.font = UIFont.preferredFont(forTextStyle: .body)
        self.textField.delegate = self
        
        // Setup grey background view to separate items and caption view from thumbnails
        greyBgViewBottomConstraint.constant = self.smallCollectionView.frame.height
        greyBgView.backgroundColor = Colors.backgroundDark()
        
        self.largeCollectionView.backgroundColor = Colors.backgroundDark()
        
        self.textField.backgroundColor = Colors.backgroundDark()
        self.textField.textColor = Colors.fontNormal()
        self.textField.borderStyle = .none
        self.textField.minimumFontSize = 17.0
    }
    
    private func setupToolbar() {
        backgroundView1.layer.cornerRadius = backgroundView1.frame.width / 2
        backgroundView2.layer.cornerRadius = backgroundView1.frame.width / 2
        backgroundView1.backgroundColor = Colors.bubbleSent()
        backgroundView2.backgroundColor = Colors.bubbleSent()
        
        if !debugColors {
            view1.backgroundColor = .clear
            view2.backgroundColor = .clear
            view3.backgroundColor = .clear
            stackViewToolbar.backgroundColor = .clear
        }
        
        trashButton.setImage(BundleUtil.imageNamed("trash")?.withTint(Colors.main()), for: .normal)
    }
    
    /// Setup of navigation items and header view
    private func setupNavigationbar() {
        // Setup navigation items
        if !backIsCancel {
            let items : [UIBarButtonItem]
            if #available(iOS 11.0, *) {
                let buttonItem = ChevronBarButtonItem(target: self, action: #selector(backButtonPressed))
                items = buttonItem.asLeftBarButtonItem()
            } else {
                let imageButtonItem = UIBarButtonItem(image: ChevronBackCircleImage.get(), style: .plain, target: self, action: #selector(backButtonPressed))
                items = [imageButtonItem]
            }
            self.navigationItem.leftBarButtonItems = items
        } else {
            if #available(iOS 13.0, *) {
                let backButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(backButtonPressed))
                self.navigationItem.leftBarButtonItems = [backButtonItem]
            } else {
                // Fallback on earlier versions
                let image =  BundleUtil.imageNamed("Close")!.withTint(Colors.gray())?.withRenderingMode(.alwaysOriginal)
                let cancelButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(backButtonPressed))
                self.navigationItem.leftBarButtonItems = [cancelButtonItem]
            }
        }
        
        let rightButton = UIButton()
        rightButton.addTarget(self, action: #selector(sendButtonPressed), for: .touchUpInside)
        rightButton.setTitle(BundleUtil.localizedString(forKey:"send"), for: .normal)
        rightButton.setTitleColor(Colors.main(), for: .normal)
        rightButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: rightButton.titleLabel?.font.pointSize ?? 24.0)
        rightButton.sizeToFit()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightButton)
        
        setupTitleView(landscape: MediaPreviewViewController.isLandscape())
    }
    
    func setupTitleView(landscape : Bool) {
        // Setup title view
        let size: CGFloat = 26.0
        let headerViewInset : CGFloat = size / 2
        
        // Use the small size of the device
        let viewWidth = self.view.frame.width < self.view.frame.height ? self.view.frame.width : self.view.frame.height
        var rightBarButtonWidth = size
        let leftBarButtonWidth: CGFloat = 40.0
        
        if let rightButton = self.navigationItem.rightBarButtonItem?.customView as? UIButton {
            rightButton.sizeToFit()
            rightBarButtonWidth += rightButton.frame.size.width
        }
        
        let widthAvailable : CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? viewWidth / 2 : (viewWidth - leftBarButtonWidth - rightBarButtonWidth)
        let finalWidth = widthAvailable - (2 * headerViewInset)
        
        let fullHeight : Double = landscape ? 32.0 : 42.0
        
        let titleViewSize = CGRect(x: 0.0, y: 0.0, width: Double(finalWidth), height: fullHeight)
        
        let tapAction = self.optionsEnabled ? self.moreButtonPressed : nil
        
        let headerView = HeaderView(for: self.mediaData, frame: titleViewSize, tapAction: tapAction)
        headerView.rotate(landscape: landscape, newWidth: titleViewSize.width)

        guard let veryLeftItem = self.navigationItem.leftBarButtonItems?.first else {
            let message = "Could not get cancel or back item"
            DDLogError(message)
            return
        }
        
        if landscape && UIDevice.current.userInterfaceIdiom != .pad  {
            self.navigationItem.leftBarButtonItems = [veryLeftItem]
            self.navigationItem.titleView = headerView
        } else {
            let headerViewItem = UIBarButtonItem(customView: headerView)
            self.navigationItem.leftBarButtonItems? = [veryLeftItem, headerViewItem]
            self.navigationItem.titleView = nil
        }
    }
    
    @objc private func pressedAction() {
        moreButtonPressed()
        dismissKeyboard()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        self.largeCollectionView.collectionViewLayout.invalidateLayout()
        if self.errorList.count > 0 {
            showError(errorList: self.errorList)
            self.errorList = []
        }
        
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        
        if let rightBarButton = self.navigationItem.rightBarButtonItem?.customView as? UIButton {
            if sendIsChoose {
                rightBarButton.setTitle(BundleUtil.localizedString(forKey:"next"), for: .normal)
            } else {
                rightBarButton.setTitle(BundleUtil.localizedString(forKey:"send"), for: .normal)
            }
            rightBarButton.tintColor = Colors.main()
            rightBarButton.sizeToFit()
        }
        
        setupTitleView(landscape: MediaPreviewViewController.isLandscape())
    }
    
    func hideKeyboardOnTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == self.navigationItem.rightBarButtonItem {
            return false
        }
        if touch.view == self.textField {
            return false
        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func dismissKeyboard() {
        self.textField.resignFirstResponder()
    }
    
    func addAccessibilityLabels() {
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = BundleUtil.localizedString(forKey:"send")
        self.textField.accessibilityLabel = BundleUtil.localizedString(forKey:"add_caption_to_image")
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        self.view.accessibilityElements = [self.navigationItem,
                                           self.largeCollectionViewContainerView!,
                                           self.textField!,
                                           self.stackViewToolbar!,
                                           self.smallCollectionView!]
                
        self.updateTitleLabel()
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func initWithMedia(dataArray: [Any], delegate: Any, completion: (([Any], Bool, [String]) -> Void)?, itemDelegate : MediaPreviewURLDataProcessor) {
        self.completion = completion
        self.itemDelegate = itemDelegate
        
        mainCollectionViewController = MainCollectionViewController(delegate: self)
        miniController = ThumbnailCollectionViewController()
        miniController?.parent = self
        
        self.resetMediaTo(dataArray: dataArray, reloadData: false)
    }
    
    @objc func resetMediaTo(dataArray: [Any], reloadData : Bool) {
        
        let loadedItems =  self.itemDelegate!.loadItems(dataArray: dataArray)
        self.mediaData = loadedItems.items
        self.errorList = loadedItems.errors
        
        self.itemDelegate!.requestAssets(queue: self.mediaFetchQueue, mediaData: self.mediaData)
        
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
                self.backButtonPressed()
            }
        })
    }
    
    func reloadData() {
        self.largeCollectionView.reloadData()
        self.smallCollectionView.reloadData()
        
        self.updateSelection()
    }
    
    func reloadCollectionViewData() {
        self.largeCollectionView.reloadData()
        self.smallCollectionView.reloadData()
        DispatchQueue.main.async {
            self.smallCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
        }
    }
    
    func presentSizeAlertWithSize(size : Int64) {
        let size = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let allowed = ByteCountFormatter.string(fromByteCount: Int64(kMaxFileSize), countStyle: .file)
        
        let title = BundleUtil.localizedString(forKey:"item_too_large_title")
        let message = String(format: BundleUtil.localizedString(forKey:"maximum_file_size_exceeded"), allowed, size)
        
        UIAlertTemplate.showAlert(owner: self, title: title, message: message)
    }
    
    @objc func sendButtonPressed(_ sender: Any) {
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        let label = BundleUtil.localizedString(forKey:"processing_items_progress")
        let progressViewHandler = ProgressViewHandler(view: self.view,
                                                      totalWorkItems: self.mediaData.count,
                                                      label: label)
        dismissKeyboard()
        
        // Stop playing video when send button is pressed
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        
        DispatchQueue.global(qos: .userInteractive).async {
            let sendAsFile = self.mediaData[0].sendAsFile
            self.itemDelegate?.sendAsFile = sendAsFile
            
            var returnVal: [Any] = []
            var captions: [String] = []
            for item in self.mediaData {
                if let videoItem = item as? VideoPreviewItem {
                    progressViewHandler.observeVideoItem(videoItem)
                }
                guard let i = self.itemDelegate?.processItemForSending(item: item) else {
                    progressViewHandler.incrementItemProgress(100)
                    continue
                }
                returnVal.append(i)
                captions.append(item.caption ?? "")
                
                if item.isKind(of: VideoPreviewItem.self) {
                    progressViewHandler.finishVideo()
                } else {
                    progressViewHandler.incrementItemProgress(100)
                }
            }
            DispatchQueue.main.async {
                progressViewHandler.hideHud {
                    self.completion?(returnVal, sendAsFile, captions)
                }
            }
        }
    }
    
    @IBAction func previewTapped (_ sender: Any) {
        guard let indexPath = self.getCurrentlyVisibleItem() else {
            return
        }
        let cell = self.largeCollectionView.cellForItem(at: indexPath) as! DocumentPreviewCell
        cell.showPreview()
    }
    
    @IBAction func trashButtonTapped(_ sender: Any) {
        guard let indexPath =  self.getCurrentlyVisibleItem() else {
            return
        }
        
        self.mediaData[indexPath.item].removeItem()
        
        _ = self.mediaData.remove(at: indexPath.item)
        
        self.largeCollectionView.deleteItems(at: [indexPath])
        self.smallCollectionView.deleteItems(at: [indexPath])
        
        if self.mediaData.count == 0 {
            self.backButtonPressed()
        } else {
            let newItem = min(indexPath.item, self.mediaData.count - 1)
            self.currentItem = IndexPath(item:newItem, section: indexPath.section)
            
            self.updateSelection()
        }
        self.updateTitleLabel()
    }
    
    private func updateTitleLabel() {
        if let headerView = self.navigationItem.titleView as? HeaderView {
            headerView.updateTitleLabel(mediaPreviewItems: self.mediaData)
        }
        if let headerView = self.navigationItem.leftBarButtonItems?.last?.customView as? HeaderView {
            headerView.updateTitleLabel(mediaPreviewItems: self.mediaData)
        }
    }
    
    open override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        selection = self.getCurrentlyVisibleItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration / 2, execute: {
            self.largeCollectionView.collectionViewLayout.invalidateLayout()
        })
        
        let isLandscape = toInterfaceOrientation.isLandscape
        setupTitleView(landscape: isLandscape)
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
    
    func moreButtonPressed() {
        let storyboardName = "MediaShareStoryboard"
        let storyboardBundle = Bundle(for: MediaPreviewViewController.self)
        let sb = UIStoryboard(name: storyboardName, bundle: storyboardBundle)
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
    func addButtonPressed() {
        self.itemDelegate!.returnAction(mediaData: self.mediaData)
    }
    
    @objc func backButtonPressed() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        if backIsCancel {
            self.dismiss(animated: true, completion: nil)
            self.itemDelegate?.executeCancelAction()
        } else {
            self.dismiss(animated: true, completion: nil)
            self.itemDelegate!.returnAction(mediaData: self.mediaData)
        }
    }
    
    @objc static func isURLItem(item : MediaPreviewItem) -> Bool {
        return item.originalAsset == nil && item.itemUrl != nil
    }
    
    func shouldScrollTo(indexPath : IndexPath, animated : Bool = true) {
        self.currentItem = indexPath
        DispatchQueue.main.async {
            self.largeCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.selectItem(at: self.currentItem, animated: true, scrollPosition: .centeredHorizontally)
        }
        self.updateTextForIndex(indexPath: self.currentItem, animated: true)
        UIAccessibility.post(notification: .pageScrolled, argument: "Item \(self.currentItem.item + 1) of \(mediaData.count)")
    }
    
    func getCurrentlyVisibleItem() -> IndexPath? {
        return self.currentItem
    }
    
    @IBAction func captionEditingChanged(_ sender: Any) {
        guard let indexPath  = self.getCurrentlyVisibleItem()  else {
            return
        }
        self.mediaData[indexPath.item].caption = self.textField.text
        updateTextAlignment()
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
            self.updateTextAlignment()
        }
        self.updateSymbols(indexPath: indexPath, animated: animated)
    }
    
    func updateSymbols(indexPath: IndexPath, animated: Bool) {
        if self.mediaData.count - 1 < indexPath.item {
            return
        }
        let index = indexPath.item
        let item = self.mediaData[index]
        switch item {
        case is ImagePreviewItem:
            view2.isHidden = true
        case is VideoPreviewItem:
            view2.isHidden = true
        case is DocumentPreviewItem:
            view2.isHidden = false
        default:
            return
        }
    }
    
    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        _ = self.bottomLayoutConstraint?.constant
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
                if let endFrame = endFrame {
                    let safeInset: CGFloat
                    if #available(iOS 11.0, *) {
                        safeInset = self.view.safeAreaInsets.bottom
                    } else {
                        safeInset = 0.0
                    }
                    let convertedEndframe = self.view.convert(endFrame, from: UIScreen.main.coordinateSpace)
                    let intersection = self.view.frame.intersection(convertedEndframe).height
                    self.bottomLayoutConstraint?.constant = -(max(intersection - smallCollectionView.frame.height - safeInset, 0))
                } else {
                    self.bottomLayoutConstraint?.constant = 0.0
                }
                
            }
            
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: {
                            self.view.layoutIfNeeded()
                           },
                           completion: {_ in 
                            self.largeCollectionView.scrollToItem(at: self.getCurrentlyVisibleItem()!, at: .centeredHorizontally, animated: false)
                           })
        }
    }
    
    open override func didReceiveMemoryWarning() {
        guard let currentItem = self.getCurrentlyVisibleItem() else {
            return
        }
        for item in mediaData {
            if item != mediaData[currentItem.item] {
                item.freeMemory()
            }
        }
    }
    
    private func updateTextAlignment() {
        if let text = textField.text {
            textField.textAlignment = text.textAlignment()
        }
    }
    
}

extension MediaPreviewViewController : UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

extension MediaPreviewViewController {
    static func isLandscape() -> Bool {
        var isLandscape = UIDevice.current.orientation.isLandscape
        
        if #available(iOSApplicationExtension 10.0, *) {
            isLandscape = (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height)
        }
        return isLandscape
    }
}
