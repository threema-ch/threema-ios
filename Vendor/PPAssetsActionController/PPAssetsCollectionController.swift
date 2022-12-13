import UIKit
import AVFoundation

protocol PPAssetsViewControllerDelegate: class {
    func assetsViewController(_ controller: PPAssetsCollectionController, didChange itemsCount: Int, _ onlyPhotos: Bool, _ onlyVideos: Bool)
    
    func assetsViewControllerDidRequestCameraController(_ controller: PPAssetsCollectionController)
    
    func assetsViewControllerDidRequestAuthorization(_ controller: PPAssetsCollectionController)
}

/**
 Top part of Assets Action Controller that represents camera roll assets preview.
 */
class PPAssetsCollectionController: UICollectionViewController  {
    
    public weak var delegate: PPAssetsViewControllerDelegate?
    
    private var flowLayout: PPCollectionViewLayout!
    fileprivate var heightConstraint: NSLayoutConstraint!
    private let assetManager = PPAssetManager()
    fileprivate var phAssets: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    private var selectedItemRows = Set<Int>()
    fileprivate var config: PPAssetsActionConfig!
    fileprivate var captureSession: AVCaptureSession?
    fileprivate var captureLayer: AVCaptureVideoPreviewLayer?
    
    //------------------ Threema edit begin ---------------------------
    fileprivate let cameraIsAvailable = UIImagePickerController.isSourceTypeAvailable(.camera) && AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    //------------------ Threema edit end ---------------------------

    public init(aConfig: PPAssetsActionConfig) {
        flowLayout = PPCollectionViewLayout()
        config = aConfig
        super.init(collectionViewLayout: flowLayout)
        
        flowLayout.itemsInfoProvider = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        stopCaptureSession()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.backgroundColor = UIColor.clear
        
        collectionView?.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView?.register(PPPhotoViewCell.self, forCellWithReuseIdentifier: PPPhotoViewCell.reuseIdentifier)
        collectionView?.register(PPVideoViewCell.self, forCellWithReuseIdentifier: PPVideoViewCell.reuseIdentifier)
       
        //------------------ Threema edit begin ---------------------------
        if cameraIsAvailable {
            collectionView?.register(PPLiveCameraCell.self, forCellWithReuseIdentifier: PPLiveCameraCell.reuseIdentifier)
        }
        //------------------ Threema edit end ---------------------------

        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
        
        collectionView?.delegate = self
        
        heightConstraint = NSLayoutConstraint(item: collectionView!,
                                              attribute: .height,
                                              relatedBy: .equal,
                                              toItem: nil,
                                              attribute: .notAnAttribute,
                                              multiplier: 1.0,
                                              constant: config.assetsPreviewRegularHeight)
        collectionView?.addConstraint(heightConstraint)
        
        self.flowLayout.viewWidth = self.view!.frame.width
        
        let requestImages = {
            self.assetManager.getPHAssets(imagesOnly: !self.config.showVideos, fetchLimit: self.config.fetchLimit, { (result) in
                if (result?.count)! > 0 {
                    self.phAssets = result!
                    self.collectionView?.reloadData()
                }
            })
        }
        
        if assetManager.authorizationStatus() == .authorized {
            if (config.showGalleryPreview) {
                requestImages()
            }
        } else if config.askPhotoPermissions {
            assetManager.requestAuthorization { status in
                if status == .authorized {
                    if (self.config.showGalleryPreview) {
                        requestImages()
                    }
                    self.delegate?.assetsViewControllerDidRequestAuthorization(self)
                } else {
                    self.heightConstraint.constant = 0
                }
            }
        } else {
            self.heightConstraint.constant = 0
        }
        
        if rowCountForLiveCameraCell() == 1 {
            self.setupCaptureSession()
        }
    }
    
    //------------------ Threema edit begin ---------------------------
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updatePreviewOrientation(UIDevice.current.orientation)
    }
    //------------------ Threema edit end ---------------------------
    
    
    func selectedPHMedia() -> [MediaProvider] {
        return selectedItemRows.map { phAssets[$0] }
    }
    
    func updateCollectionView() {
        collectionView?.setNeedsLayout()
        
        let flowLayout = PPCollectionViewLayout()
        flowLayout.itemsInfoProvider = self
        flowLayout.viewWidth = view.frame.width
        
        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 1.0,
                       options: .curveEaseIn,
                       animations:
                        {
            // FIXME: iOS10 layout workaround. Think of a better way.
            self.collectionView?.superview?.superview?.layoutIfNeeded()
            self.collectionView?.setCollectionViewLayout(flowLayout, animated: true)
        }) { result in
            self.collectionView?.reloadData()
        }
    }
    
    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.isHidden {
            return 0
        }
        return phAssets.count + rowCountForLiveCameraCell()
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row == 0 && rowCountForLiveCameraCell() == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PPLiveCameraCell.reuseIdentifier, for: indexPath) as! PPLiveCameraCell
            cell.backgroundColor = UIColor.black
            cell.accessibilityLabel = PPLiveCameraCell.reuseIdentifier
            if let layer = captureLayer {
                cell.set(layer: layer)
            }
            return cell
        }
        
        let mediaProvider = phAssets[modifiedRow(for: indexPath.row)]
        var cell: PPCheckedViewCell!
        
        if mediaProvider.mediaType == .video {
            let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PPVideoViewCell.reuseIdentifier, for: indexPath) as! PPVideoViewCell
            videoCell.setVideo(mediaProvider)
            cell = videoCell
        } else {
            let photoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PPPhotoViewCell.reuseIdentifier, for: indexPath) as! PPPhotoViewCell
            photoCell.set(mediaProvider)
            
            cell = photoCell
        }
        
        cell.checked.tintColor = config.tintColor
        if (heightConstraint.constant == config.assetsPreviewExpandedHeight) {
            cell.set(selected: selectedItemRows.contains(modifiedRow(for: indexPath.row)))
        }
        cell.accessibilityLabel = "asset-\(modifiedRow(for: indexPath.row))"
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if indexPath.row == 0 && rowCountForLiveCameraCell() == 1 {
            delegate?.assetsViewControllerDidRequestCameraController(self)
            return
        }
        
        if selectedItemRows.contains(modifiedRow(for: indexPath.row)) {
            selectedItemRows.remove(modifiedRow(for: indexPath.row))
        } else {
            if (config.maxSelectableAssets != 0 && config.maxSelectableAssets == selectedItemRows.count) {
                return
            }
            selectedItemRows.insert(modifiedRow(for: indexPath.row))
        }
        
        var isVideoSelected = false
        var isPhotoSelected = false
        let media = selectedPHMedia()
        for (_, value) in media.enumerated() {
            if (value.phasset()?.phassetIsImage())! {
                isPhotoSelected = true
            } else {
                isVideoSelected = true
            }
        }
        
        let onlyPhotos = isPhotoSelected && !isVideoSelected
        let onlyVideos = isVideoSelected && !isPhotoSelected
        delegate?.assetsViewController(self, didChange: selectedItemRows.count, onlyPhotos, onlyVideos)
        
        if (heightConstraint.constant < config.assetsPreviewExpandedHeight) {
            heightConstraint.constant = config.assetsPreviewExpandedHeight
            updateCollectionView()
        } else {
            if selectedItemRows.count == 0 {
                heightConstraint.constant = config.assetsPreviewRegularHeight
                updateCollectionView()
            }
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            if let cell = collectionView.cellForItem(at: indexPath) as? PPPhotoViewCell {
                cell.set(selected: selectedItemRows.contains(modifiedRow(for: indexPath.row)))
            }
        }
    }
    
    //    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    //        for cell in collectionView!.visibleCells  as [UICollectionViewCell]    {
    //            if let videoCell = cell as? PPVideoViewCell {
    //                videoCell.stopVideo()
    //            }
    //        }
    //    }
    //
    //    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    //        if velocity.x == 0 && velocity.y == 0 {
    //            for cell in self.collectionView!.visibleCells  as [UICollectionViewCell]    {
    //                if let videoCell = cell as? PPVideoViewCell {
    //                    videoCell.startVideo()
    //                }
    //            }
    //        }
    //    }
    //
    //    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    //        for cell in self.collectionView!.visibleCells  as [UICollectionViewCell]    {
    //            if let videoCell = cell as? PPVideoViewCell {
    //                videoCell.startVideo()
    //            }
    //        }
    //    }
}

// MARK: - Camera
extension PPAssetsCollectionController {
    func setupCaptureSession() {
        if let defaultDevice = AVCaptureDevice.default(for: AVMediaType.video),
           let input = try? AVCaptureDeviceInput(device: defaultDevice) {
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            captureLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            captureLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            captureSession?.startRunning()
            //------------------ Threema edit begin ---------------------------
            updatePreviewOrientation(UIDevice.current.orientation)
            //------------------ Threema edit end ---------------------------

            self.collectionView?.reloadData()
        }
    }
    
    //------------------ Threema edit begin ---------------------------
    private func updatePreviewOrientation(_ orientation: UIDeviceOrientation) {
        
        let currentOrientation: AVCaptureVideoOrientation
        
        // There seems to be a bug with the orientations in landscape
        switch orientation {
        case .landscapeRight:
            currentOrientation =  .landscapeLeft
        case .landscapeLeft:
            currentOrientation  = .landscapeRight
        case .portraitUpsideDown:
            currentOrientation = .portraitUpsideDown
        default:
            currentOrientation = .portrait
        }
        captureLayer?.connection?.videoOrientation = currentOrientation
    }
    //------------------ Threema edit end ---------------------------
    
    func stopCaptureSession() {
        if let session = captureSession {
            session.stopRunning()
            captureSession = nil
        }
    }
}

extension PPAssetsCollectionController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.row == 0 && rowCountForLiveCameraCell() == 1 {
            return CGSize(width: heightConstraint.constant, height: heightConstraint.constant)
        }
        let asset = phAssets[modifiedRow(for: indexPath.row)]
        
        if asset.pixelHeight == 0 || asset.pixelWidth == 0 {
            return CGSize(width: heightConstraint.constant, height: heightConstraint.constant)
        } else {
            let factor = heightConstraint.constant / CGFloat(asset.pixelHeight)
            return CGSize(width: CGFloat(asset.pixelWidth) * factor, height: heightConstraint.constant)
        }
    }
}

extension PPAssetsCollectionController {
    func modifiedRow(for row: Int) -> Int {
        return row - (config.showLiveCameraCell ? rowCountForLiveCameraCell() : 0)
    }
    
    func rowCountForLiveCameraCell() -> Int {
        
        //------------------ Threema edit begin ---------------------------
        return cameraIsAvailable && config.showLiveCameraCell && config.showGalleryPreview && PHPhotoLibrary.authorizationStatus() == .authorized ? 1 : 0
        //------------------ Threema edit end ---------------------------

    }
}
