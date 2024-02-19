//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import Foundation
import UIKit

protocol MWPhotoBrowserWrapperDelegate: AnyObject {
    /// Called before the browser deletes messages
    /// - Parameter objectIDs: Object IDs of messages that will be deleted
    func willDeleteMessages(with objectIDs: [NSManagedObjectID])
}

class MWPhotoBrowserWrapper: NSObject, MWPhotoBrowserDelegate, MWVideoDelegate, MWFileDelegate,
    ModalNavigationControllerDelegate {

    let conversation: Conversation
    weak var parentViewController: UIViewController?
    let entityManager: EntityManager
    // This needs to be a class property to work
    var fileMessagePreview: FileMessagePreview?
    
    private weak var delegate: MWPhotoBrowserWrapperDelegate?
    
    init(
        for conversation: Conversation,
        in parentViewController: UIViewController?,
        entityManager: EntityManager,
        delegate: MWPhotoBrowserWrapperDelegate
    ) {
        self.conversation = conversation
        self.parentViewController = parentViewController
        self.entityManager = entityManager
        self.delegate = delegate
        
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorThemeChanged(notification:)),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
    }
    
    private lazy var photoBrowser: MWPhotoBrowser? = createPhotoBrowser()
    
    private var mediaMessages = [BaseMessage]()
    private var selectedMediaMessages = Set<UInt>()
    
    func openPhotoBrowser(for message: BaseMessage?) {
        guard let message else {
            return
        }
        prepareMedia()
        
        guard let index = mediaMessages.firstIndex(of: message) else {
            DDLogError("Tapped media not found in fetched ones.")
            return
        }
        
        var autoPlayOnAppear = false
        if let fileMessageProvider = message as? FileMessageProvider {
            switch fileMessageProvider.fileMessageType {
            case .video:
                autoPlayOnAppear = true
            default:
                autoPlayOnAppear = false
            }
        }
        
        openPhotoBrowser(currentMediaIndex: UInt(index), showGrid: false, autoPlayOnAppear: autoPlayOnAppear)
    }
    
    func openPhotoBrowser() {
        openPhotoBrowser(currentMediaIndex: nil, showGrid: true)
    }
    
    // MARK: - MWPhotoBrowserDelegate

    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        UInt(mediaMessages.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        photoAtIndex(at: Int(index), thumbnail: false)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, objectIDAt index: UInt) -> NSManagedObjectID! {
        objectIDAtIndex(at: Int(index), thumbnail: false)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, thumbPhotoAt index: UInt) -> MWPhotoProtocol! {
        let media = photoAtIndex(at: Int(index), thumbnail: true)
        media?.loadUnderlyingImageAndNotify()
        
        return media
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, captionViewForPhotoAt index: UInt) -> MWCaptionView! {
        guard let media = photoBrowser.photo(at: index) else {
            return PhotoCaptionView()
        }
        
        switch media {
        case let photo as MediaBrowserPhoto:
            return PhotoCaptionView(photo: photo)
            
        case let video as MediaBrowserVideo:
            return VideoCaptionView(photo: video)
            
        case let file as MediaBrowserFile:
            return FileCaptionView(photo: file)
            
        default:
            DDLogError("Could not create caption view for photo browser")
            fatalError()
        }
    }
    
    // MARK: Deleting

    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, deleteButton: UIBarButtonItem!, pressedForPhotoAt index: UInt) {
        
        let media = photoBrowser.photo(at: index)
        let deleteButtonTitle: String
        
        switch media {
        case _ as MediaBrowserPhoto:
            deleteButtonTitle = BundleUtil.localizedString(forKey: "delete_photo")
            
        case _ as MediaBrowserVideo:
            deleteButtonTitle = BundleUtil.localizedString(forKey: "delete_video")

        case _ as MediaBrowserFile:
            deleteButtonTitle = BundleUtil.localizedString(forKey: "delete_file")

        default:
            DDLogError("Could not create caption view for photo browser")
            fatalError()
        }
        
        UIAlertTemplate.showDestructiveAlert(
            owner: photoBrowser,
            title: deleteButtonTitle,
            message: nil,
            titleDestructive: BundleUtil.localizedString(forKey: "delete")
        ) { _ in
            let indexSet: Set<UInt> = [index]
            self.deleteMedia(for: indexSet) {
                self.prepareMedia()
                
                if self.mediaMessages.isEmpty {
                    self.parentViewController?.dismiss(animated: true)
                }
                else {
                    self.photoBrowser?.reloadData(true)
                }
            }
        }
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, deleteButton: UIBarButtonItem!) {
        if !selectedMediaMessages.isEmpty {
            deleteMedia(for: selectedMediaMessages) {
                self.handleDeletion()
            }
        }
        else {
            let indexes = Set(0..<mediaMessages.count) as! Set<UInt>
            deleteMedia(for: indexes) {
                self.handleDeletion()
            }
        }
    }
    
    // MARK: Selected

    func photoBrowserResetSelection(_ photoBrowser: MWPhotoBrowser!) {
        selectedMediaMessages.removeAll()
    }
    
    func photoBrowserSelectAll(_ photoBrowser: MWPhotoBrowser!) {
        selectedMediaMessages.removeAll()
        let setOfSelectedIndexes = Set(0..<mediaMessages.count)
        selectedMediaMessages = Set(setOfSelectedIndexes.compactMap {
            UInt($0)
        })
    }
    
    @objc func mediaPhotoSelection() -> Set<AnyHashable>! {
        selectedMediaMessages
    }
    
    @objc func mediaSelectionCount() -> UInt {
        UInt(selectedMediaMessages.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, isPhotoSelectedAt index: UInt) -> Bool {
        selectedMediaMessages.contains(index)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt, selectedChanged selected: Bool) {
        if selected {
            selectedMediaMessages.insert(index)
        }
        else {
            selectedMediaMessages.remove(index)
        }
    }
    
    // MARK: - MWVideoDelegate

    func play(_ video: MediaBrowserVideo!) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }
    
    func showFile(_ fileMessageEntity: FileMessageEntity!) {
        fileMessagePreview = FileMessagePreview(for: fileMessageEntity)
        fileMessagePreview?.show(on: photoBrowser)
    }
    
    // MARK: - MWFileDelegate

    func playFileVideo(_ fileMessageEntity: FileMessageEntity!) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }
    
    func toggleControls() {
        photoBrowser?.toggleControls()
    }
    
    // MARK: - Helpers
    
    private func createPhotoBrowser() -> MWPhotoBrowser? {
        let photoBrowser = MWPhotoBrowser(delegate: self)
        
        photoBrowser?.displayDeleteButton = true
        photoBrowser?.zoomPhotosToFill = true
        
        return photoBrowser
    }
    
    private func photoAtIndex(at index: Int, thumbnail: Bool) -> MWPhotoProtocol? {
       
        guard index < mediaMessages.count else {
            return nil
        }
        
        let message: BaseMessage = mediaMessages[index]
        
        switch message {
        case let imageMessageEntity as ImageMessageEntity:
            let photo = MediaBrowserPhoto(imageMessageEntity: imageMessageEntity, thumbnail: thumbnail)
            photo?.caption = DateFormatter.shortStyleDateTime(message.remoteSentDate)
            return photo
            
        case let videoMessageEntity as VideoMessageEntity:
            let video = MediaBrowserVideo(thumbnail: videoMessageEntity.thumbnail?.uiImage)
            video?.delegate = self
            video?.sourceReference = videoMessageEntity
            video?.caption = DateFormatter.shortStyleDateTime(message.remoteSentDate)
            return video
            
        case let fileMessageEntity as FileMessageEntity:
            let file = MediaBrowserFile(fileMessageEntity: fileMessageEntity, thumbnail: thumbnail)
            file?.delegate = self
            file?.caption = DateFormatter.shortStyleDateTime(message.remoteSentDate)
            return file
            
        default:
            return nil
        }
    }
    
    private func objectIDAtIndex(at index: Int, thumbnail: Bool) -> NSManagedObjectID? {
       
        guard index < mediaMessages.count else {
            return nil
        }
        
        let message: BaseMessage = mediaMessages[index]
        return message.objectID
    }
    
    func openPhotoBrowser(currentMediaIndex: UInt?, showGrid: Bool = true, autoPlayOnAppear: Bool = false) {
        
        photoBrowser = createPhotoBrowser()
        
        guard let photoBrowser else {
            DDLogError("Could not create MWPhotoBrowser")
            return
        }
        prepareMedia()
        
        photoBrowser.autoPlayOnAppear = autoPlayOnAppear
        photoBrowser.startOnGrid = showGrid
        
        // Set opening index
        if let index = currentMediaIndex {
            photoBrowser.setCurrentPhotoIndex(index)
        }
        else {
            photoBrowser.setCurrentPhotoIndex(UInt(mediaMessages.count))
        }

        // Open photo browser
        let navCon = ModalNavigationController(rootViewController: photoBrowser)
        navCon.modalDelegate = self
        if UIDevice.current.userInterfaceIdiom == .pad {
            navCon.modalPresentationStyle = .overFullScreen
            navCon.showFullScreenOnIPad = true
        }
        parentViewController?.present(navCon, animated: true)
    }
    
    func prepareMedia() {
        var finalMessages = [BaseMessage]()
        
        let imageMessages = entityManager.entityFetcher
            .imageMessages(for: conversation) as? [ImageMessage] ?? [ImageMessage]()
        let videoMessages = entityManager.entityFetcher
            .videoMessages(for: conversation) as? [VideoMessage] ?? [VideoMessage]()
        let fileMessages = entityManager.entityFetcher
            .filesMessagesFilteredForPhotoBrowser(for: conversation) as? [FileMessageEntity] ?? [FileMessageEntity]()
        
        finalMessages.append(contentsOf: imageMessages)
        finalMessages.append(contentsOf: videoMessages)
        finalMessages.append(contentsOf: fileMessages)

        mediaMessages = finalMessages.sorted { $0.date < $1.date }
    }
    
    private func deleteMedia(for indexes: Set<UInt>, completion: @escaping () -> Void) {
        let mediaEntitiesToDelete = indexes.map { index in
            self.mediaMessages[Int(index)]
        }
        
        delegate?.willDeleteMessages(with: mediaEntitiesToDelete.map(\.objectID))
        
        entityManager.performSyncBlockAndSafe {
            for mediaEntity in mediaEntitiesToDelete {
                mediaEntity.conversation = nil
                self.entityManager.entityDestroyer.deleteObject(object: mediaEntity)
            }
            completion()
        }
    }
    
    private func handleDeletion() {
        prepareMedia()
        
        if mediaMessages.isEmpty {
            parentViewController?.dismiss(animated: true)
        }
        else {
            photoBrowser?.finishedDeleteMedia()
        }
    }
    
    // MARK: - Notifications
    
    @objc func colorThemeChanged(notification: NSNotification) {
        photoBrowser?.reloadData(true)
    }
    
    // MARK: - ModalNavigationControllerDelegate

    func didDismissModalNavigationController() {
        photoBrowser = nil
    }
}
