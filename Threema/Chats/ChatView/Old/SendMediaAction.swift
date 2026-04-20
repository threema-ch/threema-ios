import CocoaLumberjackSwift
import FileUtility
import Foundation
import MBProgressHUD
import Photos
import UIKit

final class SendMediaAction: NSObject {
   
    enum MediaPickerType {
        case takePhoto
        case chooseExisting
    }
    
    // MARK: - Private properties

    private let imageSender = ImageURLSenderItemCreator()
    private var picker: UIImagePickerController?
    private var pickedVideoSent = false
    private var pickedVideoSaved = false
    private var cancelled = false
    private var pickedVideoURL: URL?
    private var videoEncoders = Set<AVAssetExportSession>()
    private var videoEncodeProgressHUD: MBProgressHUD?
    private var helper: PhotosAccessHelper?
    private var mediaPreviewDataProcessor: MediaPreviewDataProcessor?
    private var sequentialSendTimer: Timer?
    private var lastProgress: Float = 0.0
    private let conversationEntityObjectID: NSManagedObjectID
    private weak var chatViewController: ChatViewController?
    
    // MARK: - Lifecycle
    
    init(chatViewController: ChatViewController) {
        self.chatViewController = chatViewController
        self.conversationEntityObjectID = chatViewController.conversation.objectID
    }
    
    // MARK: - Functions
    
    private func diffSelection(assets: [Any], from previouslySelected: [MediaPreviewItem]?) -> [Any] {
        guard let previouslySelected else {
            return assets
        }
        
        var urlItems: [Any] = []
        for item in previouslySelected {
            if MediaPreviewViewController.isURLItem(item: item) {
                urlItems.append(item)
            }
        }
        
        var selection: [Any] = []
        
        selection.append(urlItems)
        
        for (index, asset) in assets.enumerated() {
            guard let asset = asset as? DKAsset else {
                continue
            }
            
            let found = MediaPreviewDataProcessor.contains(asset: asset, itemList: previouslySelected)
            
            if found == -1 {
                selection.insert(asset, at: index + urlItems.count)
            }
            else {
                selection.insert(previouslySelected[found], at: index + urlItems.count)
            }
        }
        // Since we init the array as empty, it leads to having one extra element at the end.
        selection.removeLast()
        return selection
    }
    
    func executeAction(withType mediaPickerType: MediaPickerType) {
        if mediaPickerType == .chooseExisting {
            showPhotoPicker(lastSelection: nil)
        }
        else if mediaPickerType == .takePhoto {
            let imagePicker = UIImagePickerController()
            picker = imagePicker
            imagePicker.delegate = self
            
            if mediaPickerType == .chooseExisting {
                imagePicker.sourceType = .photoLibrary
            }
            else {
                imagePicker.sourceType = .camera
            }
            
            var myMediaTypes = [String]()
            if let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: imagePicker.sourceType) {
                if availableMediaTypes.contains(UTType.image.identifier) {
                    myMediaTypes.append(UTType.image.identifier)
                }
                if availableMediaTypes.contains(UTType.movie.identifier) {
                    myMediaTypes.append(UTType.movie.identifier)
                }
            }
            
            imagePicker.mediaTypes = myMediaTypes
            imagePicker.videoMaximumDuration = MediaConverter.videoMaxDurationInMinutes() * 60

            // Always request high quality from UIImagePickerController, and transcode by ourselves later
            imagePicker.videoQuality = .typeHigh
            
            var flashMode: UIImagePickerController.CameraFlashMode = .auto
            if AppGroup.userDefaults().dictionaryRepresentation().keys.contains("cameraFlashMode") {
                flashMode = UIImagePickerController
                    .CameraFlashMode(rawValue: AppGroup.userDefaults().integer(forKey: "cameraFlashMode")) ?? .auto
            }
            imagePicker.cameraFlashMode = flashMode
            
            chatViewController?.present(imagePicker, animated: true, completion: nil)
        }
        else {
            DDLogError("Invalid MediaPickerType")
        }
    }
    
    private func showPhotoPicker(lastSelection: [Any]?) {
        var previouslySelected = [MediaPreviewItem]()
        
        let limit = 50
        
        if mediaPreviewDataProcessor == nil {
            mediaPreviewDataProcessor = MediaPreviewDataProcessor()
        }
        
        guard let mediaPreviewDataProcessor else {
            return
        }
        
        // Create the helper instance
        helper = PhotosAccessHelper { (assets: [Any], pickerController: DKImagePickerController?) in
            
            let storyboard = UIStoryboard(
                name: "MediaShareStoryboard",
                bundle: Bundle(for: MediaPreviewViewController.self)
            )
            guard let navController = storyboard.instantiateInitialViewController() as? UINavigationController,
                  let selectionViewController = navController.topViewController as? MediaPreviewViewController
            else {
                DDLogError("Failed to instantiate MediaNavController")
                return
            }
            
            if !assets.isEmpty {
                if assets.first is DKAsset {
                    let dismissable = self.chatViewController?.presentedViewController?.presentingViewController
                    let initialSelection = self.diffSelection(assets: assets, from: previouslySelected)
                    
                    selectionViewController.initWithMedia(
                        dataArray: initialSelection,
                        completion: { selection, asFile, captions in
                            Task { @MainActor in
                                dismissable?.dismiss(animated: true) {
                                    self.sendAssets(
                                        assets: selection,
                                        asFile: asFile,
                                        withCaptions: captions,
                                        completion: nil
                                    )
                                }
                            }
                        },
                        itemDelegate: mediaPreviewDataProcessor
                    )
                    
                    Task { @MainActor in
                        selectionViewController.modalPresentationStyle = .overCurrentContext
                        self.chatViewController?.presentedViewController?.present(navController, animated: true)
                    }
                    
                    mediaPreviewDataProcessor.addMore = { (
                        defaultSelection: [Any],
                        prevSelection: [MediaPreviewItem]
                    ) in
                        Task { @MainActor in
                            pickerController?.defaultSelectedAssets = defaultSelection.compactMap { $0 as? DKAsset }
                            previouslySelected = prevSelection
                            if let picker = pickerController?
                                .UIDelegate as? ThreemaImagePickerControllerDefaultUIDelegate {
                                picker.updateButton()
                            }
                            selectionViewController.dismiss(animated: true)
                        }
                    }
                    
                    mediaPreviewDataProcessor.returnToMe = { (
                        defaultSelection: [DKAsset],
                        prevSelection: [MediaPreviewItem]
                    ) in
                        Task { @MainActor in
                            pickerController?.defaultSelectedAssets = defaultSelection
                            previouslySelected = prevSelection
                            if let picker = pickerController?
                                .UIDelegate as? ThreemaImagePickerControllerDefaultUIDelegate {
                                picker.updateButton()
                            }
                            selectionViewController.dismiss(animated: true)
                        }
                    }
                    
                    mediaPreviewDataProcessor.cancelAction = { [weak self] in
                        self?.clearTemporaryDirectoryItems(items: assets)
                    }
                }
                else {
                    let allAssets: [Any] =
                        if let lastSelection {
                            lastSelection + assets
                        }
                        else {
                            assets
                        }
                    
                    selectionViewController.initWithMedia(
                        dataArray: allAssets,
                        completion: { selection, asFile, captions in
                            Task { @MainActor in
                                selectionViewController.dismiss(animated: true) {
                                    self.sendAssets(
                                        assets: selection,
                                        asFile: asFile,
                                        withCaptions: captions,
                                        completion: nil
                                    )
                                }
                            }
                        },
                        itemDelegate: mediaPreviewDataProcessor
                    )
                    
                    Task { @MainActor in
                        selectionViewController.backIsCancel = true
                        self.chatViewController?.present(navController, animated: true)
                    }
                    
                    mediaPreviewDataProcessor.returnToMe = { [weak self] (_: [Any], prevSelection: [Any]) in
                        Task { @MainActor in
                            selectionViewController.dismiss(animated: true)
                        }
                        self?.clearTemporaryDirectoryItems(items: prevSelection)
                    }
                    
                    mediaPreviewDataProcessor.addMore = { [weak self] (_: [Any], prevSelection: [MediaPreviewItem]) in
                        Task { @MainActor in
                            previouslySelected = prevSelection
                            self?.helper = PhotosAccessHelper { (defaultAssets: [Any], _: DKImagePickerController?) in
                                let newAssets = prevSelection + defaultAssets
                                selectionViewController.resetMediaTo(dataArray: newAssets, reloadData: true)
                            }
                            self?.helper?.showPicker(
                                viewController: selectionViewController,
                                limit: 50 - prevSelection.count
                            )
                        }
                    }
                    
                    mediaPreviewDataProcessor.cancelAction = { [weak self] in
                        self?.clearTemporaryDirectoryItems(items: assets)
                    }
                }
            }
        }
        if let chatViewController {
            Task { @MainActor in
                self.helper?.showPicker(viewController: chatViewController, limit: limit)
            }
        }
    }

    private func setupDKImagePickerController() -> DKImagePickerController {
        let pickerController = DKImagePickerController()
        pickerController.assetType = .allAssets
        pickerController.showsCancelButton = true
        pickerController.showsEmptyAlbums = false
        pickerController.allowMultipleTypes = true
        pickerController.autoDownloadWhenAssetIsInCloud = true
        pickerController.defaultSelectedAssets = []
        pickerController.sourceType = .photo
        pickerController.maxSelectableCount = 50
        pickerController.UIDelegate = ThreemaImagePickerControllerDefaultUIDelegate()
        pickerController.allowsLandscape = true
        
        return pickerController
    }
    
    func showPreviewForAssets(assets: [Any]) {
        showPreviewForAssets(assets: assets, showKeyboard: false)
    }
    
    func showPreviewForAssets(assets: [Any], showKeyboard: Bool) {
        let storyboard = UIStoryboard(
            name: "MediaShareStoryboard",
            bundle: Bundle(for: MediaPreviewViewController.self)
        )
        let navController = storyboard.instantiateInitialViewController() as! ThemedNavigationController
        let selectionViewController = navController.topViewController as! MediaPreviewViewController
        selectionViewController.showKeyboard = showKeyboard
        selectionViewController.backIsCancel = true

        if let first = assets.first, !(first is PHAsset) {
            selectionViewController.disableAdd = true
        }

        if mediaPreviewDataProcessor == nil {
            mediaPreviewDataProcessor = MediaPreviewDataProcessor()
        }
        
        guard let mediaPreviewDataProcessor else {
            return
        }

        selectionViewController.initWithMedia(dataArray: assets, completion: { selection, asFile, captions in
            selectionViewController.dismiss(animated: true) {
                self.sendAssets(assets: selection, asFile: asFile, withCaptions: captions) {
                    self.clearTemporaryDirectoryItems(items: assets)
                }
            }
        }, itemDelegate: mediaPreviewDataProcessor)
      
        mediaPreviewDataProcessor.returnToMe = { [weak self] _, prevSelection in
            Task { @MainActor in
                selectionViewController.dismiss(animated: true)
            }
            self?.clearTemporaryDirectoryItems(items: prevSelection)
        }

        mediaPreviewDataProcessor.addMore = { [weak self] defaultSelection, prevSelection in
            guard let self else {
                return
            }
            let pickerController = setupDKImagePickerController()
            pickerController.defaultSelectedAssets = defaultSelection.compactMap { $0 as? DKAsset }
            selectionViewController.present(pickerController, animated: true)

            pickerController.didSelectAssets = { [weak pickerController] selectedAssets in
                pickerController?.dismiss(animated: true)
                let selection = self.diffSelection(assets: selectedAssets, from: prevSelection)
                selectionViewController.resetMediaTo(dataArray: selection, reloadData: true)
            }
        }

        mediaPreviewDataProcessor.cancelAction = { [weak self] in
            self?.clearTemporaryDirectoryItems(items: assets)
        }

        chatViewController?.present(navController, animated: true)
    }
    
    private func prepareAssets(assets: [Any], target itemArray: inout [Any]?, asFile sendAsFile: Bool) {
        for i in 0..<assets.count {
            autoreleasepool {
                if let asset = assets[i] as? PHAsset {
                    let item: URLSenderItem? =
                        if asset.mediaType == .image {
                            getSenderItemForImageAsset(asset, asFile: sendAsFile)
                        }
                        else {
                            getSenderItemForVideoAsset(asset, asFile: sendAsFile)
                        }
                
                    if cancelled {
                        itemArray = nil
                        Task { @MainActor in
                            self.hideVideoEncodeProgressHUD()
                        }
                        clearTemporaryDirectoryItems(items: assets)
                        return
                    }
                    else if let item {
                        itemArray?.append(item)
                    }
                    else {
                        DDLogError("Unknown error while processing asset")
                    }
                }
                else if let url = assets[i] as? URL {
                    let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
                    if UTIConverter.conforms(toImageType: uti) {
                        let item: URLSenderItem? =
                            if sendAsFile {
                                URLSenderItem(
                                    url: url,
                                    type: UTIConverter.uti(forFileURL: url),
                                    renderType: 0,
                                    sendAsFile: true
                                )
                            }
                            else {
                                URLSenderItemCreator.getSenderItem(for: url)
                            }
                    
                        if let item {
                            itemArray?.append(item)
                        }
                        else {
                            DDLogError("Could not create URLSenderItem from media asset")
                        }
                    }
                    else if UTIConverter.conforms(toMovieType: uti) {
                        // All videos in the format of an URL come from the media preview and have already been
                        // converted
                        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
                        let item = URLSenderItem(
                            url: url,
                            type: mimeType,
                            renderType: sendAsFile ? 0 : 1,
                            sendAsFile: true
                        )
                        if let item {
                            itemArray?.append(item)
                        }
                        else {
                            DDLogError("Could not create URLSenderItem from media asset")
                        }
                    }
                    else {
                        let item = URLSenderItemCreator.getSenderItem(for: url)
                        if let item {
                            itemArray?.append(item)
                        }
                        else {
                            DDLogError("Could not create URLSenderItem from url")
                        }
                    }
                }
            
                Task { @MainActor in
                    var text = BundleUtil.localizedString(forKey: "processing_items_progress")
                    self.incrementVideoProgressHUD(by: 100, with: &text, placeholderIncluded: true)
                }
            
                if cancelled {
                    itemArray = nil
                    Task { @MainActor in
                        self.hideVideoEncodeProgressHUD()
                    }
                    clearTemporaryDirectoryItems(items: assets)
                    return
                }
            }
        }
    }
    
    private func sendItems(itemArray: [Any], asFile sendAsFile: Bool, withCaptions captions: [Any]) {
        let correlationID = imageSender.createCorrelationID()
        let itemsCount = itemArray.count

        for i in 0..<itemsCount {
            autoreleasepool {
                if cancelled {
                    Task { @MainActor in
                        self.hideVideoEncodeProgressHUD()
                    }
                    return
                }
                
                let sequentialSemaphore = DispatchSemaphore(value: 0)

                if let item = itemArray[i] as? URLSenderItem {
                    if captions.count == itemsCount, !(captions[i] as? String ?? "").isEmpty {
                        item.caption = captions[i] as? String
                    }
                    Task {
                        let messageSender = BusinessInjector.ui.messageSender
                        do {
                            try await messageSender.sendBlobMessage(
                                for: item,
                                in: conversationEntityObjectID,
                                correlationID: correlationID,
                                webRequestID: nil
                            )
                        }
                        catch {
                            DDLogError("Could not create message and sync blobs due to: \(error)")
                        }
                        
                        sequentialSemaphore.signal()
                    }
                    sequentialSemaphore.wait()
                }
                else if let item = itemArray[i] as? AVAsset {
                    // Video
                    let caption: String =
                        if captions.count == itemsCount {
                            (captions[i] as? String) ?? ""
                        }
                        else {
                            ""
                        }
                    
                    sendVideoAsset(item, caption: caption) {
                        sequentialSemaphore.signal()
                    }
                    sequentialSemaphore.wait()

                    sequentialSendTimer = Timer.scheduledTimer(
                        timeInterval: 0.1,
                        target: self,
                        selector:
                        #selector(checkVideoDone),
                        userInfo: nil,
                        repeats: true
                    )
                }
            }
        }
    }
    
    func sendAssets(assets: [Any], asFile sendAsFile: Bool, withCaptions captions: [Any], completion: (() -> Void)?) {
        var itemArray: [Any]? = []
        let text = BundleUtil.localizedString(forKey: "processing_items_progress")
        showVideoEncodeProgressHUD(with: assets.count * 100, text: text)

        videoEncodeProgressHUD?.progressObject?.totalUnitCount = Int64(assets.count * 100)

        Task(priority: .userInitiated) {
            prepareAssets(assets: assets, target: &itemArray, asFile: sendAsFile)

            if cancelled {
                Task { @MainActor in
                    self.hideVideoEncodeProgressHUD()
                }
                clearTemporaryDirectoryItems(items: assets)
                return
            }

            let popTime = DispatchTime.now() + DispatchTimeInterval.seconds(1)
           
            DispatchQueue.main.asyncAfter(deadline: popTime) {
                self.hideVideoEncodeProgressHUD()
            }
            
            guard let itemArray else {
                return
            }
            
            sendItems(itemArray: itemArray, asFile: sendAsFile, withCaptions: captions)

            clearTemporaryDirectoryItems(items: assets)
            clearTemporaryDirectoryItems(items: itemArray)

            completion?()
        }
    }
    
    private func clearTemporaryDirectoryItems(items: [Any]) {
        Task {
            DDLogInfo("Started clearing items in temporary directory.")
                        
            for i in 0..<items.count {
                let url: URL? =
                    if let item = items[i] as? MediaPreviewItem {
                        item.itemURL
                    }
                    else if let item = items[i] as? URL {
                        item
                    }
                    else if let item = items[i] as? URLSenderItem {
                        item.url
                    }
                    else {
                        nil
                    }

                if let url {
                    do {
                        if url.isFileURL, !url.lastPathComponent.isEmpty {
                            // Cleanup thumbnail after video recoring, naming is like the video
                            // file it self with the extension '.largeThumbnail' instaed of '.MOV'
                            let startIndex = url.absoluteString.index(
                                url.absoluteString.endIndex,
                                offsetBy: -url.lastPathComponent.count
                            )
                            let range: Range<String.Index> = startIndex..<url.absoluteString.endIndex

                            let largeThumbnailPath = url.absoluteString.replacingOccurrences(
                                of: ".\(url.pathExtension)",
                                with: ".largeThumbnail",
                                options: .caseInsensitive,
                                range: range
                            )

                            if let largeThumbnailURL = URL(string: largeThumbnailPath),
                               FileUtility.shared.fileExists(at: largeThumbnailURL) {
                                try FileUtility.shared.delete(at: largeThumbnailURL)
                                DDLogInfo("Temporary item \(largeThumbnailURL) deleted")
                            }
                        }

                        try FileUtility.shared.delete(at: url)
                        DDLogInfo("Temporary item \(url) deleted")
                    }
                    catch {
                        DDLogError("Could not clear item in temporary directory. Error: \(error)")
                    }
                }
            }
        }
    }
    
    @objc func checkVideoDone() {
        var done = true
        for exportSession in videoEncoders {
            done = exportSession.progress == 1.0
        }

        if videoEncoders.isEmpty, done {
            sequentialSendTimer?.invalidate()
        }
    }
    
    private func getSenderItemForImageAsset(_ asset: PHAsset, asFile sendAsFile: Bool) -> URLSenderItem {
        var item: URLSenderItem?
        let sema = DispatchSemaphore(value: 0)
        
        let imageManager = PHImageManager.default()
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        imageManager.requestImageData(for: asset, options: options) { [imageSender] imageData, dataUTI, _, _ in
            if let imageData {
                let resources = PHAssetResource.assetResources(for: asset)
                let orgFilename =
                    if let firstResource = resources.first {
                        firstResource.originalFilename
                    }
                    else {
                        "File"
                    }

                if sendAsFile {
                    item = URLSenderItem(
                        data: imageData,
                        fileName: orgFilename,
                        type: dataUTI ?? "",
                        renderType: 0,
                        sendAsFile: true
                    )
                }
                else {
                    item = imageSender.senderItem(from: imageData, uti: dataUTI ?? "")
                }
                sema.signal()
            }
        }
        sema.wait()
        return item!
    }
    
    private func getSenderItemForVideoAsset(_ asset: PHAsset, asFile sendAsFile: Bool) -> URLSenderItem? {
        let imageManager = PHImageManager.default()
        
        var senderItem: URLSenderItem?
        let sema = DispatchSemaphore(value: 0)
        
        let options = PHVideoRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true

        imageManager.requestAVAsset(forVideo: asset, options: options) { videoAsset, _, _ in
            let creator = VideoURLSenderItemCreator()
            creator.encodeProgressDelegate = self
            guard let videoAsset,
                  let exportSession = creator.getExportSession(for: videoAsset) else {
                DDLogError("Could not create AVAssetExportSession for media asset")
                
                sema.signal()
                return
            }
            
            self.videoEncoders.insert(exportSession)
            senderItem = creator.senderItem(from: videoAsset, on: exportSession)

            sema.signal()
        }

        sema.wait()
        return senderItem
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension SendMediaAction: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        storeFlashConfiguration(for: picker)
        
        if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
           mediaType == UTType.image.identifier {
            // Image picked
            if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
               let conversationEntity = chatViewController?.conversation {
                if picker.sourceType == .camera, UserSettings.shared().autoSaveMedia,
                   conversationEntity.conversationCategory != .private {
                    AlbumManager.shared.save(image: pickedImage)
                }
                let imageURL = PhotosAccessHelper.storeImageToTmpDir(imageData: pickedImage)
                let array = [imageURL]
                picker.dismiss(animated: true) {
                    self.showPreviewForAssets(assets: array)
                }
            }
        }
        else if let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
                mediaType == UTType.movie.identifier, let conversationEntity = chatViewController?.conversation {
            // Video picked
            pickedVideoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL
            
            pickedVideoSent = false
            pickedVideoSaved = false
            
            if let pickedVideoURL, picker.sourceType == .camera, UserSettings.shared().autoSaveMedia,
               conversationEntity.conversationCategory != .private {
                AlbumManager.shared.saveMovieToLibrary(movieURL: pickedVideoURL) { _ in
                    self.pickedVideoSaved = true
                    if self.pickedVideoSent, self.pickedVideoSaved {
                        self.clearTemporaryDirectoryItems(items: [pickedVideoURL])
                    }
                }
            }
            else {
                pickedVideoSaved = true
            }
            
            // Check video duration - if this has come from the photo library, the video may be longer than
            // videoMaximumDuration (it is not enforced if allowEditing = NO, but we don't want to enable that
            // as we don't need the image cropping UI)
            if let pickedVideoURL {
                if MediaConverter.isVideoDurationValid(at: pickedVideoURL) {
                    let array = [pickedVideoURL]
                    picker.dismiss(animated: true) {
                        self.showPreviewForAssets(assets: array)
                    }
                }
                else {
                    // Video too long - must present editor
                    let videoEditor = UIVideoEditorController()
                    videoEditor.videoQuality = .typeHigh
                    videoEditor.videoMaximumDuration = TimeInterval(MediaConverter.videoMaxDurationInMinutes()) * 60
                    videoEditor.videoPath = pickedVideoURL.path
                    videoEditor.delegate = self
                    ModalPresenter.dismissPresentedController(on: chatViewController, animated: true) {
                        self.picker = nil
                        self.chatViewController?.present(videoEditor, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        storeFlashConfiguration(for: picker)
        ModalPresenter.dismissPresentedController(on: chatViewController, animated: true) {
            self.picker = nil
        }
    }
    
    func storeFlashConfiguration(for picker: UIImagePickerController) {
        if picker.sourceType == .camera {
            let flashmode = picker.cameraFlashMode
            AppGroup.userDefaults().set(flashmode.rawValue, forKey: "cameraFlashMode")
            AppGroup.userDefaults().synchronize()
        }
    }
}

// MARK: - Media sending utility functions

extension SendMediaAction {
    
    private func sendVideoAsset(_ asset: AVAsset, caption: String, onCompletion: (() -> Void)?) {
        Task {
            let senderCreator = VideoURLSenderItemCreator()
            senderCreator.encodeProgressDelegate = self
            
            guard let exportSession = senderCreator.getExportSession(for: asset) else {
                DDLogError("VideoURL was nil.")
                NotificationPresenterWrapper.shared.presentSendingError()
                onCompletion?()
                return
            }
            
            self.videoEncoders.insert(exportSession)
            
            guard let senderItem = senderCreator.senderItem(from: asset, on: exportSession) else {
                DDLogError("SenderItem was nil.")
                NotificationPresenterWrapper.shared.presentSendingError()
                onCompletion?()
                return
            }
            
            if !caption.isEmpty {
                senderItem.caption = caption
            }
            
            let messageSender = BusinessInjector.ui.messageSender
            do {
                try await messageSender.sendBlobMessage(
                    for: senderItem,
                    in: conversationEntityObjectID,
                    correlationID: nil,
                    webRequestID: nil
                )
            }
            catch {
                DDLogError("Could not create message and sync blobs due to: \(error)")
            }
            
            onCompletion?()
        }
    }
    
    private func showVideoEncodeProgressHUD(with unitCount: Int, text: String) {
        if videoEncodeProgressHUD == nil, let view = chatViewController?.view {
            chatViewController?.resignFirstResponder()
            videoEncodeProgressHUD = MBProgressHUD.showAdded(to: view, animated: true)
            videoEncodeProgressHUD?.mode = .annularDeterminate
            videoEncodeProgressHUD?.button.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
            videoEncodeProgressHUD?.button.addTarget(
                self,
                action: #selector(progressHUDCancelPressed),
                for:
                .touchUpInside
            )
            
            videoEncodeProgressHUD?.progressObject = Progress()
            videoEncodeProgressHUD?.progressObject?.totalUnitCount = Int64(unitCount)
            
            let current = max(1, (videoEncodeProgressHUD?.progressObject!.completedUnitCount)! / 100)
            let total = (videoEncodeProgressHUD?.progressObject!.totalUnitCount)! / 100
            
            updateHUDText(withCompleted: Int(current), total: Int(total), text: text)
        }
    }
    
    private func hideVideoEncodeProgressHUD() {
        if let videoEncodeProgressHUD {
            videoEncodeProgressHUD.hide(animated: true)
            self.videoEncodeProgressHUD = nil
        }
    }
    
    private func incrementVideoProgressHUD(by incrementValue: Int, with text: inout String, placeholderIncluded: Bool) {
        if let videoEncodeProgressHUD, let progressObject = videoEncodeProgressHUD.progressObject {
            progressObject.completedUnitCount += Int64(incrementValue)
            var current = progressObject.completedUnitCount / 100
            let total = progressObject.totalUnitCount / 100
            current = min(current, total)
            current = current == 0 ? 1 : current
            
            if !placeholderIncluded {
                text = text + " %d/%d"
            }
            
            updateHUDText(withCompleted: Int(current), total: Int(total), text: text)
        }
    }
    
    private func updateHUDText(withCompleted completed: Int, total: Int, text: String) {
        videoEncodeProgressHUD?.label.text = String(format: text, completed, total)
        videoEncodeProgressHUD?.label.font = UIFont.monospacedDigitSystemFont(
            ofSize: videoEncodeProgressHUD?.label.font?.pointSize ?? 0,
            weight: .semibold
        )
    }
    
    @objc func progressHUDCancelPressed() {
        for exportSession in videoEncoders {
            exportSession.cancelExport()
        }
        
        _ = VideoURLSenderItemCreator.cleanTemporaryDirectory()
        cancelled = true
    }
}

// MARK: - VideoConversionProgressDelegate

extension SendMediaAction: VideoConversionProgressDelegate {

    func videoExportSession(exportSession: AVAssetExportSession) {
        let progress = exportSession.progress
        Task { @MainActor in
            if progress == 1.0 {
                self.lastProgress = 0
                self.videoEncoders.remove(exportSession)
            }

            if (progress - self.lastProgress) * 100 > 1 {
                var text = BundleUtil.localizedString(forKey: "processing_items_progress")
                // TODO: This is the same bad thing as in the MediaPreviewViewController
                self.incrementVideoProgressHUD(
                    by: Int(progress - self.lastProgress) * 100,
                    with: &text,
                    placeholderIncluded: true
                )
                DDLogInfo(
                    "Actual progress \(progress), incremental progress \(progress - self.lastProgress), incremented by \((progress - self.lastProgress) * 100)"
                )
                self.lastProgress = progress
            }
        }
    }
}

// MARK: - UIVideoEditorControllerDelegate

extension SendMediaAction: UIVideoEditorControllerDelegate {

    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        // Reset delegate to prevent calling this function twice
        editor.delegate = nil
        editor.dismiss(animated: true)

        // Delete original video file
        if let pickedVideoURL {
            clearTemporaryDirectoryItems(items: [pickedVideoURL])
        }

        let editedVideoURL = URL(fileURLWithPath: editedVideoPath)

        let asset = AVURLAsset(url: editedVideoURL)
        sendVideoAsset(asset, caption: "") {
            self.pickedVideoSent = true
            if self.pickedVideoSent, self.pickedVideoSaved {
                self.clearTemporaryDirectoryItems(items: [editedVideoURL])
            }
        }
    }

    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        DDLogError("Video editor failed: \(error)")
        editor.dismiss(animated: true)

        if let pickedVideoURL {
            clearTemporaryDirectoryItems(items: [pickedVideoURL])
        }
    }

    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        editor.dismiss(animated: true)

        if let pickedVideoURL {
            clearTemporaryDirectoryItems(items: [pickedVideoURL])
        }
    }
}
