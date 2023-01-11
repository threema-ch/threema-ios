//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import MBProgressHUD
import ThreemaFramework
import ZipArchive

class ConversationExporter: NSObject, PasswordCallback {
    
    enum CreateZipError: Error {
        case notEnoughStorage(storageNeeded: Int64)
        case generalError
        case cancelled
    }
    
    private var password: String?
    private var conversation: Conversation
    private var entityManager: EntityManager
    private var withMedia: Bool
    private var cancelled = false
    private var viewController: UIViewController?
    private var emailSubject = ""
    private var timeString: String?
    private var zipFileContainer: ZipFileContainer?
    
    private var log = ""
    
    private let displayNameMaxLength = 50
    
    /// Initialize a ConversationExporter without a viewController for testing
    /// - Parameters:
    ///   - password: The password for encrypting the zip
    ///   - entityManager: the entityManager used for querying the db
    ///   - contact: The contact for which the chat is exported
    ///   - withMedia: Whether media should be included or not
    init(password: String, entityManager: EntityManager, contact: Contact?, withMedia: Bool) {
        self.password = password
        self.conversation = entityManager.entityFetcher.conversation(for: contact)
        self.entityManager = entityManager
        self.withMedia = withMedia
    }
    
    /// Initialize a ConversationExporter with a contact whose 1-to-1 conversation will be exported
    /// - Parameters:
    ///   - viewController: Will present progress indicators on this viewController
    ///   - contact: Will export the conversation for this contact
    ///   - entityManager: Will query the associated db
    ///   - withMedia: Whether media should be exported
    @objc init(viewController: UIViewController, contact: Contact, entityManager: EntityManager, withMedia: Bool) {
        self.viewController = viewController
        self.conversation = entityManager.entityFetcher.conversation(for: contact)
        self.entityManager = entityManager
        self.withMedia = withMedia
    }
    
    /// Initialize a ConversationExporter with a group conversation which will be exported
    /// - Parameters:
    ///   - viewController: Will present progress indicators on this viewController
    ///   - conversation: Will export this conversation.
    ///   - entityManager: Will query the associated db
    ///   - withMedia: Whether media should be exported
    @objc init(
        viewController: UIViewController,
        conversation: Conversation,
        entityManager: EntityManager,
        withMedia: Bool
    ) {
        self.viewController = viewController
        self.conversation = conversation
        self.entityManager = entityManager
        self.withMedia = withMedia
    }
    
    /// Check if a conversation can be exported
    /// - Parameter conversation: Conversation to export
    /// - Parameter entityManager: EntityManager to load all messages
    /// - Returns: Can the passed conversation be exported?
    static func canExport(conversation: Conversation, entityManager: EntityManager) -> Bool {
        let mdmSetup = MDMSetup(setup: false)
        
        if let exportDisabled = mdmSetup?.disableExport(), exportDisabled {
            return false
        }
        
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        return messageFetcher.count() > 0
    }
    
    /// Exports a conversation
    @objc func exportConversation() {
        emailSubject = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "conversation_log_subject"),
            conversation.displayName ?? ""
        )
        ZipFileContainer.cleanFiles()
        requestPassword()
    }
}

extension ConversationExporter {
    /// Creates the name of the zip file containing the exported chat
    /// - Returns: String starting with Threema, the display name of the chat and the current date.
    private func filenamePrefix() -> String {
        guard let regex = try? NSRegularExpression(pattern: "[^a-z0-9-_]", options: [.caseInsensitive]) else {
            return "Threema_" + DateFormatter.getNowDateString()
        }
        
        var displayName: String! = conversation.displayName
        if displayName!.count > displayNameMaxLength {
            displayName = String(displayName.prefix(displayNameMaxLength - 1))
        }
        displayName = regex.stringByReplacingMatches(
            in: displayName,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: NSRange(location: 0, length: displayName.count),
            withTemplate: "_"
        )
        
        return "Threema_" + displayName + "_" + DateFormatter.getNowDateString()
    }
    
    /// Returns the filename with extension of the zip file
    /// - Returns: Filename with extension of the zip file
    private func zipFileName() -> String {
        filenamePrefix()
    }
    
    private func conversationTextFilename() -> String {
        "messages.txt"
    }
    
    /// Deletes all files created for this specific export
    private func removeZipFileContainerList() {
        zipFileContainer?.deleteFile()
    }
    
    /// Creates a zip file with the contact or conversation initialized
    /// - Throws: CreateZipError if there is not enough storage
    /// - Returns: An URL to the zip file if the export was successful and nil otherwise
    private func createZipFiles() throws -> URL {
        if password == nil {
            throw CreateZipError.generalError
        }
        
        zipFileContainer = ZipFileContainer(password: password!, name: "Conversation.zip")
        
        let success = exportChatToZipFile()
        
        guard let conversationData = log.data(using: String.Encoding.utf8) else {
            throw CreateZipError.generalError
        }
        
        if !enoughFreeStorage(toStore: Int64(conversationData.count)) {
            DispatchQueue.main.async {
                self.removeCurrentHUD()
                self.showStorageAlert(Int64(conversationData.count), freeStorage: Int64(self.getFreeStorage()))
            }
            removeZipFileContainerList()
        }
        
        if cancelled {
            removeZipFileContainerList()
            throw CreateZipError.cancelled
        }
        
        if !(zipFileContainer!.addData(data: conversationData, filename: conversationTextFilename())) {
            throw CreateZipError.generalError
        }

        if !success, !cancelled {
            removeZipFileContainerList()
            DispatchQueue.main.async {
                self.removeCurrentHUD()
                MBProgressHUD.showAdded(to: (self.viewController!.view)!, animated: true)
            }
            let (storageCheckSuccess, totalStorage) = checkStorageNecessary()
            if storageCheckSuccess {
                throw CreateZipError.notEnoughStorage(storageNeeded: totalStorage)
            }
            throw CreateZipError.generalError
        }
        
        if cancelled {
            removeZipFileContainerList()
            throw CreateZipError.cancelled
        }
        
        guard let url = zipFileContainer!.getURLWithFileName(fileName: zipFileName()) else {
            throw CreateZipError.generalError
        }
        
        return url
    }
    
    /// Creates an export of the initialized conversation or contact. Will present an error if the chat export has
    /// failed or a share sheet if the export was successful.
    private func createExport() {
        viewController?.isModalInPresentation = true
        DispatchQueue.global(qos: .default).async {
            var zipURL: URL?
            do {
                zipURL = try self.createZipFiles()
            }
            catch CreateZipError.notEnoughStorage(storageNeeded: _) {
                let (success, totalStorageNeeded) = self.checkStorageNecessary()
                if success {
                    DispatchQueue.main.async {
                        self.removeCurrentHUD()
                        self.showStorageAlert(totalStorageNeeded, freeStorage: self.getFreeStorage())
                    }
                    return
                }
            }
            catch {
                if !self.cancelled {
                    DispatchQueue.main.async {
                        self.showGeneralAlert(errorCode: 0)
                    }
                }
                DispatchQueue.main.async {
                    self.removeCurrentHUD()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.removeCurrentHUD()
                
                if self.cancelled {
                    return
                }
                
                let activityViewController = self.createActivityViewController(zipURL: zipURL!)
                
                self.viewController!.present(activityViewController!, animated: true)
                self.timeString = nil
            }
        }
    }
    
    /// Returns the amount of free storage in bytes
    /// - Returns: The amount of free storage in bytes or -1 if the amount of storage can not be determined
    private func getFreeStorage() -> Int64 {
        var dictionary: [FileAttributeKey: Any]?
        do {
            dictionary = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        }
        catch {
            return -1
        }
        if dictionary != nil {
            let freeSpaceSize = (dictionary?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            
            return freeSpaceSize
        }
        return -1
    }
    
    /// Returns true if there is enough free storage to store noBytes
    private func enoughFreeStorage(toStore noBytes: Int64) -> Bool {
        if getFreeStorage() > noBytes {
            return true
        }
        return false
    }
    
    private func incrementProgress() {
        DispatchQueue.main.async {
            guard let hud = MBProgressHUD.forView(self.viewController!.view) else {
                return
            }
            
            guard let po = hud.progressObject else {
                return
            }
            
            po.completedUnitCount += 1
            hud.label.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "export_progress_label"),
                po.completedUnitCount,
                po.totalUnitCount
            )
            hud.label.font = UIFont.monospacedDigitSystemFont(ofSize: hud.label.font.pointSize, weight: .semibold)
        }
    }
    
    private func addMediaBatch(with messageFetcher: MessageFetcher, from: Int, to: Int) -> Bool {
        let messages = messageFetcher.messages(at: from, count: to - from)
        guard !messages.isEmpty else {
            return false
        }
       
        let success = autoreleasepool { () -> Bool in
            for message in messages {
                if !self.addMessage(message: message) {
                    return false
                }
                self.incrementProgress()
            }
            return true
        }
        return success
    }
    
    private func addMessage(message: BaseMessage) -> Bool {
        log.append(getMessageFrom(baseMessage: message))
        if withMedia, let blobDataMessage = message as? BlobData, let blobData = blobDataMessage.blobGet() {
            let storageNecessary = Int64(blobData.count)
            if !enoughFreeStorage(toStore: storageNecessary) {
                return false
            }
            
            if !(zipFileContainer!.addMediaData(mediaData: blobDataMessage)) {
                // Writing the file has failed
                return false
            }
        }
        entityManager.refresh(message, mergeChanges: true)
        return true
    }
    
    private func exportChatToZipFile() -> Bool {
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        messageFetcher.orderAscending = true
        
        let countTotal = messageFetcher.count()
        
        if cancelled {
            return false
        }
       
        initProgress(totalWork: Int64(countTotal))
        
        // Stride increment should be equal to the minimum possible memory capacity / maximum possible file size
        let strideInc = 15
        
        for i in stride(from: 0, to: countTotal, by: strideInc) {
            if cancelled {
                return false
            }
            
            let success = addMediaBatch(
                with: messageFetcher,
                from: i,
                to: min(countTotal, i + strideInc)
            )
            if !success {
                return false
            }
        }
        
        return true
    }
    
    /// Returns the storage necessary for exporting the initialized chat or conversation
    /// - Returns: A tuple (a,b) where b indicates the storage needed for the chat export if a is true. a is false if
    /// checking the necessary storage has failed.
    private func checkStorageNecessary() -> (Bool, Int64) {
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        messageFetcher.orderAscending = false
        
        let countTotal = messageFetcher.count()
        var totalStorageNecessary: Int64 = 0
        
        if cancelled {
            return (false, -1)
        }
        
        for i in 0...countTotal {
            let messages = messageFetcher.messages(at: i, count: i + 1)
            guard let message = messages.first else {
                return (false, -1)
            }
            let success = autoreleasepool { () -> Bool in
                if let blobMessage = message as? BlobData, let blobSize = blobMessage.blobGet()?.count {
                    totalStorageNecessary += Int64(blobSize)
                }
                
                self.entityManager.refresh(message as NSManagedObject, mergeChanges: true)
                return true
            }
            if !success {
                return (false, -1)
            }
        }
        return (true, totalStorageNecessary)
    }
    
    private func getMessageFrom(baseMessage: BaseMessage) -> String {
        var log = ""
        if baseMessage.isOwnMessage {
            log.append(">>> ")
        }
        else {
            log.append("<<< ")
            if let sender = baseMessage.sender {
                log.append("(")
                log.append(sender.displayName)
                log.append(") ")
            }
        }
        
        let date = DateFormatter.longStyleDateTime(baseMessage.remoteSentDate)
        log.append(date)
        log.append(": ")
        
        if let textMessage = baseMessage as? TextMessage, let quoteID = textMessage.quotedMessageID,
           let quoteMessage = entityManager.entityFetcher.message(
               with: quoteID,
               conversation: baseMessage.conversation
           ) {
            log.append("[")
            if let displayName = quoteMessage.sender?.displayName {
                log.append("\(displayName): ")
            }
            else if let isOwn = quoteMessage.isOwn, !isOwn.boolValue, let contact = quoteMessage.conversation.contact {
                log.append("\(contact.displayName): ")
            }
            else {
                log.append("\(BundleUtil.localizedString(forKey: "me")): ")
            }
            if let previewText = quoteMessage.previewText() {
                log.append("\"\(previewText)\"] ")
            }
            else {
                log.append("] ")
            }
        }
        
        if let logText = baseMessage.logText() {
            log.append(logText)
        }
        
        log.append("\r\n")
        
        return log
    }
}

// MARK: - UI Elements

extension ConversationExporter {
    func passwordResult(_ password: String!, from _: UIViewController!) {
        self.password = password
        MBProgressHUD.showAdded(to: (viewController!.view)!, animated: true)
        
        viewController!.dismiss(animated: true, completion: ({
            self.createExport()
        }))
    }
    
    /// Shows an alert with an error code
    /// - Parameter errorCode: the error code shown in the alert
    func showGeneralAlert(errorCode: Int) {
        let title = BundleUtil.localizedString(forKey: "chat_export_failed_title")
        let message = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "chat_export_failed_message"),
            errorCode
        )
        
        UIAlertTemplate.showAlert(owner: viewController!, title: title, message: message, actionOk: nil)
    }
    
    /// Shows an alert indicating that there is not enough storage
    /// - Parameters:
    ///   - chatSize: The size needed for the export
    ///   - freeStorage: The current free size
    func showStorageAlert(_ chatSize: Int64, freeStorage: Int64) {
        let needed = ByteCountFormatter.string(fromByteCount: chatSize, countStyle: .file)
        let free = ByteCountFormatter.string(fromByteCount: freeStorage, countStyle: .file)
        
        let title = BundleUtil.localizedString(forKey: "not_enough_storage_title")
        let message = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "amount_of_free_storage_needed"),
            needed,
            free
        )
        
        UIAlertTemplate.showAlert(owner: viewController!, title: title, message: message, actionOk: nil)
    }
    
    /// Presents the password request UI
    func requestPassword() {
        let passwordTrigger = CreatePasswordTrigger(on: viewController)
        passwordTrigger?.passwordAdditionalText = BundleUtil.localizedString(forKey: "password_description_export")
        passwordTrigger?.passwordCallback = self
        
        passwordTrigger?.presentPasswordUI()
    }
    
    func createActivityViewController(zipURL: URL) -> UIActivityViewController? {
        let zipActivity = ZipFileActivityItemProvider(url: zipURL, subject: emailSubject)
        
        let activityViewController = ActivityUtil.activityViewController(
            withActivityItems: [zipActivity],
            applicationActivities: []
        )
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            let rect = viewController!.view.convert(viewController!.view.frame, to: viewController!.view)
            activityViewController?.popoverPresentationController?.sourceRect = rect
            activityViewController?.popoverPresentationController?.sourceView = viewController!.view
        }
        
        let defaults = AppGroup.userDefaults()
        defaults?.set(ThreemaUtilityObjC.systemUptime(), forKey: "UIActivityViewControllerOpenTime")
        defaults?.synchronize()
        
        activityViewController!.completionWithItemsHandler = { _, _, _, _ in
            let defaults = AppGroup.userDefaults()
            defaults?.removeObject(forKey: "UIActivityViewControllerOpenTime")
            ZipFileContainer.cleanFiles()
        }
        return activityViewController
    }
    
    @objc func progressHUDCancelPressed() {
        DispatchQueue.main.async {
            self.cancelled = true
            self.cancelProgressHud()
        }
    }
    
    func removeCurrentHUD() {
        viewController?.isModalInPresentation = false
        MBProgressHUD.hide(for: viewController!.view, animated: true)
    }
    
    func cancelProgressHud() {
        removeCurrentHUD()
        MBProgressHUD.showAdded(to: viewController!.view, animated: true)
        MBProgressHUD.forView(viewController!.view)?.label.text = BundleUtil
            .localizedString(forKey: "cancelling_export")
    }
    
    func initProgress(totalWork: Int64) {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.viewController!.view, animated: true)
            let hud = MBProgressHUD.showAdded(to: self.viewController!.view, animated: true)
            
            if hud.progressObject == nil {
                hud.mode = .annularDeterminate
                
                let progress = Progress(totalUnitCount: Int64(totalWork))
                hud.progressObject = progress
                
                hud.button.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
                hud.button.addTarget(self, action: #selector(self.progressHUDCancelPressed), for: .touchUpInside)
                
                hud.label.text = String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "export_progress_label"),
                    0,
                    totalWork
                )
            }
        }
    }
}
