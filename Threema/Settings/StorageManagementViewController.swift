//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
import UIKit

class StorageManagementViewController: ThemedTableViewController {
    
    @IBOutlet var storageTotal: UILabel!
    @IBOutlet var storageTotalValue: UILabel!
    @IBOutlet var storageTotalInUse: UILabel!
    @IBOutlet var storageTotalInUseValue: UILabel!
    @IBOutlet var storageTotalFree: UILabel!
    @IBOutlet var storageTotalFreeValue: UILabel!
    @IBOutlet var storageThreema: UILabel!
    @IBOutlet var storageThreemaValue: UILabel!
    @IBOutlet var storageThreemaActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var mediaDeleteCell: UITableViewCell!
    @IBOutlet var mediaDeleteLabel: UILabel!
    @IBOutlet var mediaDeleteDetailLabel: UILabel!
    @IBOutlet var mediaDeleteButtonLabel: UILabel!
    @IBOutlet var mediaDeleteActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var messageDeleteCell: UITableViewCell!
    @IBOutlet var messageDeleteLabel: UILabel!
    @IBOutlet var messageDeleteDetailLabel: UILabel!
    @IBOutlet var messageDeleteButtonLabel: UILabel!
    @IBOutlet var messageDeleteActivityIndicator: UIActivityIndicatorView!
        
    private var olderThanCell: String?
    private var mediaOlderThanOption = OlderThanOption.oneYear
    private var messageOlderThanOption = OlderThanOption.oneYear

    enum OlderThanOption: Int, CaseIterable {
        case oneYear = 0
        case sixMonths
        case threeMonths
        case oneMonth
        case oneWeek
        case everything
    }
    
    private enum Section: Int, CaseIterable {
        case storage = 0
        case deletionNote
        case deleteMedia
        case deleteMessage
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = BundleUtil.localizedString(forKey: "storage_management")
        
        storageTotal.text = BundleUtil.localizedString(forKey: "storage_total")
        storageTotalInUse.text = BundleUtil.localizedString(forKey: "storage_total_in_use")
        storageTotalFree.text = BundleUtil.localizedString(forKey: "storage_total_free")
        storageThreema.text = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "storage_threema"),
            ThreemaApp.currentName
        )
        storageThreemaActivityIndicator.hidesWhenStopped = true
        
        mediaDeleteLabel.text = BundleUtil.localizedString(forKey: "delete_media_older_than")
        mediaDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: mediaOlderThanOption)
        mediaDeleteButtonLabel.text = BundleUtil.localizedString(forKey: "delete_media")
        mediaDeleteActivityIndicator.hidesWhenStopped = true
        
        messageDeleteLabel.text = BundleUtil.localizedString(forKey: "delete_messages_older_than")
        messageDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: messageOlderThanOption)
        messageDeleteButtonLabel.text = BundleUtil.localizedString(forKey: "delete_messages")
        messageDeleteActivityIndicator.hidesWhenStopped = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateColors()
        updateSizes()

        tableView.reloadData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let senderCell = sender as? UITableViewCell,
              let olderThanViewController = segue.destination as? StorageManagementOlderThanViewController else {
                
            return
        }

        olderThanCell = senderCell.reuseIdentifier
        olderThanViewController.selectedIndex = olderThanCell == "MediaOlderThanCell" ? mediaOlderThanOption
            .rawValue : messageOlderThanOption.rawValue
    }
    
    @IBAction func refreshOlderThanIndex(_ segue: UIStoryboardSegue) {
        if let olderThanViewController = segue.source as? StorageManagementOlderThanViewController {
            if olderThanCell == "MediaOlderThanCell" {
                mediaOlderThanOption = OlderThanOption(rawValue: olderThanViewController.selectedIndex) ?? .oneYear
                mediaDeleteDetailLabel.text = StorageManagementViewController
                    .titleDescription(for: mediaOlderThanOption)
            }
            else {
                messageOlderThanOption = OlderThanOption(rawValue: olderThanViewController.selectedIndex) ?? .oneYear
                messageDeleteDetailLabel.text = StorageManagementViewController
                    .titleDescription(for: messageOlderThanOption)
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let namedSection = Section(rawValue: section) else {
            fatalError("Unknown section \(section)")
        }
        
        switch namedSection {
        case .storage:
            return 4
        case .deletionNote:
            return 0
        case .deleteMedia, .deleteMessage:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let namedSection = Section(rawValue: section) else {
            return nil
        }
        
        if namedSection == .deleteMedia {
            return BundleUtil.localizedString(forKey: "delete_media_explain")
        }
        else if namedSection == .deleteMessage {
            return BundleUtil.localizedString(forKey: "delete_messages_explain")
        }
        else if namedSection == .deletionNote {
            return BundleUtil.localizedString(forKey: "delete_explain")
        }
        return nil
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        updateColors()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let namedSection = Section(rawValue: indexPath.section) else {
            return
        }
        
        if namedSection == .deleteMedia, indexPath.row == 1 {
            // confirm delete media
            UIAlertTemplate.showConfirm(
                owner: self,
                popOverSource: mediaDeleteButtonLabel!,
                title: deleteMediaConfirmationSentence(for: mediaOlderThanOption),
                message: nil,
                titleOk: BundleUtil.localizedString(forKey: "delete_media"),
                actionOk: { _ in
                
                    self.startMediaDelete()
                    self.cleanTemporaryDirectory()
                },
                titleCancel: BundleUtil.localizedString(forKey: "cancel")
            )
        }
        else if namedSection == .deleteMessage, indexPath.row == 1 {
            // confirm delete messages
            UIAlertTemplate.showConfirm(
                owner: self,
                popOverSource: messageDeleteButtonLabel!,
                title: deleteMessageConfirmationSentence(for: messageOlderThanOption),
                message: nil,
                titleOk: BundleUtil.localizedString(forKey: "delete_messages"),
                actionOk: { _ in
                
                    self.startMessageDelete()
                    self.cleanTemporaryDirectory()
                
                },
                titleCancel: BundleUtil.localizedString(forKey: "cancel")
            )
        }
    }
    
    private func cleanTemporaryDirectory() {
        if mediaOlderThanOption == .everything {
            FileUtility.cleanTemporaryDirectory(olderThan: Date())
        }
        else {
            FileUtility.cleanTemporaryDirectory(olderThan: nil)
        }
    }
        
    override func updateColors() {
        super.updateColors()
        
        storageThreemaValue.textColor = Colors.textLight
        mediaDeleteDetailLabel.textColor = Colors.textLight
        messageDeleteDetailLabel.textColor = Colors.textLight
        mediaDeleteButtonLabel.textColor = Colors.red
        messageDeleteButtonLabel.textColor = Colors.red
        mediaDeleteActivityIndicator.color = Colors.textLight
        storageThreemaActivityIndicator.color = Colors.textLight
        messageDeleteActivityIndicator.color = Colors.textLight
    }
    
    func updateSizes() {
        storageThreemaValue.text = ""
        storageThreemaActivityIndicator.startAnimating()
        
        let deviceStorage = DeviceUtility.getStorageSize()
        
        storageTotalValue.text = ByteCountFormatter.string(
            fromByteCount: deviceStorage.totalSize ?? 0,
            countStyle: ByteCountFormatter.CountStyle.file
        )
        storageTotalInUseValue.text = ByteCountFormatter.string(
            fromByteCount: (deviceStorage.totalSize ?? 0) - (deviceStorage.totalFreeSize ?? 0),
            countStyle: ByteCountFormatter.CountStyle.file
        )
        storageTotalFreeValue.text = ByteCountFormatter.string(
            fromByteCount: deviceStorage.totalFreeSize ?? 0,
            countStyle: ByteCountFormatter.CountStyle.file
        )
        
        DispatchQueue(label: "calcStorageThreema").async {
            var dbSize: Int64 = 0
            var appSize: Int64 = 0
            if let appDataURL = FileUtility.appDataDirectory {
                // Check DatabaseManager.storeSize
                let dbURL = appDataURL.appendingPathComponent("ThreemaData.sqlite")
                dbSize = FileUtility.fileSizeInBytes(fileURL: dbURL) ?? 0
                DDLogInfo(
                    "DB size \(ByteCountFormatter.string(fromByteCount: dbSize, countStyle: ByteCountFormatter.CountStyle.file))"
                )
                
                FileUtility.pathSizeInBytes(pathURL: appDataURL, size: &appSize)
                FileUtility.pathSizeInBytes(pathURL: FileManager.default.temporaryDirectory, size: &appSize)
                DDLogInfo(
                    "APP size \(ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file))"
                )
            }
            
            DispatchQueue.main.async {
                self.storageThreemaValue.text = ByteCountFormatter.string(
                    fromByteCount: appSize,
                    countStyle: ByteCountFormatter.CountStyle.file
                )
                
                self.storageThreemaActivityIndicator.stopAnimating()
            }
        }
    }
    
    static func titleDescription(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear:
            return BundleUtil.localizedString(forKey: "one_year_title")
        case .sixMonths:
            return BundleUtil.localizedString(forKey: "six_months_title")
        case .threeMonths:
            return BundleUtil.localizedString(forKey: "three_months_title")
        case .oneMonth:
            return BundleUtil.localizedString(forKey: "one_month_title")
        case .oneWeek:
            return BundleUtil.localizedString(forKey: "one_week_title")
        case .everything:
            return BundleUtil.localizedString(forKey: "everything")
        }
    }
    
    private func description(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear:
            return BundleUtil.localizedString(forKey: "one_year")
        case .sixMonths:
            return BundleUtil.localizedString(forKey: "six_months")
        case .threeMonths:
            return BundleUtil.localizedString(forKey: "three_months")
        case .oneMonth:
            return BundleUtil.localizedString(forKey: "one_month")
        case .oneWeek:
            return BundleUtil.localizedString(forKey: "one_week")
        case .everything:
            return BundleUtil.localizedString(forKey: "everything")
        }
    }
    
    private func deleteMediaConfirmationSentence(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
            let defaultString = BundleUtil.localizedString(forKey: "delete_media_confirm")
            return String.localizedStringWithFormat(defaultString, description(for: option))
        case .everything:
            return BundleUtil.localizedString(forKey: "delete_media_confirm_all")
        }
    }
    
    private func deleteMessageConfirmationSentence(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
            let defaultString = BundleUtil.localizedString(forKey: "delete_messages_confirm")
            return String.localizedStringWithFormat(defaultString, description(for: option))
        case .everything:
            return BundleUtil.localizedString(forKey: "delete_messages_confirm_all")
        }
    }
    
    func olderThanDate(_ option: OlderThanOption) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch option {
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .everything:
            return nil
        }
    }
    
    func startMediaDelete() {
        mediaDeleteActivityIndicator.startAnimating()
        mediaDeleteButtonLabel.isHidden = true
        mediaDeleteCell.isUserInteractionEnabled = false
        
        Timer.scheduledTimer(
            timeInterval: TimeInterval(0.3),
            target: self,
            selector: #selector(mediaDelete),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func mediaDelete() {
        var dbContext: DatabaseContext!
        if Thread.isMainThread {
            dbContext = DatabaseManager.db()!.getDatabaseContext()
        }
        else {
            dbContext = DatabaseManager.db()!.getDatabaseContext(withChildContextforBackgroundProcess: true)
        }
        let destroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        if let count = destroyer.deleteMedias(olderThan: olderThanDate(mediaOlderThanOption)) {
            DDLogNotice("\(count) media files deleted")
            
            Old_ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            self.mediaDeleteActivityIndicator.stopAnimating()
            self.mediaDeleteButtonLabel.isHidden = false
            self.mediaDeleteCell.isUserInteractionEnabled = true
            
            self.updateSizes()
        }
    }
    
    func startMessageDelete() {
        messageDeleteActivityIndicator.startAnimating()
        messageDeleteButtonLabel.isHidden = true
        messageDeleteCell.isUserInteractionEnabled = false
        
        Timer.scheduledTimer(
            timeInterval: TimeInterval(0.3),
            target: self,
            selector: #selector(messageDelete),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func messageDelete() {
        var dbContext: DatabaseContext!
        if Thread.isMainThread {
            dbContext = DatabaseManager.db()!.getDatabaseContext()
        }
        else {
            dbContext = DatabaseManager.db()!.getDatabaseContext(withChildContextforBackgroundProcess: true)
        }
        let entityManager = EntityManager(databaseContext: dbContext)
        if let count = entityManager.entityDestroyer.deleteMessages(olderThan: olderThanDate(messageOlderThanOption)) {
            
            // Delete single conversation or delete last message of group conversation it has no messages
            for conversation in entityManager.entityFetcher.allConversations() {
                if let conversation = conversation as? Conversation {
                    let messageFetcher = MessageFetcher(for: conversation, with: entityManager)
                    if messageFetcher.count() == 0 {
                        if !conversation.isGroup() {
                            entityManager.performSyncBlockAndSafe {
                                entityManager.entityDestroyer.deleteObject(object: conversation)
                            }
                        }
                        else {
                            entityManager.performSyncBlockAndSafe {
                                conversation.lastMessage = nil
                            }
                        }
                    }
                }
            }

            DDLogNotice("\(count) messages deleted")

            // Recalculate unread messages count for all conversations
            if let conversations = entityManager.entityFetcher.notArchivedConversations() as? [Conversation] {
                let unreadMessages = UnreadMessages(entityManager: entityManager)
                unreadMessages.totalCount(doCalcUnreadMessagesCountOf: Set(conversations))
            }

            let notificationManager = NotificationManager()
            notificationManager.updateUnreadMessagesCount()

            Old_ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            self.messageDeleteActivityIndicator.stopAnimating()
            self.messageDeleteButtonLabel.isHidden = false
            self.messageDeleteCell.isUserInteractionEnabled = true
            
            self.updateSizes()
        }
    }
}
