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

import Foundation
import ZipArchive
import MBProgressHUD

class ConversationExporter: NSObject, PasswordCallback {
    
    enum CreateZipError: Error {
        case notEnoughStorage(storageNeeded: Int64)
        case generalError
        case cancelled
    }
    
    private var password: String?
    private var conversation: Conversation
    private var entityManager: EntityManager
    private var contact: Contact?
    private var withMedia: Bool
    private var cancelled: Bool = false
    private var viewController: UIViewController?
    private var emailSubject = ""
    private var timeString: String?
    private var zipFileContainer: ZipFileContainer?
    
    private var log: String = ""
    
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
        self.contact = contact
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
        self.contact = contact
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
    @objc init(viewController: UIViewController, conversation: Conversation, entityManager: EntityManager, withMedia: Bool) {
        self.viewController = viewController
        self.conversation = conversation
        self.entityManager = entityManager
        self.withMedia = withMedia
    }
    
    /// Gets the subject used in the email when exporting
    /// - Returns: Name or Identity of the chat
    private func getSubjectName() -> String {
        var subjectName: String
        
        if self.contact!.firstName != nil {
            subjectName = self.contact!.firstName
            if self.contact!.lastName != nil {
                subjectName = " " + self.contact!.lastName
            }
            if self.contact!.identity != nil {
                subjectName = " (" + self.contact!.identity + ")"
            }
        } else {
            subjectName = self.contact!.identity
        }
        return subjectName
    }
    
    /// Exports a 1-to-1 conversation. Can not be used with group conversations!
    func exportConversation() {
        let subjectName = getSubjectName()
        self.emailSubject = String(format: NSLocalizedString("conversation_log_subject", comment: ""), "\(subjectName)")
        ZipFileContainer.cleanFiles()
        self.requestPassword()
    }
    
    /// Exports a group conversation.
    @objc func exportGroupConversation() {
        self.emailSubject = String(format: NSLocalizedString("conversation_log_group_subject", comment: ""))
        ZipFileContainer.cleanFiles()
        self.requestPassword()
    }
}

extension ConversationExporter {
    /// Creates the name of the zip file containing the exported chat
    /// - Returns: String starting with Threema, the display name of the chat and the current date.
    private func filenamePrefix() -> String {
        guard let regex = try? NSRegularExpression(pattern: "[^a-z0-9-_]", options: [.caseInsensitive]) else {
            return "Threema_" + DateFormatter.getNowDateString()
        }
        
        var displayName: String! = self.conversation.displayName
        if displayName!.count > displayNameMaxLength {
            displayName = String(displayName.prefix(displayNameMaxLength-1))
        }
        displayName = regex.stringByReplacingMatches(in: displayName,
                                                     options: NSRegularExpression.MatchingOptions(rawValue: 0),
                                                     range: NSRange(location: 0, length: displayName.count),
                                                     withTemplate: "_")
        
        return "Threema_" + displayName + "_" + DateFormatter.getNowDateString()
    }
    
    /// Returns the filename with extension of the zip file
    /// - Returns: Filename with extension of the zip file
    private func zipFileName() -> String {
        return self.filenamePrefix()
    }
    
    private func conversationTextFilename() -> String {
        return self.filenamePrefix() + ".txt"
    }
    
    /// Deletes all files created for this specific export
    private func removeZipFileContainerList() {
        self.zipFileContainer?.deleteFile()
    }
    
    /// Creates a zip file with the contact or conversation initialized
    /// - Throws: CreateZipError if there is not enough storage
    /// - Returns: An URL to the zip file if the export was successful and nil otherwise
    private func createZipFiles() throws -> URL {
        if password == nil {
            throw CreateZipError.generalError
        }
        
        self.zipFileContainer = ZipFileContainer(password: self.password!, name: "Conversation.zip")
        
        let success = self.exportChatToZipFile()
        
        guard let conversationData = self.log.data(using: String.Encoding.utf8) else {
            throw CreateZipError.generalError
        }
        
        if !self.enoughFreeStorage(toStore: Int64(conversationData.count)) {
            DispatchQueue.main.async {
                self.removeCurrentHUD()
                self.showStorageAlert(Int64(conversationData.count), freeStorage: Int64(self.getFreeStorage()))
            }
            self.removeZipFileContainerList()
        }
        
        if self.cancelled {
            self.removeZipFileContainerList()
            throw CreateZipError.cancelled
        }
        
        if !(self.zipFileContainer!.addData(data: conversationData, filename: self.conversationTextFilename())) {
            throw CreateZipError.generalError
        }
        
        if !success && !self.cancelled {
            self.removeZipFileContainerList()
            DispatchQueue.main.async {
                self.removeCurrentHUD()
                MBProgressHUD.showAdded(to: (self.viewController!.view)!, animated: true)
            }
            let (storageCheckSuccess, totalStorage) = self.checkStorageNecessary()
            if storageCheckSuccess {
                throw CreateZipError.notEnoughStorage(storageNeeded: totalStorage)
            }
            throw CreateZipError.generalError
        }
        
        if self.cancelled {
            self.removeZipFileContainerList()
            throw CreateZipError.cancelled
        }
        
        guard let url = self.zipFileContainer!.getUrlWithFileName(fileName: self.zipFileName()) else {
            throw CreateZipError.generalError
        }
        
        return url
    }
    
    /// Creates an export of the initialized conversation or contact. Will present an error if the chat export has
    /// failed or a share sheet if the export was successful.
    private func createExport() {
        DispatchQueue.global(qos: .default).async {
            var zipUrl: URL?
            do {
                zipUrl = try self.createZipFiles()
            } catch CreateZipError.notEnoughStorage(storageNeeded: _) {
                let (success, totalStorageNeeded) = self.checkStorageNecessary()
                if success {
                    DispatchQueue.main.async {
                        self.removeCurrentHUD()
                        self.showStorageAlert(totalStorageNeeded, freeStorage: self.getFreeStorage())
                    }
                    return
                }
            } catch {
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
                
                let activityViewController = self.createActivityViewController(zipUrl: zipUrl!)
                
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
        } catch {
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
        DispatchQueue.main.async(execute: {
            guard let hud = MBProgressHUD.forView(self.viewController!.view) else {
                return
            }
            
            guard let po = hud.progressObject else {
                return
            }
            po.completedUnitCount += 1
            hud.label.text = String(format: NSLocalizedString("export_progress_label", comment: ""), po.completedUnitCount, po.totalUnitCount)
            if #available(iOS 13.0, *) {
                hud.label.font = UIFont.monospacedSystemFont(ofSize: hud.label.font.pointSize, weight: .semibold)
            }
        })
    }
    
    private func addMediaBatch(with messageFetcher: MessageFetcher, from: Int, to: Int) -> Bool {
        guard let messages = messageFetcher.messages(atOffset: from, count: to - from) else {
            return false
        }
        let success = autoreleasepool { () -> Bool in
            for j in 0...(to - from) - 1 {
                if messages[j] is BaseMessage {
                    guard let message = messages[j] as? BaseMessage else {
                        return false
                    }
                    if !self.addMessage(message: message) {
                        return false
                    }
                }
                self.incrementProgress()
            }
            return true
        }
        return success
    }
    
    private func addMessage(message : BaseMessage) -> Bool {
        log.append(ConversationExporter.getMessageFrom(baseMessage: message))
        
        if self.withMedia, message is BlobData, ((message as! BlobData).blobGet()) != nil {
            let storageNecessary = Int64((message as! BlobData).blobGet()!.count)
            if !enoughFreeStorage(toStore: storageNecessary) {
                return false
            }
            
            if !(self.zipFileContainer!.addMediaData(mediaData:message as! BlobData)) {
                // Writing the file has failed
                return false
            }
        }
        self.entityManager.refreshObject(message, mergeChanges: true)
        return true
    }
    
    private func exportChatToZipFile() -> Bool {
        guard let messageFetcher = MessageFetcher.init(for: self.conversation, with: self.entityManager.entityFetcher) else {
            return false
        }
        messageFetcher.orderAscending = true
        
        let countTotal = messageFetcher.count()
        
        if self.cancelled {
            return false
        }
        
        self.initProgress(totalWork: Int64(countTotal))
        
        // Stride increment should be equal to the minimum possible memory capacity / maximum possible file size
        let strideInc = 15
        
        for i in stride(from: 0, to: countTotal, by: strideInc) {
            if self.cancelled {
                return false
            }
            
            let success = addMediaBatch(with: messageFetcher,
                                            from: i,
                                            to: min(countTotal, i + strideInc))
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
        guard let messageFetcher = MessageFetcher.init(for: self.conversation, with: self.entityManager.entityFetcher) else {
            return (false, -1)
        }
        messageFetcher.orderAscending = false
        
        let countTotal = messageFetcher.count()
        var totalStorageNecessary: Int64 = 0
        
        if self.cancelled {
            return (false, -1)
        }
        
        for i in 0...countTotal {
            guard let messages = messageFetcher.messages(atOffset: i, count: i + 1) else {
                return (false, -1)
            }
            let success = autoreleasepool { () -> Bool in
                if messages.first != nil, messages.first! is BlobData, ((messages.first! as! BlobData).blobGet()) != nil {
                    totalStorageNecessary += Int64((messages.first! as! BlobData).blobGet()!.count)
                }
                
                self.entityManager.refreshObject(messages.first! as? NSManagedObject, mergeChanges: true)
                return true
            }
            if !success {
                return (false, -1)
            }
        }
        return (true, totalStorageNecessary)
    }
    
    private static func getMessageFrom(baseMessage: BaseMessage) -> String {
        var log = ""
        if baseMessage.isOwn.boolValue {
            log.append(">>> ")
        } else {
            log.append("<<< ")
            if baseMessage.sender != nil {
                log.append("(")
                log.append(baseMessage.sender.displayName)
                log.append(") ")
            }
        }
        
        let date = DateFormatter.longStyleDateTime(baseMessage.remoteSentDate)
        log.append(date)
        log.append(": ")
        
        if baseMessage.logText() != nil {
            log.append(baseMessage.logText())
        }
        
        log.append("\r\n")
        
        return log
    }
}

// MARK: - UI Elements
extension ConversationExporter {
    func passwordResult(_ password: String!, from _ : UIViewController!) {
        self.password = password
        
        MBProgressHUD.showAdded(to: (self.viewController!.view)!, animated: true)
        
        self.viewController!.dismiss(animated: true, completion: ({
            self.createExport()
        }))
    }
    
    /// Shows an alert with an error code
    /// - Parameter errorCode: the error code shown in the alert
    func showGeneralAlert(errorCode: Int) {
        let title = String(format: NSLocalizedString("chat_export_failed_title", comment: ""))
        let message = String(format: NSLocalizedString("chat_export_failed_message", comment: ""), errorCode)
        
        UIAlertTemplate.showAlert(owner: self.viewController!, title: title, message: message, actionOk: nil)
    }
    
    /// Shows an alert indicating that there is not enough storage
    /// - Parameters:
    ///   - chatSize: The size needed for the export
    ///   - freeStorage: The current free size
    func showStorageAlert(_ chatSize: Int64, freeStorage: Int64) {
        let needed = ByteCountFormatter.string(fromByteCount: chatSize, countStyle: .file)
        let free = ByteCountFormatter.string(fromByteCount: freeStorage, countStyle: .file)
        
        let title = NSLocalizedString("not_enough_storage_title", comment: "")
        let message = String(format: NSLocalizedString("amount_of_free_storage_needed", comment: ""), needed, free)
        
        UIAlertTemplate.showAlert(owner: self.viewController!, title: title, message: message, actionOk: nil)
    }
    
    /// Presents the password request UI
    func requestPassword() {
        let passwordTrigger = CreatePasswordTrigger(on: self.viewController)
        passwordTrigger?.passwordAdditionalText = String(format: NSLocalizedString("password_description_export", comment: ""))
        passwordTrigger?.passwordCallback = self
        
        passwordTrigger?.presentPasswordUI()
    }
    
    func createActivityViewController(zipUrl: URL) -> UIActivityViewController? {
        let zipActivity = ZipFileActivityItemProvider(url: zipUrl, subject: self.emailSubject)
        
        let activityViewController = ActivityUtil.activityViewController(withActivityItems: [zipActivity], applicationActivities: [])
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            let rect = self.viewController!.view.convert(self.viewController!.view.frame, from: self.viewController!.view.superview)
            activityViewController?.popoverPresentationController?.sourceRect = rect
            activityViewController?.popoverPresentationController?.sourceView = self.viewController!.view
        }
        
        let defaults = AppGroup.userDefaults()
        defaults?.set(Utils.systemUptime(), forKey: "UIActivityViewControllerOpenTime")
        defaults?.synchronize()
        
        activityViewController!.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
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
        MBProgressHUD.hide(for: self.viewController!.view, animated: true)
    }
    
    func cancelProgressHud() {
        self.removeCurrentHUD()
        MBProgressHUD.showAdded(to: self.viewController!.view, animated: true)
        MBProgressHUD(view: self.viewController!.view).label.text = NSLocalizedString("cancelling_export", comment: "")
    }
    
    func initProgress(totalWork: Int64) {
        DispatchQueue.main.async(execute: {
            MBProgressHUD.hide(for: self.viewController!.view, animated: true)
            let hud = MBProgressHUD.showAdded(to: self.viewController!.view, animated: true)
            
            if hud.progressObject == nil {
                hud.mode = .annularDeterminate
                
                let progress = Progress(totalUnitCount: Int64(totalWork))
                hud.progressObject = progress
                
                hud.button.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
                hud.button.addTarget(self, action: #selector(self.progressHUDCancelPressed), for: .touchUpInside)
                
                hud.label.text = String(format: NSLocalizedString("export_progress_label", comment: ""), 0, totalWork)
            }
        })
    }
}
