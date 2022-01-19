//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

@objc class SafeManager: NSObject {
    
    private var safeConfigManager: SafeConfigManagerProtocol
    private var safeStore: SafeStore
    private var safeApiService: SafeApiService
    private var logger: ValidationLogger

    //trigger safe backup states
    private static var backupObserver: NSObjectProtocol?
    private static var backupDelay: Timer?
    private static let backupProcessLock: DispatchQueue = DispatchQueue(label: "backupProcessLock")
    private static var backupProcessStart: Bool = false
    private static var backupIsRunning: Bool = false
    private var backupForce: Bool = false
    private var backupCompletionHandler: (() -> Void)? = nil

    private var checksum: [UInt8]?

    enum SafeError: Error {
        case activateFailed(message: String)
        case backupFailed(message: String)
        case restoreError(message: String)
        case restoreFailed(message: String)
    }
    
    init(safeConfigManager: SafeConfigManagerProtocol, safeStore: SafeStore, safeApiService: SafeApiService) {
        self.safeConfigManager = safeConfigManager
        self.safeStore = safeStore
        self.safeApiService = safeApiService
        self.logger = ValidationLogger.shared()
    }
    
    //NSObject thereby not the whole SafeConfigManagerProtocol interface must be like @objc
    @objc convenience init(safeConfigManagerAsObject safeConfigManager: NSObject, safeStore: SafeStore, safeApiService: SafeApiService) {
        self.init(safeConfigManager: safeConfigManager as! SafeConfigManagerProtocol, safeStore: safeStore, safeApiService: safeApiService)
    }
    
    @objc var isActivated: Bool {
        get {
            if let key = self.safeConfigManager.getKey() {
                return key.count == self.safeStore.masterKeyLength
            }
            return false
        }
    }
    
    var isBackupRunning: Bool {
        get {
            return SafeManager.backupIsRunning
        }
    }

    @objc func activate(identity: String, password: String) throws {
        self.safeConfigManager.setKey(self.safeStore.createKey(identity: identity, password: password))
        self.safeConfigManager.setIsTriggered(true)

        initTrigger()
    }
    
    @objc func activate(identity: String, password: String, customServer: String?, server: String?, maxBackupBytes: NSNumber?, retentionDays: NSNumber?) throws {
        if let key = self.safeStore.createKey(identity: identity, password: password) {
            try activate(key: key, customServer: customServer, server: server, maxBackupBytes: maxBackupBytes?.intValue, retentionDays: retentionDays?.intValue)
        }
    }
    
    func activate(key: [UInt8], customServer: String?, server: String?, maxBackupBytes: Int?, retentionDays: Int?) throws {
        if let customServer = customServer,
            let server = server {
            
            self.safeConfigManager.setKey(key)
            self.safeConfigManager.setCustomServer(customServer)
            self.safeConfigManager.setServer(server)
            self.safeConfigManager.setMaxBackupBytes(maxBackupBytes)
            self.safeConfigManager.setRetentionDays(retentionDays)
        } else {
            if let defaultServer = self.safeStore.getSafeDefaultServer(key: key) {
                let result = testServer(serverUrl: defaultServer)
                if let errorMessage = result.errorMessage {
                    throw SafeError.activateFailed(message: "Test default server: \(errorMessage)")
                } else {
                    self.safeConfigManager.setKey(key)
                    self.safeConfigManager.setCustomServer(nil)
                    self.safeConfigManager.setServer(defaultServer.absoluteString)
                    self.safeConfigManager.setMaxBackupBytes(result.maxBackupBytes)
                    self.safeConfigManager.setRetentionDays(result.retentionDays)
                }
            }
        }

        initTrigger()
    }
    
    @objc func deactivate() {
        if let observer = SafeManager.backupObserver {
            SafeManager.backupObserver = nil
            NotificationCenter.default.removeObserver(observer, name: Notification.Name(kSafeBackupTrigger), object: nil)
        }
        
        if let key = self.safeConfigManager.getKey(),
            let backupId = self.safeStore.getBackupId(key: key) {
            
            if let safeServer = self.safeStore.getSafeServer(key: key) {
                let safeServerAuth = self.safeStore.extractSafeServerAuth(server: safeServer)
                let safeBackupUrl = safeServerAuth.server.appendingPathComponent("backups/\(SafeStore.dataToHexString(backupId))")
                if let errorMessage = safeApiService.delete(server: safeBackupUrl, user: safeServerAuth.user, password: safeServerAuth.password) {
                    self.logger.logString("Safe backup could not be deleted: \(errorMessage)")
                }
            }
        }
        
        self.safeConfigManager.setKey(nil)
        self.safeConfigManager.setCustomServer(nil)
        self.safeConfigManager.setServer(nil)
        self.safeConfigManager.setMaxBackupBytes(nil)
        self.safeConfigManager.setRetentionDays(nil)
        self.safeConfigManager.setLastBackup(nil)
        self.safeConfigManager.setLastChecksum(nil)
        self.safeConfigManager.setLastResult(nil)
        self.safeConfigManager.setLastAlertBackupFailed(nil)
        self.safeConfigManager.setBackupStartedAt(nil)
        self.safeConfigManager.setIsTriggered(false)
        
        DispatchQueue.main.async {
            self.setBackupReminder()
        }
    }

    func isPasswordBad(password: String) -> Bool {
        if password.count < 8 {
            return true
        }
        else if checkPasswordToRegEx(password: password) {
            return true
        }
        
        return checkPasswordToFile(password: password)
    }

    private func checkPasswordToFile(password: String) -> Bool {
        
        guard let filePath = Bundle.main.path(forResource: "bad_passwords", ofType: "txt"),
            let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            
            return false
        }
        
        defer {
            fileHandle.closeFile()
        }

        let delimiter: Data = String(stringLiteral: "\n").data(using: .utf8)!
        let chunkSize = 4096
        var isEof: Bool = false
        var lineStart: String = ""

        while !isEof {
            var position: Int = 0
            let chunk = fileHandle.readData(ofLength: chunkSize)
            if chunk.count == 0 {
                isEof = true
            }
            
            //compare password with all lines within the chunk
            repeat {
                var line: String = ""
                if let range = chunk.subdata(in: position..<chunk.count).range(of: delimiter) {
                    if lineStart.count > 0 {
                        line.append(lineStart)
                        lineStart = ""
                    }
                    line.append(String(data: chunk.subdata(in: position..<position+range.lowerBound), encoding: .utf8)!)
                    position += range.upperBound
                } else {
                    //store start characters of next line/chunk
                    if chunk.count > position {
                        lineStart = String(data: chunk.subdata(in: position..<chunk.count), encoding: .utf8)!
                    }
                    position = chunk.count
                }
                
                if line.count > 0 && line == password {
                    return true
                }
            } while chunk.count > position
        }
        
        return false
    }
    
    private func checkPasswordToRegEx(password: String) -> Bool {
        let checks = [
            "(.)\\1+",           //do not allow single repeating characters
            "^[0-9]{1,15}$"]     //do not allow numbers only
        
        do {
            for check in checks {
                let regex = try NSRegularExpression(pattern: check, options: .caseInsensitive)
                let result = regex.matches(in: password, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: password.count))
                
                //result must match once the whole password/string
                if result.count == 1 && result[0].range.location == 0 && result[0].range.length == password.count {
                    return true
                }
            }
        } catch let error {
            print("regex faild to check password: \(error.localizedDescription)")
        }
        
        return false
    }
    
    static func isPasswordPatternValid(password: String, regExPattern: String) throws -> Bool {
        var regExMatches: Int = 0
        let regEx = try NSRegularExpression(pattern: regExPattern)
        regExMatches = regEx.numberOfMatches(in: password, options: [], range: NSRange.init(location: 0, length: password.count))
        return regExMatches == 1
    }
    
    @objc func setBackupReminder() {
        
        // remove safe backup notification anyway
        let notificationKey = "safe-backup-notification"
        let oneDayInSeconds = 24 * 60 * 60
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationKey])
        DDLogNotice("Threema Safe: Reminder notification removed")
            
        // add new safe backup notification, if is Threema Safe activated and is set backup retention days
        if self.isActivated,
            let lastBackup = self.safeConfigManager.getLastBackup(),
            let retentionDays = self.safeConfigManager.getRetentionDays() {
            
            let notification = UNMutableNotificationContent()
            notification.title = BundleUtil.localizedString(forKey: "safe_setup_backup_title")
            notification.body = BundleUtil.localizedString(forKey: "safe_expired_notification")
            notification.categoryIdentifier = "SAFE_SETUP"
            notification.userInfo = ["threema": ["nil": "nil"], "key": notificationKey]
            
            var trigger: UNTimeIntervalNotificationTrigger?
            var fireDate = lastBackup.addingTimeInterval(TimeInterval(oneDayInSeconds * (retentionDays / 2)))
            if fireDate.timeIntervalSinceNow <= 0 { // Fire date is in the past
                fireDate = lastBackup.addingTimeInterval(TimeInterval(oneDayInSeconds * retentionDays))
                if fireDate.timeIntervalSinceNow <= 0 { // Safe backup it outside of retention days
                    let seconds = lastBackup.timeIntervalSinceNow
                    let days = Double(exactly: seconds / Double(oneDayInSeconds))?.rounded(.up)
                    notification.body = String(format: BundleUtil.localizedString(forKey: "safe_failed_notification"),  abs(days!))
                } else {
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
                }
            } else { // Fire date is in the future
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
            }
            
            let notificationRequest = UNNotificationRequest(identifier: notificationKey, content: notification, trigger: trigger)
            UNUserNotificationCenter.current().add(notificationRequest) { error in
                if let error = error {
                    DDLogError("Threema Safe: Error adding reminder to fire at \(DateFormatter.getFullDate(for: fireDate)): \(error.localizedDescription)")
                } else {
                    DDLogNotice("Threema Safe: Reminder notification added, fire at: \(DateFormatter.getFullDate(for: fireDate))")
                }
            }
        }
    }

    func testServer(serverUrl: URL) -> (errorMessage: String?, maxBackupBytes: Int?, retentionDays: Int?) {
        let safeServerAuth = self.safeStore.extractSafeServerAuth(server: serverUrl)
        let result = self.safeApiService.testServer(server: safeServerAuth.server, user: safeServerAuth.user, password: safeServerAuth.password)
        
        if let errorMessage = result.errorMessage {
            return (errorMessage: errorMessage, maxBackupBytes: nil, retentionDays: nil)
        } else {
            let parser = SafeJsonParser()
            guard let data = result.serverConfig,
                let config = parser.getSafeServerConfig(from: data) else {
                    
                    return (errorMessage: "Invalid response data", maxBackupBytes: nil, retentionDays: nil)
            }
            
            return (errorMessage: nil, maxBackupBytes: config.maxBackupBytes, retentionDays: config.retentionDays)
        }
    }
    
    /// Apply Threema Safe server it has changed
    @objc func applyServer(server: String?, username: String?, password: String?) {
        if self.isActivated {
            var newServerUrl: URL?

            if let customServer = server {
                newServerUrl = self.safeStore.composeSafeServerAuth(server: customServer, user: username, password: password)
            } else {
                newServerUrl = self.safeStore.getSafeDefaultServer(key: self.safeConfigManager.getKey()!)
            }
            
            if let newServerUrl = newServerUrl {
                if self.safeConfigManager.getServer() != newServerUrl.absoluteString {
                    // Save Threema Safe server config and reset result and control config
                    self.safeConfigManager.setCustomServer(server)
                    self.safeConfigManager.setServer(newServerUrl.absoluteString)
                    self.safeConfigManager.setMaxBackupBytes(nil)
                    self.safeConfigManager.setRetentionDays(nil)
                    self.safeConfigManager.setLastChecksum(nil)
                    self.safeConfigManager.setBackupSize(nil)
                    self.safeConfigManager.setBackupStartedAt(nil)
                    self.safeConfigManager.setLastAlertBackupFailed(nil)
                    self.safeConfigManager.setIsTriggered(true)
                    self.safeConfigManager.setLastResult(nil)
                    self.safeConfigManager.setLastBackup(nil)
                }
            } else {
                self.logger.logString("Error while apply Threema Safe server: could not calculate server")
            }
        }
    }
    
    private func startBackup(force: Bool, completionHandler: @escaping () -> Void) {
        
        self.backupCompletionHandler = completionHandler
        
        do {
            if let key = self.safeConfigManager.getKey(),
                let backupId = self.safeStore.getBackupId(key: key) {

                // get backup data and and its checksum
                if let data = self.safeStore.backupData() {
                    self.checksum = self.safeStore.sha1(data: Data(data))
                    
                    // do backup is forced or if data has changed or last backup (nearly) out of date
                    if force || self.safeConfigManager.getLastChecksum() != self.checksum || self.safeStore.isDateOlderThenDays(date: self.safeConfigManager.getLastBackup(), days: self.safeConfigManager.getRetentionDays() ?? 180 / 2) {
                        
                        self.safeConfigManager.setBackupStartedAt(Date())
                        
                        // test server and save its config
                        if let safeServerUrl = self.safeStore.getSafeServer(key: key) {
                            let safeServerAuth = self.safeStore.extractSafeServerAuth(server: safeServerUrl)
                            let safeBackupUrl = safeServerAuth.server.appendingPathComponent("backups/\(SafeStore.dataToHexString(backupId))")
                            
                            let result = testServer(serverUrl: safeServerUrl)
                            if let errorMessage = result.errorMessage {
                                throw SafeError.backupFailed(message: errorMessage)
                            } else {
                                self.safeConfigManager.setMaxBackupBytes(result.maxBackupBytes)
                                self.safeConfigManager.setRetentionDays(result.retentionDays)
                            }
                            
                            // encrypt backup data and upload it
                            let encryptedData = try self.safeStore.encryptBackupData(key: key, data: data)
                            
                            // set actual backup size anyway
                            self.safeConfigManager.setBackupSize(Int64(encryptedData.count))
                            
                            if encryptedData.count < self.safeConfigManager.getMaxBackupBytes() ?? 524288 {
                                
                                self.safeApiService.upload(backup: safeBackupUrl, user: safeServerAuth.user, password: safeServerAuth.password, encryptedData: encryptedData) { (data, errorMessage) in
                                    if let errorMessage = errorMessage {
                                        self.logger.logString(errorMessage)
                                        
                                        self.safeConfigManager.setLastResult(errorMessage.contains("Payload Too Large") ? BundleUtil.localizedString(forKey: "safe_upload_size_exceeded") : "\(BundleUtil.localizedString(forKey: "safe_upload_failed")) (\(errorMessage))")
                                    } else {
                                        self.safeConfigManager.setLastChecksum(self.checksum)
                                        self.safeConfigManager.setLastBackup(Date())
                                        self.safeConfigManager.setLastResult(BundleUtil.localizedString(forKey: "safe_successful"))
                                        self.safeConfigManager.setLastAlertBackupFailed(nil)
                                    }
                                    
                                    self.backupCompletionHandler!()
                                }
                                
                            } else {
                                throw SafeError.backupFailed(message: BundleUtil.localizedString(forKey: "safe_upload_size_exceeded"))
                            }
                        } else {
                            throw SafeError.backupFailed(message: "Invalid safe server url")
                        }
                        
                        // cancel background task here, because the upload it's a background task too
                        BackgroundTaskManager.shared.cancelBackgroundTask(key: kSafeBackgroundTask)
                    } else {
                        self.backupCompletionHandler!()
                    }
                } else {
                    throw SafeError.backupFailed(message: "Missing private key")
                }
            } else {
                throw SafeStore.SafeError.invalidMasterKey
            }
        } catch SafeError.backupFailed(let message) {
            self.logger.logString(message)
            
            self.safeConfigManager.setLastResult("\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(message)")

            self.backupCompletionHandler!()
        } catch let error {
            self.logger.logString(error.localizedDescription)
            
            self.safeConfigManager.setLastResult("\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(error.localizedDescription)")

            self.backupCompletionHandler!()
        }
    }
    
    func startRestore(identity:String, password: String, customServer: String?, server: String?, restoreIdentityOnly: Bool, activateSafeAnyway: Bool, completionHandler: @escaping (SafeError?) -> Swift.Void) {
        
        if let key = self.safeStore.createKey(identity: identity, password: password),
            let backupId = self.safeStore.getBackupId(key: key) {
            
            var safeServerUrl: URL
            if let server = server,
                server.count > 0 {
                
                safeServerUrl = URL(string: server)!
            } else {
                safeServerUrl = self.safeStore.getSafeDefaultServer(key: key)!
            }
            
            let safeServerAuth = self.safeStore.extractSafeServerAuth(server: safeServerUrl)
            let backupUrl = safeServerAuth.server.appendingPathComponent("backups/\(SafeStore.dataToHexString(backupId))")
            
            var decryptedData: [UInt8]?
            
            do {
                let safeApiService = SafeApiService()
                let encryptedData = try safeApiService.download(backup: backupUrl, user: safeServerAuth.user, password: safeServerAuth.password)

                if encryptedData != nil {
                    decryptedData = try self.safeStore.decryptBackupData(key: key, data: Array(encryptedData!))
                    
                    try self.safeStore.restoreData(identity: identity, data: decryptedData!, onlyIdentity: restoreIdentityOnly, completionHandler: { (error) in
                        if let error = error {
                            switch error {
                            case .restoreError(let message):
                                completionHandler(SafeError.restoreError(message: message))
                            case .restoreFailed(let message):
                                completionHandler(SafeError.restoreFailed(message: message))
                            default: break
                            }
                        } else {
                            do {
                                if (!restoreIdentityOnly || activateSafeAnyway) {
                                    //activate Threema Safe
                                    try self.activate(key: key, customServer: customServer, server: safeServerUrl.absoluteString, maxBackupBytes: nil, retentionDays: nil)
                                } else {
                                    //show Threema Safe-Intro
                                    UserSettings.shared()?.safeIntroShown = false
                                }
                            
                                //trigger backup
                                NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: nil)
                                
                                completionHandler(nil)
                            } catch {
                                completionHandler(SafeError.restoreError(message: BundleUtil.localizedString(forKey: "safe_activation_failed")))
                            }
                        }
                    })
                }
            } catch SafeApiService.SafeApiError.requestFailed(let message) {
                completionHandler(SafeError.restoreFailed(message: "\(BundleUtil.localizedString(forKey: "safe_no_backup_found")) (\(message))"))
            } catch SafeStore.SafeError.restoreFailed(let message) {
                completionHandler(SafeError.restoreFailed(message: message))
                
                if let decryptedData = decryptedData {
                    // Save decrypted backup data into application documents folder, for analyzing failures
                    _ = FileUtility.write(fileUrl: DocumentManager.applicationDocumentsDirectory()?.appendingPathComponent("safe-backup.json"), text: String(bytes: decryptedData, encoding: .utf8)!)
                }
            } catch {
                completionHandler(SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found")))
            }
        } else {
            completionHandler(SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found")))
        }
    }
    
    @objc func initTrigger() {
        
        DDLogVerbose("Threema Safe triggered")
        
        if isActivated {
            if SafeManager.backupObserver == nil {
                SafeManager.backupObserver = NotificationCenter.default.addObserver(forName: Notification.Name(kSafeBackupTrigger), object: nil, queue: nil) { (notification) in
                    if !AppDelegate.shared().isAppInBackground() && self.isActivated {
                        
                        //start background task to give time to create backup file, if the app is going into background
                        BackgroundTaskManager.shared.newBackgroundTask(key: kSafeBackgroundTask, timeout: 60, completionHandler: {
                            if SafeManager.backupDelay != nil {
                                SafeManager.backupDelay?.invalidate()
                            }
                            
                            // set 5s delay timer to start backup (if delay time 0s, then force backup)
                            var interval: Int = 5
                            if notification.object is Int {
                                interval = notification.object as! Int
                            }
                            self.backupForce = interval == 0
                            
                            //async is necessary if the call is already within an operation queue (like after setup completion)
                            SafeManager.backupDelay = Timer.scheduledTimer(timeInterval: TimeInterval(interval), target: self, selector: #selector(self.trigger), userInfo: nil, repeats: false)
                        })
                    }
                }
            }
            
            if self.safeConfigManager.getIsTriggered() || self.safeStore.isDateOlderThenDays(date: self.safeConfigManager.getLastBackup(), days: 1)  {
                NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: nil)
            }
            
            // Show alert once a day, if is last successful backup older than 7 days
            if self.safeConfigManager.getLastResult() != BundleUtil.localizedString(forKey: "safe_successful") && self.safeConfigManager.getLastBackup() != nil && self.safeStore.isDateOlderThenDays(date: self.safeConfigManager.getLastBackup(), days: 7) {
                
                DDLogWarn("WARNING Threema Safe backup not successfully since 7 days or more")
                self.logger.logString("WARNING Threema Safe backup not successfully since 7 days or more")
            
                if self.safeStore.isDateOlderThenDays(date: self.safeConfigManager.getLastAlertBackupFailed(), days: 1) {
                    if let topViewController = AppDelegate.shared()?.currentTopViewController(),
                        let seconds = self.safeConfigManager.getLastBackup()?.timeIntervalSinceNow,
                        let days = Double(exactly: seconds / 86400)?.rounded(FloatingPointRoundingRule.up) {

                        self.safeConfigManager.setLastAlertBackupFailed(Date())
                        
                        UIAlertTemplate.showAlert(owner: topViewController, title: BundleUtil.localizedString(forKey: "safe_setup_backup_title"), message: String(format: BundleUtil.localizedString(forKey: "safe_failed_notification"),  abs(days)))
                    }
                }
            }
        }
    }
    
    @objc private func trigger() {
        DispatchQueue(label: "backupProcess").async {

            //if forced, try to start backup immediately, otherwise when backup process is already running or last backup not older then a day then just mark as triggered
            SafeManager.backupProcessLock.sync {
                SafeManager.backupProcessStart = false

                if self.backupForce && SafeManager.backupIsRunning {
                    self.safeConfigManager.setLastResult("\(NSLocalizedString("safe_unsuccessful", comment: "")): is already running")
                } else if !self.backupForce && (SafeManager.backupIsRunning || !self.safeStore.isDateOlderThenDays(date: self.safeConfigManager.getLastBackup(), days: 1)) {
                    
                    self.safeConfigManager.setIsTriggered(true)
                    self.logger.logString("Safe backup just triggered")
                } else {
                    SafeManager.backupProcessStart = true
                    SafeManager.backupIsRunning = true
                    self.safeConfigManager.setIsTriggered(false)
                }
            }

            if SafeManager.backupProcessStart {
                self.logger.logString("Safe backup start, force \(self.backupForce)")
                
                self.startBackup(force: self.backupForce) {
                    SafeManager.backupProcessLock.sync {
                        SafeManager.backupIsRunning = false
                        BackgroundTaskManager.shared.cancelBackgroundTask(key: kSafeBackgroundTask)
                    }

                    DispatchQueue.main.async {
                        self.setBackupReminder()
                        NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupUIRefresh), object: nil)
                    }
                    
                    self.logger.logString("Safe backup completed")
                }
            } else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: kSafeBackgroundTask)
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupUIRefresh), object: nil)
            }
        }
    }
}
