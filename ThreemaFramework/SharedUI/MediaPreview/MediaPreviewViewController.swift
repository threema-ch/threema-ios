//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import MBProgressHUD
import UIKit

open class MediaPreviewViewController: UIViewController, UIGestureRecognizerDelegate {
    private let debugColors = false
    private let buttonSize: CGFloat = 24.0
    
    @IBOutlet var largeCollectionView: UICollectionView!
    @IBOutlet var smallCollectionView: UICollectionView!
    @IBOutlet var middleStackView: UIStackView!
    @IBOutlet var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet var textField: UITextField!
    @IBOutlet var stackView: UIStackView!
    
    @IBOutlet var greyBgView: UIView!
    @IBOutlet var greyBgViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var stackViewToolbar: UIStackView!
    @IBOutlet var view1: UIView!
    @IBOutlet var view2: UIView!
    @IBOutlet var view3: UIView!
    @IBOutlet var trashButton: UIButton!
    @IBOutlet var previewButton: UIButton!
    
    @IBOutlet var view1WidthConstraint: NSLayoutConstraint!
    @IBOutlet var view2WidthConstraint: NSLayoutConstraint!
    
    @IBOutlet var largeCollectionViewContainerView: MediaPreviewCarouselContainerView!
    
    @IBOutlet var backgroundView1: UIView!
    @IBOutlet var backgroundView2: UIView!
    
    var mediaData: [MediaPreviewItem] = []
    
    @objc public var backIsCancel = false
    @objc var showKeyboard = false
    
    var completion: (([Any], Bool, [String]) -> Void)?
    public var optionsEnabled = true
    public var sendIsChoose = false
    @objc public var disableAdd = false
    public var memoryConstrained = false
    public var conversationDescription: NSAttributedString?
    
    var mainCollectionViewController: MainCollectionViewController?
    var miniController: ThumbnailCollectionViewController?
    
    var currentItem = IndexPath(item: 0, section: 0)
    var errorList: [PhotosPickerError] = []
    
    var selection: IndexPath?
    var itemDelegate: MediaPreviewURLDataProcessor?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionViews()
        setupNavigationbar()
        setupCaptionTextfield()
        setupToolbar()
        
        updateSymbols(indexPath: currentItem, animated: false)
        
        addAccessibilityLabels()
        
        currentItem = IndexPath(item: mediaData.count - 1, section: 0)

        if largeCollectionView.numberOfItems(inSection: currentItem.section) > 0 {
            largeCollectionView.selectItem(at: currentItem, animated: true, scrollPosition: .centeredHorizontally)
            smallCollectionView.selectItem(at: currentItem, animated: true, scrollPosition: .left)
        }
        
        updateTextForIndex(indexPath: currentItem, animated: false)
        
        // There seems to be an issue in iOS 13 where the content view of an UINavigationBar can have the wrong height.
        // The issue still persists in an iOS 13.7 Simulator.
        // Source for the fix: DaleOne in the Apple Developer Forums (https://developer.apple.com/forums/thread/121861)
        if ProcessInfo().operatingSystemVersion.majorVersion == 13 {
            navigationController?.navigationBar.setNeedsLayout()
        }
        
        themeChanged()
        updateTitleLabel()
        
        overrideUserInterfaceStyle = UserSettings.shared().darkTheme ? .dark : .light
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        view.accessibilityElements = [
            navigationItem,
            largeCollectionViewContainerView!,
            textField!,
            stackViewToolbar!,
            smallCollectionView!,
        ]
        
        smallCollectionView.flashScrollIndicators()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        largeCollectionView.collectionViewLayout.invalidateLayout()
        if !errorList.isEmpty {
            showError(errorList: errorList)
            errorList = []
        }
        
        setupOrUpdateRightBarButtonItem()
        
        setupTitleView(landscape: MediaPreviewViewController.isLandscape())
        
        setupKeyboardActions()
        
        // Get notified on theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
        themeChanged()
        
        if showKeyboard {
            textField.becomeFirstResponder()
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        for item in mediaData {
            item.freeMemory()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupOrUpdateRightBarButtonItem() {
        var rightBarButtonItem: UIButton
        
        if let rbi = navigationItem.rightBarButtonItem?.customView as? UIButton {
            rightBarButtonItem = rbi
        }
        else {
            rightBarButtonItem = UIButton()
            rightBarButtonItem.addTarget(self, action: #selector(sendButtonPressed), for: .touchUpInside)
        }
        
        if sendIsChoose {
            rightBarButtonItem.setTitle(BundleUtil.localizedString(forKey: "next"), for: .normal)
        }
        else {
            rightBarButtonItem.setTitle(BundleUtil.localizedString(forKey: "send"), for: .normal)
        }
        rightBarButtonItem.setTitleColor(.primary, for: .normal)
        rightBarButtonItem.titleLabel?.font = UIFont
            .boldSystemFont(ofSize: rightBarButtonItem.titleLabel?.font.pointSize ?? 24.0)
        rightBarButtonItem.sizeToFit()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonItem)
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func setupKeyboardActions() {
        hideKeyboardOnTap()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    @objc func themeChanged() {
        greyBgView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
        largeCollectionView.backgroundColor = Colors.backgroundTableView
        view.backgroundColor = Colors.backgroundThumbnailCollectionView
        smallCollectionView.backgroundColor = Colors.backgroundThumbnailCollectionView
        middleStackView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
    
        textField.backgroundColor = .clear
        
        backgroundView1.backgroundColor = Colors.secondary
        backgroundView2.backgroundColor = Colors.secondary
        
        stackView.backgroundColor = Colors.backgroundPreviewCollectionViewCell
                        
        setupNavigationbar()
        reloadData()
    }
    
    private func setupCollectionViews() {
        let layout = MediaPreviewFlowLayout()
        layout.scrollDirection = .horizontal
        
        largeCollectionView.collectionViewLayout = layout
        largeCollectionView.delegate = mainCollectionViewController
        largeCollectionView.dataSource = mainCollectionViewController
        largeCollectionView.isPagingEnabled = true
        largeCollectionView.allowsMultipleSelection = false
        largeCollectionViewContainerView.delegate = self
        
        setupSmallCollectionView()
    }
    
    private func setupSmallCollectionView() {
        smallCollectionView.delegate = miniController!
        smallCollectionView.dataSource = miniController!
        smallCollectionView.allowsMultipleSelection = false
        smallCollectionView.allowsSelection = true
        
        smallCollectionView.dragInteractionEnabled = true
        smallCollectionView.dragDelegate = miniController!
        smallCollectionView.dropDelegate = miniController!
        
        smallCollectionView.showsHorizontalScrollIndicator = true
        
        smallCollectionView.register(
            ConversationDescriptionCell.self,
            forCellWithReuseIdentifier: "ConversationDescriptionCell"
        )
    }
    
    private func setupCaptionTextfield() {
        textField.attributedPlaceholder = NSAttributedString(
            string: BundleUtil.localizedString(forKey: "add_caption_to_image"),
            attributes: [NSAttributedString.Key.foregroundColor: Colors.textVeryLight]
        )
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.delegate = self
        
        // Setup grey background view to separate items and caption view from thumbnails
        greyBgViewBottomConstraint.constant = smallCollectionView.frame.height
        greyBgView.backgroundColor = Colors.backgroundView
        
        largeCollectionView.backgroundColor = Colors.backgroundTableView
        
        textField.backgroundColor = Colors.backgroundTextView
        textField.borderStyle = .none
        textField.minimumFontSize = 17.0
    }
    
    private func setupToolbar() {
        backgroundView1.layer.cornerRadius = backgroundView1.frame.width / 2
        backgroundView2.layer.cornerRadius = backgroundView1.frame.width / 2
        backgroundView1.backgroundColor = Colors.chatBubbleSent
        backgroundView2.backgroundColor = Colors.chatBubbleSent
        
        if !debugColors {
            view1.backgroundColor = .clear
            view2.backgroundColor = .clear
            view3.backgroundColor = .clear
            stackViewToolbar.backgroundColor = .clear
        }
        
        trashButton.setImage(BundleUtil.imageNamed("trash_")?.withTint(.primary), for: .normal)
        previewButton.setImage(BundleUtil.imageNamed("eye_")?.withTint(.primary), for: .normal)
    }
    
    /// Setup of navigation items and header view
    private func setupNavigationbar() {
        // Setup navigation items
        if !backIsCancel {
            let items: [UIBarButtonItem]
            let buttonItem = ChevronBarButtonItem(target: self, action: #selector(backButtonPressed))
            items = buttonItem.asLeftBarButtonItem()
            navigationItem.leftBarButtonItems = items
        }
        else {
            let backButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(backButtonPressed)
            )
            navigationItem.leftBarButtonItems = [backButtonItem]
        }
        
        setupOrUpdateRightBarButtonItem()
        
        setupTitleView(landscape: MediaPreviewViewController.isLandscape())
    }
    
    func setupTitleView(landscape: Bool) {
        // Setup title view
        let size: CGFloat = 26.0
        let headerViewInset: CGFloat = size / 2
        
        // Use the small size of the device
        let viewWidth = view.frame.width < view.frame.height ? view.frame.width : view.frame.height
        var rightBarButtonWidth = size
        let leftBarButtonWidth: CGFloat = 40.0
        
        if let rightButton = navigationItem.rightBarButtonItem?.customView as? UIButton {
            rightButton.sizeToFit()
            rightBarButtonWidth += rightButton.frame.size.width
        }
        
        let widthAvailable: CGFloat = UIDevice.current
            .userInterfaceIdiom == .pad ? viewWidth / 2 : (viewWidth - leftBarButtonWidth - rightBarButtonWidth)
        let finalWidth = widthAvailable - (2 * headerViewInset)
        
        let fullHeight: Double = landscape ? 32.0 : 42.0
        
        let titleViewSize = CGRect(x: 0.0, y: 0.0, width: Double(finalWidth), height: fullHeight)
        
        let tapAction = optionsEnabled ? { [weak self] in self?.moreButtonPressed() } : nil
        
        let headerView = HeaderView(for: mediaData, frame: titleViewSize, tapAction: tapAction)
        headerView.rotate(landscape: landscape, newWidth: titleViewSize.width)

        guard let veryLeftItem = navigationItem.leftBarButtonItems?.first else {
            let message = "Could not get cancel or back item"
            DDLogError(message)
            return
        }
        
        if landscape, UIDevice.current.userInterfaceIdiom != .pad {
            navigationItem.leftBarButtonItems = [veryLeftItem]
            navigationItem.titleView = headerView
        }
        else {
            let headerViewItem = UIBarButtonItem(customView: headerView)
            navigationItem.leftBarButtonItems? = [veryLeftItem, headerViewItem]
            navigationItem.titleView = nil
        }
    }
    
    @objc private func pressedAction() {
        moreButtonPressed()
        dismissKeyboard()
    }
    
    func hideKeyboardOnTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        tap.numberOfTouchesRequired = 1
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == navigationItem.rightBarButtonItem {
            return false
        }
        if touch.view == textField {
            return false
        }
        return true
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
    
    @objc func dismissKeyboard() {
        textField.resignFirstResponder()
    }
    
    func addAccessibilityLabels() {
        textField.accessibilityLabel = BundleUtil.localizedString(forKey: "add_caption_to_image")
        trashButton.accessibilityLabel = BundleUtil.localizedString(forKey: "delete")
        previewButton.accessibilityLabel = BundleUtil
            .localizedString(forKey: "media_preview_preview_button_accessibility_label")
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func initWithMedia(
        dataArray: [Any],
        completion: (([Any], Bool, [String]) -> Void)?,
        itemDelegate: MediaPreviewURLDataProcessor
    ) {
        self.completion = completion
        self.itemDelegate = itemDelegate
        
        mainCollectionViewController = MainCollectionViewController(delegate: self)
        miniController = ThumbnailCollectionViewController()
        miniController?.parent = self
        
        resetMediaTo(dataArray: dataArray, reloadData: false)
    }
    
    @objc func resetMediaTo(dataArray: [Any], reloadData: Bool) {
        guard let itemDelegate else {
            fatalError("ItemDelegate must be set")
        }
        
        let loadedItems = itemDelegate.loadItems(dataArray: dataArray)
        mediaData = loadedItems.items
        errorList = loadedItems.errors
        
        if reloadData {
            self.reloadData()
            if !errorList.isEmpty {
                showError(errorList: errorList)
                errorList = []
            }
        }
    }
    
    private func showError(errorList: [PhotosPickerError]) {
        let items = errorList.count
        
        var title = BundleUtil.localizedString(forKey: "could_not_add_items_title")
        var message = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "multiple_media_items_could_not_be_processed"),
            items
        )
        
        if let itemDelegate, itemDelegate.memoryConstrained,
           errorList.contains(where: { $0 == .fileTooLargeForShareExtension }) {
            title = BundleUtil.localizedString(forKey: "could_not_add_all_items_memory_constrained_title")
            message = BundleUtil.localizedString(forKey: "could_not_add_all_items_memory_constrained_message")
        }
        else if !errorList.isEmpty, errorList.filter({ $0 != .fileTooLargeForSending }).isEmpty {
            title = BundleUtil.localizedString(forKey: "could_not_add_all_items_memory_constrained_title")
            message = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "error_message_file_too_big"),
                FileUtility.getFileSizeDescription(from: Int64(kMaxFileSize))
            )
        }
        else if items == 1 {
            title = BundleUtil.localizedString(forKey: "could_not_add_all_items_title")
            message = BundleUtil.localizedString(forKey: "one_media_item_could_not_be_processed")
        }
        
        UIAlertTemplate.showAlert(owner: self, title: title, message: message, actionOk: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.mediaData.isEmpty {
                strongSelf.backButtonPressed()
            }
        })
    }
    
    func reloadData() {
        largeCollectionView.reloadData()
        smallCollectionView.reloadData()
        
        updateSelection()
    }
    
    func reloadCollectionViewData() {
        largeCollectionView.reloadData()
        smallCollectionView.reloadData()
        DispatchQueue.main.async {
            self.smallCollectionView.selectItem(
                at: IndexPath(item: 0, section: 0),
                animated: false,
                scrollPosition: .left
            )
        }
    }
    
    func presentSizeAlertWithSize(size: Int64) {
        let size = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let allowed = ByteCountFormatter.string(fromByteCount: Int64(kMaxFileSize), countStyle: .file)
        
        let title = BundleUtil.localizedString(forKey: "item_too_large_title")
        let message = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "maximum_file_size_exceeded"),
            allowed,
            size
        )
        
        UIAlertTemplate.showAlert(owner: self, title: title, message: message)
    }
    
    @objc func sendButtonPressed(_ sender: Any) {
        navigationItem.rightBarButtonItem?.isEnabled = false
        let label = BundleUtil.localizedString(forKey: "processing_items_progress")
        let progressViewHandler = ProgressViewHandler(
            view: view,
            totalWorkItems: mediaData.count,
            label: label
        )
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
                }
                else {
                    progressViewHandler.incrementItemProgress(100)
                }
            }
            DispatchQueue.main.async {
                progressViewHandler.hideHud { [weak self] in
                    self?.completion?(returnVal, sendAsFile, captions)
                    self?.itemDelegate = nil
                }
            }
        }
    }
    
    @IBAction func previewTapped(_ sender: Any) {
        guard let indexPath = getCurrentlyVisibleItem() else {
            return
        }
        let cell = largeCollectionView.cellForItem(at: indexPath) as! DocumentPreviewCell
        cell.showPreview()
    }
    
    @IBAction func trashButtonTapped(_ sender: Any) {
        guard let indexPath = getCurrentlyVisibleItem() else {
            return
        }
        
        mediaData[indexPath.item].removeItem()
        
        _ = mediaData.remove(at: indexPath.item)
        
        largeCollectionView.deleteItems(at: [indexPath])
        smallCollectionView.deleteItems(at: [indexPath])
        
        if mediaData.isEmpty {
            backButtonPressed()
        }
        else {
            let newItem = min(indexPath.item, mediaData.count - 1)
            currentItem = IndexPath(item: newItem, section: indexPath.section)
            
            updateSelection()
        }
        updateTitleLabel()
    }
    
    private func updateTitleLabel() {
        if let headerView = navigationItem.titleView as? HeaderView {
            headerView.updateTitleLabel(mediaPreviewItems: mediaData)
        }
        if let headerView = navigationItem.leftBarButtonItems?.last?.customView as? HeaderView {
            headerView.updateTitleLabel(mediaPreviewItems: mediaData)
        }
    }
    
    override open func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        selection = getCurrentlyVisibleItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration / 2) {
            self.largeCollectionView.collectionViewLayout.invalidateLayout()
        }
        
        let isLandscape = toInterfaceOrientation.isLandscape
        setupTitleView(landscape: isLandscape)
    }
    
    func updateSelection() {
        guard let indexPath = getCurrentlyVisibleItem() else {
            return
        }
        
        guard mediaData.count >= currentItem.count else {
            return
        }
        
        updateTextForIndex(indexPath: indexPath, animated: true)
        largeCollectionViewContainerView.currentImage = mediaData[min(indexPath.item, mediaData.count - 1)]
        
        DispatchQueue.main.async {
            self.smallCollectionView.selectItem(
                at: indexPath,
                animated: true,
                scrollPosition: UICollectionView.ScrollPosition.centeredHorizontally
            )
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        }
    }
    
    func moreButtonPressed() {
        let storyboardName = "MediaShareStoryboard"
        let storyboardBundle = Bundle(for: MediaPreviewViewController.self)
        let sb = UIStoryboard(name: storyboardName, bundle: storyboardBundle)
        let moreOptionsNavigationController = sb
            .instantiateViewController(withIdentifier: "moreOptionsNavigationController")
        
        (moreOptionsNavigationController.children.first as? MediaShareOptionsViewController)?
            .setupOptions(
                options: MediaShareOptionsViewController
                    .ImageSendOptions(sendAsFile: mediaData[0].sendAsFile, imageQuality: "")
            )
        
        present(moreOptionsNavigationController, animated: true, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            (moreOptionsNavigationController.children.first as? MediaShareOptionsViewController)?.delegate = strongSelf
        })
    }
    
    func updateOptions(imageSendOptions: MediaShareOptionsViewController.ImageSendOptions) {
        if !mediaData.isEmpty {
            for index in 0...mediaData.count - 1 {
                let item = mediaData[index]
                item.sendAsFile = imageSendOptions.sendAsFile
            }
        }
    }

    func addButtonPressed() {
        itemDelegate!.returnAction(mediaData: mediaData)
    }
    
    @objc func backButtonPressed() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kMediaPreviewPauseVideo), object: nil)
        if backIsCancel {
            dismiss(animated: true, completion: nil)
            itemDelegate?.executeCancelAction()
        }
        else {
            dismiss(animated: true, completion: nil)
            itemDelegate!.returnAction(mediaData: mediaData)
        }
    }
    
    @objc static func isURLItem(item: MediaPreviewItem) -> Bool {
        item.originalAsset == nil && item.itemURL != nil
    }
    
    func shouldScrollTo(indexPath: IndexPath, animated: Bool = true) {
        currentItem = indexPath
        DispatchQueue.main.async {
            self.largeCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.scrollToItem(at: self.currentItem, at: .centeredHorizontally, animated: animated)
            self.smallCollectionView.selectItem(
                at: self.currentItem,
                animated: true,
                scrollPosition: .centeredHorizontally
            )
        }
        updateTextForIndex(indexPath: currentItem, animated: true)
        UIAccessibility.post(
            notification: .pageScrolled,
            argument: "Item \(currentItem.item + 1) of \(mediaData.count)"
        )
    }
    
    func getCurrentlyVisibleItem() -> IndexPath? {
        currentItem
    }
    
    @IBAction func captionEditingChanged(_ sender: Any) {
        guard let indexPath = getCurrentlyVisibleItem() else {
            return
        }
        mediaData[indexPath.item].caption = textField.text
        updateTextAlignment()
    }
    
    func updateTextForIndex(indexPath: IndexPath, animated: Bool) {
        if mediaData.count - 1 < indexPath.item || mediaData.isEmpty {
            return
        }
        DispatchQueue.main.async {
            let index = indexPath.item
            let textColor = Colors.text
            let tintColor: UIColor = .primary
            
            if !animated {
                self.textField.text = self.mediaData[index].caption
            }
            else {
                self.textField.text = self.mediaData[index].caption
                let fadeOut = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: { [weak self] in
                    self?.textField.textColor = self?.textField.backgroundColor
                    self?.textField.tintColor = .clear
                    self?.textField.text = ""
                })
                
                let fadeIn = UIViewPropertyAnimator(duration: 0.2, curve: .easeOut, animations: { [weak self] in
                    self?.textField.textColor = textColor
                    self?.textField.tintColor = tintColor
                    let index = indexPath.item
                    self?.textField.text = self?.mediaData[index].caption
                })
                
                fadeOut.addCompletion { _ in
                    fadeIn.startAnimation()
                }
                fadeOut.startAnimation()
            }
            self.updateTextAlignment()
        }
        updateSymbols(indexPath: indexPath, animated: animated)
    }
    
    func updateSymbols(indexPath: IndexPath, animated: Bool) {
        if mediaData.count - 1 < indexPath.item || mediaData.isEmpty {
            return
        }
        let index = indexPath.item
        let item = mediaData[index]
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
        _ = bottomLayoutConstraint?.constant
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let endFrameY = endFrame?.origin.y ?? 0
            
            let duration: TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
                .doubleValue ?? 0
            
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve = UIView.AnimationOptions(rawValue: animationCurveRaw)
            
            var delay = TimeInterval(0)
            
            if endFrameY >= UIScreen.main.bounds.size.height {
                bottomLayoutConstraint?.constant = 0.0
            }
            else {
                if let endFrame {
                    let safeInset: CGFloat = view.safeAreaInsets.bottom
                    let convertedEndframe = view.convert(endFrame, from: UIScreen.main.coordinateSpace)
                    let intersection = view.frame.intersection(convertedEndframe).height
                    bottomLayoutConstraint?.constant = -max(
                        intersection - smallCollectionView.frame.height - safeInset,
                        0
                    )
                    
                    delay = TimeInterval(view.safeAreaInsets.bottom * (0.25 / intersection) / 3)
                }
                else {
                    bottomLayoutConstraint?.constant = 0.0
                }
            }
            
            UIView.animate(
                withDuration: duration,
                delay: delay,
                options: animationCurve,
                animations: {
                    self.view.layoutIfNeeded()
                },
                completion: { [weak self] _ in
                    guard let strongSelf = self,
                          strongSelf.largeCollectionView.numberOfSections > 0,
                          strongSelf.largeCollectionView.numberOfItems(inSection: 0) > 0 else {
                        return
                    }
                    guard let currentlyVisibleItem = strongSelf.getCurrentlyVisibleItem() else {
                        return
                    }
                    strongSelf.largeCollectionView.scrollToItem(
                        at: currentlyVisibleItem,
                        at: .centeredHorizontally,
                        animated: false
                    )
                }
            )
        }
    }
    
    override open func didReceiveMemoryWarning() {
        guard let currentItem = getCurrentlyVisibleItem() else {
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

// MARK: - UITextFieldDelegate

extension MediaPreviewViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
    
    public func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if let oldString = textField.text {
            let newString = oldString.replacingCharacters(in: Range(range, in: oldString)!, with: string)
            if newString.lengthOfBytes(using: .utf8) <= kMaxCaptionLen {
                return true
            }
        }
        NotificationPresenterWrapper.shared.present(type: .captionTooLong)
        return false
    }
}

extension MediaPreviewViewController {
    static func isLandscape() -> Bool {
        UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height
    }
}
