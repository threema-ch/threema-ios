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
import CocoaLumberjackSwift
import MBProgressHUD

class OrphanedFilesCleanupViewController: ThemedTableViewController {
    
    @IBOutlet weak var orphanedFilesDescription: UILabel!
    @IBOutlet weak var orphanedFilesMoveToBin: UILabel!
    @IBOutlet weak var orphanedFilesRestore: UILabel!
    @IBOutlet weak var orphanedFilesDelete: UILabel!
    
    private var totalFilesCount: Int?
    private var orphanedFiles: [String]?
    private var orphanedFilesInBin: [String]?
    private var orphanedFilesBinSize: Int64?

    override func viewDidLoad() {
        orphanedFilesDescription.text = BundleUtil.localizedString(forKey: "settings_orphaned_files_description")
        orphanedFilesMoveToBin.text = BundleUtil.localizedString(forKey: "settings_orphaned_files_button")
        orphanedFilesRestore.text = BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_restore_button")
        orphanedFilesDelete.text = BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_delete_button")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.isUserInteractionEnabled = false
        let progress = startProgress()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(300)) {
            self.updateView()
            self.updateColors()
            
            progress?.hide(animated: true)
            self.view.isUserInteractionEnabled = true
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Colors.update(cell)
        updateColors()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            return 152.0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section != 0 ? UITableView.automaticDimension : 0.0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "settings_advanced_orphaned_files_cleanup")
        case 1:
            return BundleUtil.localizedString(forKey: "settings_orphaned_files_title")
        case 2:
            return BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_title")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return ""
        case 1:
            if let orphanedFiles = orphanedFiles,
               orphanedFiles.count > 0 {
                
                return String(format: BundleUtil.localizedString(forKey: "settings_orphaned_files_footer"), "\(orphanedFiles.count)", "\((totalFilesCount ?? 0) + orphanedFiles.count)")
            }
            else {
                return BundleUtil.localizedString(forKey: "settings_orphaned_files_footer_no_files")
            }
        case 2:
            if let orphanedFilesInBin = orphanedFilesInBin,
                orphanedFilesInBin.count > 0 {
                
                return String(format: BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_footer"), "\(orphanedFilesInBin.count)", ByteCountFormatter.string(fromByteCount: orphanedFilesBinSize ?? 0, countStyle: ByteCountFormatter.CountStyle.file))
            }
            else {
                return BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_footer_no_files")
            }
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        func executeAction(action: @escaping () -> Swift.Void) {
            self.view.isUserInteractionEnabled = false
            let progress = startProgress()

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(300)) {
                self.orphanedFilesDelete.isEnabled = false
                self.orphanedFilesRestore.isEnabled = false
                self.orphanedFilesMoveToBin.isEnabled = false
                
                action()
                
                self.updateView()
                
                progress?.hide(animated: true)
                tableView.isUserInteractionEnabled = true
            }
       }

        if indexPath.section == 1 && indexPath.row == 0 && orphanedFilesMoveToBin.isEnabled {
            executeAction {
                self.moveToBin()
            }
        }
        else if indexPath.section == 2 && indexPath.row == 0 && orphanedFilesRestore.isEnabled {
            executeAction {
                self.restoreBin()
            }
        }
        else if indexPath.section == 2 && indexPath.row == 1 && orphanedFilesDelete.isEnabled {

            // Confirm delete all content of bin
            UIAlertTemplate.showConfirm(owner: self, popOverSource: self.orphanedFilesDelete, title: BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_delete_conformation"), message: nil, titleOk: BundleUtil.localizedString(forKey: "settings_orphaned_files_bin_delete_button"), actionOk: { (action) in
                
                executeAction {
                    self.emptyBin()
                }
            }, titleCancel: BundleUtil.localizedString(forKey: "cancel"))

        }
    }
    
    // MARK: - Private functions
    
    private func updateView() {
        totalFilesCount = 0
        orphanedFiles = nil
        orphanedFilesInBin = nil
        
        let entityManager = EntityManager()
        let result = entityManager.entityDestroyer.orphanedExternalFiles()
        
        if let filenames = result.orphanedFiles,
           filenames.count > 0 {
            
            totalFilesCount = result.totalFilesCount
            orphanedFiles = filenames
            
            orphanedFilesMoveToBin.isEnabled = true
        }
        else {
            orphanedFilesMoveToBin.isEnabled = false
        }
        
        if let filenames = filesInBin(),
           filenames.count > 0 {
            
            orphanedFilesInBin = filenames
            
            if let binFolder = FileUtility.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath) {
                var binSize: Int64 = 0
                FileUtility.pathSizeInBytes(pathUrl: binFolder, size: &binSize)
                orphanedFilesBinSize = binSize
            }
            else {
                orphanedFilesBinSize = nil
            }
            
            orphanedFilesRestore.isEnabled = true
            orphanedFilesDelete.isEnabled = true
        }
        else {
            orphanedFilesRestore.isEnabled = false
            orphanedFilesDelete.isEnabled = false
        }
        
        tableView.reloadData()
    }
    
    private func updateColors() {
        self.orphanedFilesMoveToBin.textColor = Colors.fontLink()
        self.orphanedFilesRestore.textColor = Colors.fontLink()
        self.orphanedFilesDelete.textColor = Colors.red()
    }
    
    private func filesInBin() -> [String]? {
        let binFolder = FileUtility.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath)
        if FileUtility.isExists(fileUrl: binFolder) {
            return FileUtility.dir(pathUrl: binFolder)
        }
        return nil
    }
    
    private func moveToBin() {
        guard let orphanedFiles = orphanedFiles else {
            return
        }
        
        guard let binFolder = FileUtility.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath) else {
            return
        }
        
        if !FileUtility.isExists(fileUrl: binFolder) && !FileUtility.mkDir(at: binFolder) {
            DDLogError("Bin couldn't be created.")
            return
        }
    
        for orphanedFile in orphanedFiles {
            if let source = FileUtility.appDataDirectory?.appendingPathComponent("\(EntityDestroyer.externalDataPath)/\(orphanedFile)"),
               !FileUtility.move(source: source, destination: binFolder.appendingPathComponent(orphanedFile)) {
                
                DDLogError("Orphaned file couldn't be moved to Bin.")
            }
        }
    }
    
    private func restoreBin() {
        guard let binFolder = FileUtility.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath) else {
            return
        }
        
        if let files = FileUtility.dir(pathUrl: binFolder) {
            for file in files {
                if let destination = FileUtility.appDataDirectory?.appendingPathComponent("\(EntityDestroyer.externalDataPath   )/\(file)"),
                   !FileUtility.move(source: binFolder.appendingPathComponent(file), destination: destination) {
                    
                    DDLogError("Orphaned file couldn't be restored.")
                }
            }
        }

        if let files = FileUtility.dir(pathUrl: binFolder),
           files.count == 0 {

            FileUtility.delete(at: binFolder)
        }
    }
    
    private func emptyBin() {
        guard let binFolder = FileUtility.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath) else {
            return
        }
        
        FileUtility.delete(at: binFolder)
    }
    
    private func startProgress() -> MBProgressHUD? {
        guard let superview = tableView.superview else {
            return nil
        }
        return MBProgressHUD.showAdded(to: superview, animated: true)
    }
}
