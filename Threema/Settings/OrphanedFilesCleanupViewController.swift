//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import SwiftUI
import ThreemaMacros

class OrphanedFilesCleanupViewController: ThemedTableViewController {
    
    @IBOutlet var orphanedFilesDescription: UILabel!
    @IBOutlet var orphanedFilesMoveToBin: UILabel!
    @IBOutlet var orphanedFilesRestore: UILabel!
    @IBOutlet var orphanedFilesDelete: UILabel!
    @IBOutlet var logAllFiles: UILabel!
    
    private var totalFilesCount: Int?
    private var orphanedFiles: [String]?
    private var orphanedFilesInBin: [String]?
    private var orphanedFilesBinSize: Int64?

    override func viewDidLoad() {
        orphanedFilesDescription.text = String.localizedStringWithFormat(
            #localize("settings_orphaned_files_description"),
            TargetManager.appName,
            TargetManager.appName
        )
        orphanedFilesMoveToBin.text = #localize("settings_orphaned_files_button")
        orphanedFilesRestore.text = #localize("settings_orphaned_files_bin_restore_button")
        orphanedFilesDelete.text = #localize("settings_orphaned_files_bin_delete_button")
        logAllFiles.text = #localize("settings_orphaned_files_log_all_files_button")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.isUserInteractionEnabled = false
        let progress = startProgress()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(300)) {
            self.updateView()
            self.updateColors()
            
            progress?.hide(animated: true)
            self.view.isUserInteractionEnabled = true
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        updateColors()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            return 152.0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section != 0 ? UITableView.automaticDimension : 0.0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            #localize("settings_advanced_orphaned_files_cleanup")
        case 1:
            #localize("settings_orphaned_files_title")
        case 2:
            #localize("settings_orphaned_files_bin_title")
        case 3:
            #localize("settings_orphaned_files_log_title")
        default:
            nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            ""
        case 1:
            if let orphanedFiles,
               !orphanedFiles.isEmpty {
                
                String.localizedStringWithFormat(
                    #localize("settings_orphaned_files_footer"),
                    "\(orphanedFiles.count)",
                    "\((totalFilesCount ?? 0) + orphanedFiles.count)",
                    TargetManager.appName
                )
            }
            else {
                #localize("settings_orphaned_files_footer_no_files")
            }
        case 2:
            if let orphanedFilesInBin,
               !orphanedFilesInBin.isEmpty {
                
                String.localizedStringWithFormat(
                    #localize("settings_orphaned_files_bin_footer"),
                    "\(orphanedFilesInBin.count)",
                    ByteCountFormatter.string(
                        fromByteCount: orphanedFilesBinSize ?? 0,
                        countStyle: .file
                    ),
                    TargetManager.appName
                )
            }
            else {
                #localize("settings_orphaned_files_bin_footer_no_files")
            }
        default:
            nil
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 1, indexPath.row == 0, orphanedFilesMoveToBin.isEnabled {
            return indexPath
        }
        else if indexPath.section == 2, indexPath.row == 0, orphanedFilesRestore.isEnabled {
            return indexPath
        }
        else if indexPath.section == 2, indexPath.row == 1, orphanedFilesDelete.isEnabled {
            return indexPath
        }
        else if indexPath.section == 3, indexPath.row == 0, logAllFiles.isEnabled {
            return indexPath
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        func executeAction(action: @escaping () -> Swift.Void) {
            view.isUserInteractionEnabled = false
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

        if indexPath.section == 1, indexPath.row == 0, orphanedFilesMoveToBin.isEnabled {
            executeAction {
                self.moveToBin()
            }
        }
        else if indexPath.section == 2, indexPath.row == 0, orphanedFilesRestore.isEnabled {
            executeAction {
                self.restoreBin()
            }
        }
        else if indexPath.section == 2, indexPath.row == 1, orphanedFilesDelete.isEnabled {

            // Confirm delete all content of bin
            UIAlertTemplate.showConfirm(
                owner: self,
                popOverSource: orphanedFilesDelete,
                title: #localize("settings_orphaned_files_bin_delete_conformation"),
                message: nil,
                titleOk: #localize("settings_orphaned_files_bin_delete_button"),
                actionOk: { _ in
                
                    executeAction {
                        self.emptyBin()
                    }
                }, titleCancel: #localize("cancel")
            )
        }
        else if indexPath.section == 3, indexPath.row == 0, logAllFiles.isEnabled {
            DDLogNotice("Logging all files used by Threema")
            logFilesAndShowProgress()
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
           !filenames.isEmpty {
            
            totalFilesCount = result.totalFilesCount
            orphanedFiles = filenames
            
            orphanedFilesMoveToBin.isEnabled = true
        }
        else {
            orphanedFilesMoveToBin.isEnabled = false
        }
        
        if let filenames = filesInBin(),
           !filenames.isEmpty {
            
            orphanedFilesInBin = filenames
            
            if let binFolder = FileUtility.shared.appDataDirectory?
                .appendingPathComponent(EntityDestroyer.externalDataBinPath) {
                var binSize: Int64 = 0
                FileUtility.shared.pathSizeInBytes(pathURL: binFolder, size: &binSize)
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
        
        logAllFiles.isEnabled = UserSettings.shared().validationLogging
        
        tableView.reloadData()
    }
    
    override func updateColors() {
        super.updateColors()
        
        orphanedFilesMoveToBin.textColor = Colors.textLink
        orphanedFilesRestore.textColor = Colors.textLink
        orphanedFilesDelete.textColor = .systemRed
        logAllFiles.textColor = Colors.textLink
    }
    
    private func filesInBin() -> [String]? {
        let binFolder = FileUtility.shared.appDataDirectory?.appendingPathComponent(EntityDestroyer.externalDataBinPath)
        if FileUtility.shared.isExists(fileURL: binFolder) {
            return FileUtility.shared.dir(pathURL: binFolder)
        }
        return nil
    }
    
    private func moveToBin() {
        guard let orphanedFiles else {
            return
        }
        
        guard let binFolder = FileUtility.shared.appDataDirectory?
            .appendingPathComponent(EntityDestroyer.externalDataBinPath)
        else {
            return
        }
        
        if !FileUtility.shared.isExists(fileURL: binFolder), !FileUtility.shared.mkDir(at: binFolder) {
            DDLogError("Bin couldn't be created.")
            return
        }
    
        for orphanedFile in orphanedFiles {
            if let source = FileUtility.shared.appDataDirectory?
                .appendingPathComponent("\(EntityDestroyer.externalDataPath)/\(orphanedFile)"),
                !FileUtility.shared.move(source: source, destination: binFolder.appendingPathComponent(orphanedFile)) {
                
                DDLogError("Orphaned file couldn't be moved to Bin.")
            }
        }
    }
    
    private func restoreBin() {
        guard let binFolder = FileUtility.shared.appDataDirectory?
            .appendingPathComponent(EntityDestroyer.externalDataBinPath)
        else {
            return
        }
        
        if let files = FileUtility.shared.dir(pathURL: binFolder) {
            for file in files {
                if let destination = FileUtility.shared.appDataDirectory?
                    .appendingPathComponent("\(EntityDestroyer.externalDataPath)/\(file)"),
                    !FileUtility.shared.move(source: binFolder.appendingPathComponent(file), destination: destination) {
                    
                    DDLogError("Orphaned file couldn't be restored.")
                }
            }
        }

        if let files = FileUtility.shared.dir(pathURL: binFolder),
           files.isEmpty {

            FileUtility.shared.delete(at: binFolder)
        }
    }
    
    private func emptyBin() {
        guard let binFolder = FileUtility.shared.appDataDirectory?
            .appendingPathComponent(EntityDestroyer.externalDataBinPath)
        else {
            return
        }
        
        FileUtility.shared.delete(at: binFolder)
    }
    
    private func startProgress() -> MBProgressHUD? {
        guard let superview = tableView.superview else {
            return nil
        }
        return MBProgressHUD.showAdded(to: superview, animated: true)
    }
    
    private func logFilesAndShowProgress() {
        var progress: MBProgressHUD?
        DispatchQueue.main.async {
            if let superview = self.tableView.superview {
                progress = MBProgressHUD.showAdded(to: superview, animated: true)
            }
        }

        if let url = FileUtility.shared.appDataDirectory {
            FileUtility.shared.logDirectoriesAndFiles(path: url, logFileName: nil)
        }
        if let url = FileUtility.shared.appDocumentsDirectory {
            FileUtility.shared.logDirectoriesAndFiles(path: url, logFileName: nil)
        }
        if let url = FileUtility.shared.appCachesDirectory {
            FileUtility.shared.logDirectoriesAndFiles(path: url, logFileName: nil)
        }
        FileUtility.shared.logDirectoriesAndFiles(path: FileManager.default.temporaryDirectory, logFileName: nil)

        DispatchQueue.main.async {
            progress?.hide(animated: true, afterDelay: 1.5)
        }
    }
}

struct OrphanedFilesCleanupViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
        let vc = storyboard.instantiateViewController(identifier: "OrphanedFilesCleanupViewController")
        return vc
    }
}
