//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

class StorageManagementViewController: ThemedTableViewController {
    
    @IBOutlet weak var storageTotal: UILabel!
    @IBOutlet weak var storageTotalValue: UILabel!
    @IBOutlet weak var storageTotalInUse: UILabel!
    @IBOutlet weak var storageTotalInUseValue: UILabel!
    @IBOutlet weak var storageTotalFree: UILabel!
    @IBOutlet weak var storageTotalFreeValue: UILabel!
    @IBOutlet weak var storageThreema: UILabel!
    @IBOutlet weak var storageThreemaValue: UILabel!
    @IBOutlet weak var storageThreemaActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var mediaDeleteCell: UITableViewCell!
    @IBOutlet weak var mediaDeleteLabel: UILabel!
    @IBOutlet weak var mediaDeleteDetailLabel: UILabel!
    @IBOutlet weak var mediaDeleteButtonLabel: UILabel!
    @IBOutlet weak var mediaDeleteActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var messageDeleteCell: UITableViewCell!
    @IBOutlet weak var messageDeleteLabel: UILabel!
    @IBOutlet weak var messageDeleteDetailLabel: UILabel!
    @IBOutlet weak var messageDeleteButtonLabel: UILabel!
    @IBOutlet weak var messageDeleteActivityIndicator: UIActivityIndicatorView!
        
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
        
        self.title = BundleUtil.localizedString(forKey: "storage_management")
        
        self.storageTotal.text = BundleUtil.localizedString(forKey: "storage_total")
        self.storageTotalInUse.text = BundleUtil.localizedString(forKey: "storage_total_in_use")
        self.storageTotalFree.text = BundleUtil.localizedString(forKey: "storage_total_free")
        self.storageThreema.text = BundleUtil.localizedString(forKey: "storage_threema");
        self.storageThreemaActivityIndicator.hidesWhenStopped = true
        
        self.mediaDeleteLabel.text = BundleUtil.localizedString(forKey: "delete_media_older_than")
        self.mediaDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: mediaOlderThanOption)
        self.mediaDeleteButtonLabel.text = BundleUtil.localizedString(forKey: "delete_media")
        self.mediaDeleteActivityIndicator.hidesWhenStopped = true
        
        self.messageDeleteLabel.text = BundleUtil.localizedString(forKey: "delete_messages_older_than")
        self.messageDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: messageOlderThanOption)
        self.messageDeleteButtonLabel.text = BundleUtil.localizedString(forKey: "delete_messages")
        self.messageDeleteActivityIndicator.hidesWhenStopped = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.updateColors()
        self.updateSizes()

        tableView.reloadData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let senderCell = sender as? UITableViewCell,
            let olderThanViewController = segue.destination as? StorageManagementOlderThanViewController else {
                
            return
        }

        self.olderThanCell = senderCell.reuseIdentifier
        olderThanViewController.selectedIndex = self.olderThanCell == "MediaOlderThanCell" ? mediaOlderThanOption.rawValue : messageOlderThanOption.rawValue
    }
    
    @IBAction func refreshOlderThanIndex(_ segue: UIStoryboardSegue) {
        if let olderThanViewController = segue.source as? StorageManagementOlderThanViewController {
            if self.olderThanCell == "MediaOlderThanCell" {
                self.mediaOlderThanOption = OlderThanOption(rawValue: olderThanViewController.selectedIndex) ?? .oneYear
                self.mediaDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: mediaOlderThanOption)
            }
            else {
                self.messageOlderThanOption = OlderThanOption(rawValue: olderThanViewController.selectedIndex) ?? .oneYear
                self.messageDeleteDetailLabel.text = StorageManagementViewController.titleDescription(for: messageOlderThanOption)
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
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
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if #available(iOS 11.0, *) {
            if section == 0 {
                return 38.0
            }
        }
        
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let namedSection = Section(rawValue: section) else {
            return nil
        }
        
        if namedSection == .deleteMedia {
            return BundleUtil.localizedString(forKey: "delete_media_explain")
        } else if namedSection == .deleteMessage {
            return BundleUtil.localizedString(forKey: "delete_messages_explain")
        } else if namedSection == .deletionNote {
            return BundleUtil.localizedString(forKey: "delete_explain")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Colors.update(cell)
        self.updateColors()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let namedSection = Section(rawValue: indexPath.section) else {
            return
        }
        
        if namedSection == .deleteMedia && indexPath.row == 1 {
            //confirm delete media
            UIAlertTemplate.showConfirm(owner: self, popOverSource: self.mediaDeleteButtonLabel!, title: deleteMediaConfirmationSentence(for: mediaOlderThanOption), message: nil, titleOk: BundleUtil.localizedString(forKey: "delete_media"), actionOk: { (action) in
                
                self.startMediaDelete()
                self.cleanTemporaryDirectory()
            }, titleCancel: BundleUtil.localizedString(forKey: "cancel"))
        }
        else if namedSection == .deleteMessage && indexPath.row == 1 {
            //confirm delete messages
            UIAlertTemplate.showConfirm(owner: self, popOverSource: self.messageDeleteButtonLabel!, title: deleteMessageConfirmationSentence(for: messageOlderThanOption), message: nil, titleOk: BundleUtil.localizedString(forKey: "delete_messages"), actionOk: { (action) in
                
                self.startMessageDelete()
                self.cleanTemporaryDirectory()
                
            }, titleCancel: BundleUtil.localizedString(forKey: "cancel"))
        }
    }
    
    private func cleanTemporaryDirectory() {
        if self.mediaOlderThanOption == .everything {
            FileUtility.cleanTemporaryDirectory(olderThan: Date())
        } else {
            FileUtility.cleanTemporaryDirectory(olderThan: nil)
        }
    }
        
    func updateColors() {
        self.storageThreemaValue.textColor = Colors.fontLight()
        self.mediaDeleteDetailLabel.textColor = Colors.fontLight()
        self.messageDeleteDetailLabel.textColor = Colors.fontLight()
        self.mediaDeleteButtonLabel.textColor = Colors.red()
        self.messageDeleteButtonLabel.textColor = Colors.red()
        self.mediaDeleteActivityIndicator.color = Colors.fontLight()
        self.storageThreemaActivityIndicator.color = Colors.fontLight()
        self.messageDeleteActivityIndicator.color = Colors.fontLight()
    }
    
    func updateSizes() {
        self.storageThreemaValue.text = ""
        self.storageThreemaActivityIndicator.startAnimating()
        
        let deviceStorage = FileUtility.deviceSizeInBytes()
        
        self.storageTotalValue.text = ByteCountFormatter.string(fromByteCount: deviceStorage.totalSize ?? 0, countStyle: ByteCountFormatter.CountStyle.file)
        self.storageTotalInUseValue.text = ByteCountFormatter.string(fromByteCount: (deviceStorage.totalSize ?? 0) - (deviceStorage.totalFreeSize ?? 0), countStyle: ByteCountFormatter.CountStyle.file)
        self.storageTotalFreeValue.text = ByteCountFormatter.string(fromByteCount: deviceStorage.totalFreeSize ?? 0, countStyle: ByteCountFormatter.CountStyle.file)
        
        DispatchQueue(label: "calcStorageThreema").async {
            var dbSize: Int64 = 0
            var appSize: Int64 = 0
            if let appDataUrl = FileUtility.appDataDirectory {
                // Check DatabaseManager.storeSize
                let dbUrl = appDataUrl.appendingPathComponent("ThreemaData.sqlite")
                dbSize = FileUtility.fileSizeInBytes(fileUrl: dbUrl) ?? 0
                DDLogInfo("DB size \(ByteCountFormatter.string(fromByteCount: dbSize, countStyle: ByteCountFormatter.CountStyle.file))")
                
                FileUtility.pathSizeInBytes(pathUrl: appDataUrl, size: &appSize)
                FileUtility.pathSizeInBytes(pathUrl: FileManager.default.temporaryDirectory, size: &appSize)
                DDLogInfo("APP size \(ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file))")
            }
            
            DispatchQueue.main.async {
                self.storageThreemaValue.text = ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file)
                
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
            let defaultString = BundleUtil.localizedString(forKey: "delete_media_confirm") ?? ""
            return String(format: defaultString, description(for: option))
        case .everything:
            return BundleUtil.localizedString(forKey: "delete_media_confirm_all")
        }
    }
    
    private func deleteMessageConfirmationSentence(for option: OlderThanOption) -> String {
        switch option {
        case .oneYear, .sixMonths, .threeMonths, .oneMonth, .oneWeek:
            let defaultString = BundleUtil.localizedString(forKey: "delete_messages_confirm") ?? ""
            return String(format: defaultString, description(for: option))
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
        self.mediaDeleteActivityIndicator.startAnimating()
        self.mediaDeleteButtonLabel.isHidden = true
        self.mediaDeleteCell.isUserInteractionEnabled = false
        
        Timer.scheduledTimer(timeInterval: TimeInterval(0.3), target: self, selector: #selector(self.mediaDelete), userInfo: nil, repeats: false)
    }
    
    @objc func mediaDelete() {
        let dbContext = DatabaseManager.db()!.getDatabaseContext(!Thread.isMainThread)
        let destroyer = EntityDestroyer(managedObjectContext: dbContext!.current)
        if let count = destroyer.deleteMedias(olderThan: self.olderThanDate(mediaOlderThanOption)) {
            DDLogNotice("\(count) media files deleted")
            
            ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            self.mediaDeleteActivityIndicator.stopAnimating()
            self.mediaDeleteButtonLabel.isHidden = false
            self.mediaDeleteCell.isUserInteractionEnabled = true
            
            self.updateSizes()
        }
    }
    
    func startMessageDelete() {
        self.messageDeleteActivityIndicator.startAnimating()
        self.messageDeleteButtonLabel.isHidden = true
        self.messageDeleteCell.isUserInteractionEnabled = false
        
        Timer.scheduledTimer(timeInterval: TimeInterval(0.3), target: self, selector: #selector(self.messageDelete), userInfo: nil, repeats: false)
    }
    
    @objc func messageDelete() {
        let dbContext = DatabaseManager.db()!.getDatabaseContext(!Thread.isMainThread)
        let entityManager = EntityManager(databaseContext: dbContext)!
        if let count = entityManager.entityDestroyer.deleteMessages(olderThan: self.olderThanDate(messageOlderThanOption)) {
            
            // Delete single conversation or delete last message of group conversation it has no messages
            for conversation in entityManager.entityFetcher.allConversations() {
                if let conversation = conversation as? Conversation {
                    let messageFetcher = MessageFetcher(for: conversation, with: entityManager.entityFetcher)
                    if messageFetcher?.count() == 0 {
                        if !conversation.isGroup() {
                            entityManager.performSyncBlockAndSafe({
                                entityManager.entityDestroyer.deleteObject(object: conversation)
                            })
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
            
            ChatViewControllerCache.clear()
        }
        
        DispatchQueue.main.async {
            self.messageDeleteActivityIndicator.stopAnimating()
            self.messageDeleteButtonLabel.isHidden = false
            self.messageDeleteCell.isUserInteractionEnabled = true
            
            self.updateSizes()
        }
    }
}
