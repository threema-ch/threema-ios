import CocoaLumberjackSwift
import FileUtility
import Foundation
import MBProgressHUD
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import ZipArchive

final class ConversationExporter: NSObject {
    
    enum CreateZipError: Error {
        case notEnoughStorage(storageNeeded: Int64)
        case generalError
        case cancelled
    }
    
    private var password: String?
    private lazy var conversation: ConversationEntity? = entityManager.entityFetcher
        .existingObject(with: conversationObjectID) as? ConversationEntity

    private var conversationObjectID: NSManagedObjectID
    private var entityManager: EntityManager
    private var withMedia: Bool
    private var cancelled = false
    private weak var viewController: UIViewController?
    private var emailSubject = ""
    private var timeString: String?
    private var zipFileContainer: ZipFileContainer?
    
    private lazy var displayName: String = {
        var displayName = ""
        entityManager.performAndWait {
            displayName = self.conversation?.displayName ?? ""
        }
        return displayName
    }()
    
    private var log = ""
    
    private let displayNameMaxLength = 50
    
    /// Initialize a ConversationExporter with a group conversation which will be exported
    /// - Parameters:
    ///   - viewController: Will present progress indicators on this viewController
    ///   - conversationObjectID: Will export the conversation with this object ID
    ///   - entityManager: Will query the associated db
    ///   - withMedia: Whether media should be exported
    init(
        viewController: UIViewController,
        conversationObjectID: NSManagedObjectID,
        entityManager: EntityManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: AppLaunchManager.remoteSecretManager
        ).backgroundEntityManager,
        withMedia: Bool
    ) {
        self.viewController = viewController
        self.conversationObjectID = conversationObjectID
        self.entityManager = entityManager
        self.withMedia = withMedia
    }
    
    /// Check if a conversation can be exported
    /// - Parameter conversation: ConversationEntity to export
    /// - Parameter entityManager: EntityManager to load all messages
    /// - Returns: Can the passed conversation be exported?
    static func canExport(conversation: ConversationEntity, entityManager: EntityManager) -> Bool {
        let mdmSetup = MDMSetup()
        
        if let exportDisabled = mdmSetup?.disableExport(), exportDisabled {
            return false
        }
        
        let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
        return messageFetcher.count() > 0
    }
    
    /// Exports a conversation
    func exportConversation() {
        emailSubject = String.localizedStringWithFormat(
            #localize("conversation_log_subject"),
            TargetManager.appName,
            displayName
        )
        ZipFileContainer.cleanFiles()
        requestPassword()
    }
    
    func updateWithMedia(to withMedia: Bool) {
        self.withMedia = withMedia
    }
}

extension ConversationExporter {
    /// Creates the name of the zip file containing the exported chat
    /// - Returns: String starting with Threema, the display name of the chat and the current date.
    private func filenamePrefix() -> String {
        let defaultFileName = "Threema_" + DateFormatter.getNowDateString()
        
        guard let regex = try? NSRegularExpression(pattern: "[^a-z0-9-_]", options: [.caseInsensitive]) else {
            return defaultFileName
        }
        
        guard !displayName.isEmpty else {
            return defaultFileName
        }
        
        if displayName.count > displayNameMaxLength {
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
        let conversationData = Data(log.utf8)
        
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
            catch let CreateZipError.notEnoughStorage(storageNeeded: storage) {
                DDLogError(
                    "[Conversation Export] Not enough storage to export conversation. Storage needed: \(storage)."
                )
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
                DDLogError("[Conversation Export] Export failed: \(error)")
                
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
            dictionary = try FileUtility.shared.attributesOfFileSystem(forPath: NSHomeDirectory())
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
                #localize("export_progress_label"),
                po.completedUnitCount,
                po.totalUnitCount
            )
            hud.label.font = UIFont.monospacedDigitSystemFont(ofSize: hud.label.font.pointSize, weight: .semibold)
        }
    }
    
    private func addMediaBatch(with messageFetcher: MessageFetcher, from: Int, to: Int) -> Bool {
        let messages = messageFetcher.messages(at: from, count: to - from)
        guard !messages.isEmpty else {
            DDLogError("[Conversation Export] Media batch empty.")
            return false
        }
       
        let success = autoreleasepool { () -> Bool in
            for message in messages {
                var success = false
                
                entityManager.performAndWait {
                    success = self.addMessage(message: message)
                }
                
                if !success {
                    DDLogError("[Conversation Export] Add media for message \(message.id) failed.")
                    return false
                }
                
                self.incrementProgress()
            }
            return true
        }
        return success
    }
    
    private func addMessage(message: BaseMessageEntity) -> Bool {
        log.append(getMessageFrom(baseMessage: message))
        
        if withMedia, let blobDataMessage = message as? BlobData, let blobData = blobDataMessage.blobData {
            let storageNecessary = Int64(blobData.count)
            if !enoughFreeStorage(toStore: storageNecessary) {
                DDLogError("[Conversation Export] Not enough space to store media of message.")
                return false
            }
            
            if !(zipFileContainer!.addMediaData(mediaData: blobDataMessage)) {
                // Writing the file has failed
                DDLogError("[Conversation Export] Writing of media data failed.")
                return false
            }
        }
        // We refresh to free memory
        entityManager.refresh(message, mergeChanges: true)
        return true
    }
    
    private func exportChatToZipFile() -> Bool {
        guard let conversation else {
            return false
        }
        
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
                DDLogError("[Conversation Export] Media export unsuccessful.")
                return false
            }
        }
        
        return true
    }
    
    /// Returns the storage necessary for exporting the initialized chat or conversation
    /// - Returns: A tuple (a,b) where b indicates the storage needed for the chat export if a is true. a is false if
    /// checking the necessary storage has failed.
    private func checkStorageNecessary() -> (Bool, Int64) {
        guard let conversation else {
            return (false, -1)
        }
        
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
                if let blobMessage = message as? BlobData, let blobSize = blobMessage.blobData?.count {
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
    
    private func getMessageFrom(baseMessage: BaseMessageEntity) -> String {
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
        
        let date = DateFormatter.longStyleDateTime(baseMessage.remoteSentDate ?? baseMessage.date)
        log.append(date)
        log.append(": ")
        
        if let textMessage = baseMessage as? TextMessageEntity, let quoteID = textMessage.quotedMessageID,
           let quoteMessage = entityManager.entityFetcher.message(
               with: quoteID,
               in: baseMessage.conversation
           ) as? PreviewableMessage {
            log.append("[")
            if let displayName = quoteMessage.sender?.displayName {
                log.append("\(displayName): ")
            }
            else if !quoteMessage.isOwn.boolValue, let contact = quoteMessage.conversation.contact {
                log.append("\(contact.displayName): ")
            }
            else {
                log.append("\(#localize("me")): ")
            }
                
            log.append("\"\(quoteMessage.previewText)\"] ")
        }
        
        if let additionalExportInfo = additionalExportInfo(for: baseMessage) {
            log.append(additionalExportInfo)
        }
        
        log.append("\r\n")
        
        return log
    }

    private func additionalExportInfo(for baseMessageEntity: BaseMessageEntity) -> String? {
        if let entity = baseMessageEntity as? AudioMessageEntity {
            var seconds = entity.duration.intValue
            let minutes: Int = seconds / 60
            seconds = seconds - minutes * 60
            return "\(#localize("file_message_voice")) (\(minutes):\(seconds),\(entity.blobExportFilename ?? "nil"))"
        }
        else if let entity = baseMessageEntity as? BallotMessageEntity {
            guard let ballot = entity.ballot else {
                return nil
            }
            var info = "\(#localize("ballot")): \(ballot.title ?? "")"

            for choice in ballot.choicesSortedByOrder {
                info += "- \(choice.name ?? "")\n"
            }
            return info
        }
        else if let entity = baseMessageEntity as? FileMessageEntity {
            var filename = entity.blobExportFilename
            if entity.blobData == nil {
                filename += " \(#localize("fileNotDownloaded"))"
            }
            
            var info = "\(#localize("file")) (\(filename))"

            if let caption = entity.caption {
                let cap = ", \(#localize("caption")): \(caption)"
                info += cap
            }

            return info
        }
        else if let entity = baseMessageEntity as? ImageMessageEntity {
            var info = "\(#localize("image")) (\(entity.blobExportFilename ?? ""))"

            if let caption = entity.image?.caption() {
                info = info + ", \(#localize("caption")): \(caption)"
            }
            return info
        }
        else if let entity = baseMessageEntity as? LocationMessageEntity {
            guard let latitude = entity.latitude as? Double, let longitude = entity.longitude as? Double else {
                return #localize("location")
            }
            return "\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))"
        }
        else if let entity = baseMessageEntity as? SystemMessageEntity {
            return switch entity.systemMessageType {
            case let .systemMessage(type: type):
                type.localizedMessage()
            case let .callMessage(type: type):
                type.localizedMessage
            case let .workConsumerInfo(type: type):
                type.localizedMessage
            }
        }
        else if let entity = baseMessageEntity as? TextMessageEntity {
            return entity.text
        }
        else if let entity = baseMessageEntity as? VideoMessageEntity {
            var seconds = entity.duration.intValue
            let minutes: Int = seconds / 60
            seconds = seconds - minutes * 60
            return "\(#localize("video")) (\(minutes):\(seconds),\(entity.blobExportFilename ?? "nil"))"
        }
        else {
            return nil
        }
    }
}

// MARK: - UI Elements

extension ConversationExporter {
    
    /// Shows an alert with an error code
    /// - Parameter errorCode: the error code shown in the alert
    func showGeneralAlert(errorCode: Int) {
        let title = #localize("chat_export_failed_title")
        let message = String.localizedStringWithFormat(
            #localize("chat_export_failed_message"),
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
        
        let title = #localize("not_enough_storage_title")
        let message = String.localizedStringWithFormat(
            #localize("amount_of_free_storage_needed"),
            needed,
            free
        )
            
        UIAlertTemplate.showAlert(owner: viewController!, title: title, message: message, actionOk: nil)
    }
    
    /// Presents the password request UI
    func requestPassword() {
        let passwordCreationView = PasswordCreationView(
            coordinator: nil,
            title: #localize("export_chat"),
            footer: #localize("password_description_export"),
            passwordCreateButton: #localize("export_chat_button"),
            onPasswordCreated: { [weak self] password in
                guard let self else {
                    return
                }
                
                self.password = password
                viewController?.presentedViewController?.dismiss(animated: true)
                createExport()
            },
            onDismiss: { [weak self] in
                guard let self else {
                    return
                }
                
                viewController?.presentedViewController?.dismiss(animated: true)
            }
        )
        
        let navController = UINavigationController(
            rootViewController: UIHostingController(
                rootView: passwordCreationView
            )
        )
        
        viewController?.present(navController, animated: true)
    }
    
    func createActivityViewController(zipURL: URL) -> UIActivityViewController? {
        let item = UIActivityHelperFactory.makeItemSource(type: .zipFile(url: zipURL, subject: emailSubject))
        let activityViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        if let topViewController = AppDelegate.shared().currentTopViewController(),
           topViewController.traitCollection.horizontalSizeClass == .regular {
            let rect = viewController!.view.convert(viewController!.view.frame, to: viewController!.view)
            activityViewController.popoverPresentationController?.sourceRect = rect
            activityViewController.popoverPresentationController?.sourceView = viewController!.view
        }
        
        let defaults = AppGroup.userDefaults()
        defaults?.set(ThreemaUtilityObjC.systemUptime(), forKey: "UIActivityViewControllerOpenTime")
        defaults?.synchronize()
        
        activityViewController.completionWithItemsHandler = { _, _, _, _ in
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
        MBProgressHUD.forView(viewController!.view)?.label.text = #localize("cancelling_export")
    }
    
    func initProgress(totalWork: Int64) {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.viewController!.view, animated: true)
            let hud = MBProgressHUD.showAdded(to: self.viewController!.view, animated: true)
            
            if hud.progressObject == nil {
                hud.mode = .annularDeterminate
                
                let progress = Progress(totalUnitCount: Int64(totalWork))
                hud.progressObject = progress
                
                hud.button.setTitle(#localize("cancel"), for: .normal)
                hud.button.addTarget(self, action: #selector(self.progressHUDCancelPressed), for: .touchUpInside)
                
                hud.label.text = String.localizedStringWithFormat(
                    #localize("export_progress_label"),
                    0,
                    totalWork
                )
            }
        }
    }
}
