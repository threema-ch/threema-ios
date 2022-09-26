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

import CocoaLumberjackSwift
import Foundation

@objc class SafeManager: NSObject {
    
    private var safeConfigManager: SafeConfigManagerProtocol
    private var safeStore: SafeStore
    private var safeApiService: SafeApiService
    private var logger: ValidationLogger

    // trigger safe backup states
    private static var backupObserver: NSObjectProtocol?
    private static var backupDelay: Timer?
    private static let backupProcessLock = DispatchQueue(label: "backupProcessLock")
    private static var backupProcessStart = false
    private static var backupIsRunning = false
    private var backupForce = false

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
    
    // NSObject thereby not the whole SafeConfigManagerProtocol interface must be like @objc
    @objc convenience init(
        safeConfigManagerAsObject safeConfigManager: NSObject,
        safeStore: SafeStore,
        safeApiService: SafeApiService
    ) {
        self.init(
            safeConfigManager: safeConfigManager as! SafeConfigManagerProtocol,
            safeStore: safeStore,
            safeApiService: safeApiService
        )
    }
    
    @objc var isActivated: Bool {
        if let key = safeConfigManager.getKey() {
            return key.count == safeStore.masterKeyLength
        }
        return false
    }
    
    var isBackupRunning: Bool {
        SafeManager.backupIsRunning
    }

    @objc func activate(identity: String, password: String) throws {
        safeConfigManager.setKey(safeStore.createKey(identity: identity, password: password))
        safeConfigManager.setIsTriggered(true)

        initTrigger()
    }
    
    @objc func activate(
        identity: String,
        password: String,
        customServer: String?,
        server: String?,
        maxBackupBytes: NSNumber?,
        retentionDays: NSNumber?,
        completion: @escaping (Error?) -> Void
    ) {
        if let key = safeStore.createKey(identity: identity, password: password) {
            activate(
                key: key,
                customServer: customServer,
                server: server,
                maxBackupBytes: maxBackupBytes?.intValue,
                retentionDays: retentionDays?.intValue,
                completion: completion
            )
        }
    }
    
    func activate(
        key: [UInt8],
        customServer: String?,
        server: String?,
        maxBackupBytes: Int?,
        retentionDays: Int?,
        completion: @escaping (Error?) -> Void
    ) {
        if let customServer = customServer,
           let server = server {
            
            safeConfigManager.setKey(key)
            safeConfigManager.setCustomServer(customServer)
            safeConfigManager.setServer(server)
            safeConfigManager.setMaxBackupBytes(maxBackupBytes)
            safeConfigManager.setRetentionDays(retentionDays)
            initTrigger()
            completion(nil)
        }
        else {
            safeStore.getSafeDefaultServer(key: key) { result in
                switch result {
                case let .success(defaultServer):
                    let testResult = self.testServer(serverURL: defaultServer)
                    if let errorMessage = testResult.errorMessage {
                        completion(SafeError.activateFailed(message: "Test default server: \(errorMessage)"))
                    }
                    else {
                        self.safeConfigManager.setKey(key)
                        self.safeConfigManager.setCustomServer(nil)
                        self.safeConfigManager.setServer(defaultServer.absoluteString)
                        self.safeConfigManager.setMaxBackupBytes(testResult.maxBackupBytes)
                        self.safeConfigManager.setRetentionDays(testResult.retentionDays)
                        
                        self.initTrigger()
                        completion(nil)
                    }
                case let .failure(error):
                    completion(error)
                }
            }
        }
    }
    
    @objc func deactivate() {
        if let observer = SafeManager.backupObserver {
            SafeManager.backupObserver = nil
            NotificationCenter.default.removeObserver(
                observer,
                name: Notification.Name(kSafeBackupTrigger),
                object: nil
            )
        }
        
        if let key = safeConfigManager.getKey(),
           let backupID = safeStore.getBackupID(key: key) {
            
            safeStore.getSafeServer(key: key) { result in
                switch result {
                case let .success(safeServer):
                    let safeServerAuth = self.safeStore.extractSafeServerAuth(server: safeServer)
                    let safeBackupURL = safeServerAuth.server
                        .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                    if let errorMessage = self.safeApiService.delete(
                        server: safeBackupURL,
                        user: safeServerAuth.user,
                        password: safeServerAuth.password
                    ) {
                        self.logger.logString("Safe backup could not be deleted: \(errorMessage)")
                    }
                case .failure: break
                }
            }
        }
        
        safeConfigManager.setKey(nil)
        safeConfigManager.setCustomServer(nil)
        safeConfigManager.setServer(nil)
        safeConfigManager.setMaxBackupBytes(nil)
        safeConfigManager.setRetentionDays(nil)
        safeConfigManager.setLastBackup(nil)
        safeConfigManager.setLastChecksum(nil)
        safeConfigManager.setLastResult(nil)
        safeConfigManager.setLastAlertBackupFailed(nil)
        safeConfigManager.setBackupStartedAt(nil)
        safeConfigManager.setIsTriggered(false)
        
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
        var isEof = false
        var lineStart = ""

        while !isEof {
            var position = 0
            let chunk = fileHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty {
                isEof = true
            }
            
            // compare password with all lines within the chunk
            repeat {
                var line = ""
                if let range = chunk.subdata(in: position..<chunk.count).range(of: delimiter) {
                    if !lineStart.isEmpty {
                        line.append(lineStart)
                        lineStart = ""
                    }
                    line
                        .append(String(
                            data: chunk.subdata(in: position..<position + range.lowerBound),
                            encoding: .utf8
                        )!)
                    position += range.upperBound
                }
                else {
                    // store start characters of next line/chunk
                    if chunk.count > position {
                        lineStart = String(data: chunk.subdata(in: position..<chunk.count), encoding: .utf8)!
                    }
                    position = chunk.count
                }
                
                if !line.isEmpty, line == password {
                    return true
                }
            }
            while chunk.count > position
        }
        
        return false
    }
    
    private func checkPasswordToRegEx(password: String) -> Bool {
        let checks = [
            "(.)\\1+", // do not allow single repeating characters
            "^[0-9]{1,15}$",
        ] // do not allow numbers only
        
        do {
            for check in checks {
                let regex = try NSRegularExpression(pattern: check, options: .caseInsensitive)
                let result = regex.matches(
                    in: password,
                    options: NSRegularExpression.MatchingOptions(rawValue: 0),
                    range: NSRange(location: 0, length: password.count)
                )
                
                // result must match once the whole password/string
                if result.count == 1, result[0].range.location == 0, result[0].range.length == password.count {
                    return true
                }
            }
        }
        catch {
            print("regex faild to check password: \(error.localizedDescription)")
        }
        
        return false
    }
    
    static func isPasswordPatternValid(password: String, regExPattern: String) throws -> Bool {
        var regExMatches = 0
        let regEx = try NSRegularExpression(pattern: regExPattern)
        regExMatches = regEx.numberOfMatches(
            in: password,
            options: [],
            range: NSRange(location: 0, length: password.count)
        )
        return regExMatches == 1
    }
    
    @objc func setBackupReminder() {
        
        // remove safe backup notification anyway
        let notificationKey = "safe-backup-notification"
        let oneDayInSeconds = 24 * 60 * 60
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationKey])
        DDLogNotice("Threema Safe: Reminder notification removed")
            
        // add new safe backup notification, if is Threema Safe activated and is set backup retention days
        if isActivated,
           let lastBackup = safeConfigManager.getLastBackup(),
           let retentionDays = safeConfigManager.getRetentionDays() {
            
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
                    notification.body = String(
                        format: BundleUtil.localizedString(forKey: "safe_failed_notification"),
                        abs(days!)
                    )
                }
                else {
                    trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: fireDate.timeIntervalSinceNow,
                        repeats: false
                    )
                }
            }
            else { // Fire date is in the future
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
            }
            
            let notificationRequest = UNNotificationRequest(
                identifier: notificationKey,
                content: notification,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(notificationRequest) { error in
                if let error = error {
                    DDLogError(
                        "Threema Safe: Error adding reminder to fire at \(DateFormatter.getFullDate(for: fireDate)): \(error.localizedDescription)"
                    )
                }
                else {
                    DDLogNotice(
                        "Threema Safe: Reminder notification added, fire at: \(DateFormatter.getFullDate(for: fireDate))"
                    )
                }
            }
        }
    }

    func testServer(serverURL: URL) -> (errorMessage: String?, maxBackupBytes: Int?, retentionDays: Int?) {
        let safeServerAuth = safeStore.extractSafeServerAuth(server: serverURL)
        let result = safeApiService.testServer(
            server: safeServerAuth.server,
            user: safeServerAuth.user,
            password: safeServerAuth.password
        )
        
        if let errorMessage = result.errorMessage {
            return (errorMessage: errorMessage, maxBackupBytes: nil, retentionDays: nil)
        }
        else {
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
        if isActivated {
            let doApply: (URL?) -> Void = { newServerURL in
                if let newServerURL = newServerURL {
                    if self.safeConfigManager.getServer() != newServerURL.absoluteString {
                        // Save Threema Safe server config and reset result and control config
                        self.safeConfigManager.setCustomServer(server)
                        self.safeConfigManager.setServer(newServerURL.absoluteString)
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
                }
                else {
                    self.logger.logString("Error while apply Threema Safe server: could not calculate server")
                }
            }

            if let customServer = server {
                doApply(safeStore.composeSafeServerAuth(server: customServer, user: username, password: password))
            }
            else {
                safeStore.getSafeDefaultServer(key: safeConfigManager.getKey()!) { result in
                    switch result {
                    case let .success(newServerURL):
                        doApply(newServerURL)
                    case let .failure(error):
                        self.logger.logString("Cannot obtain default server: \(error)")
                    }
                }
            }
        }
    }
    
    private func startBackup(force: Bool, completionHandler: @escaping () -> Void) {
        
        do {
            if let key = safeConfigManager.getKey(),
               let backupID = safeStore.getBackupID(key: key) {

                // get backup data and and its checksum
                if let data = safeStore.backupData() {
                    checksum = BytesUtility.sha1(data: Data(data))
                    
                    // do backup is forced or if data has changed or last backup (nearly) out of date
                    if force || safeConfigManager.getLastChecksum() != checksum || safeStore.isDateOlderThenDays(
                        date: safeConfigManager.getLastBackup(),
                        days: safeConfigManager.getRetentionDays() ?? 180 / 2
                    ) {
                        
                        safeConfigManager.setBackupStartedAt(Date())
                        
                        // test server and save its config
                        safeStore.getSafeServer(key: key) { result in
                            self.handleTestResultSaveConfig(
                                key: key,
                                data: data,
                                backupID: backupID,
                                result: result,
                                completionHandler: completionHandler
                            )
                        }
                        
                        // cancel background task here, because the upload it's a background task too
                        BackgroundTaskManager.shared.cancelBackgroundTask(key: kSafeBackgroundTask)
                    }
                    else {
                        completionHandler()
                    }
                }
                else {
                    throw SafeError.backupFailed(message: "Missing private key")
                }
            }
            else {
                throw SafeStore.SafeError.invalidMasterKey
            }
        }
        catch let SafeError.backupFailed(message) {
            self.logger.logString(message)
            
            self.safeConfigManager
                .setLastResult("\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(message)")

            completionHandler()
        }
        catch {
            logger.logString(error.localizedDescription)
            
            safeConfigManager
                .setLastResult(
                    "\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(error.localizedDescription)"
                )

            completionHandler()
        }
    }
    
    private func handleTestResultSaveConfig(
        key: [UInt8],
        data: [UInt8],
        backupID: [UInt8],
        result: Swift.Result<URL, Error>,
        completionHandler: @escaping () -> Void
    ) {
        do {
            switch result {
            case let .success(safeServerURL):
                let safeServerAuth = safeStore.extractSafeServerAuth(server: safeServerURL)
                let safeBackupURL = safeServerAuth.server
                    .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                
                let result = testServer(serverURL: safeServerURL)
                if let errorMessage = result.errorMessage {
                    throw SafeError.backupFailed(message: errorMessage)
                }
                else {
                    safeConfigManager.setMaxBackupBytes(result.maxBackupBytes)
                    safeConfigManager.setRetentionDays(result.retentionDays)
                }
                
                // encrypt backup data and upload it
                let encryptedData = try safeStore.encryptBackupData(key: key, data: data)
                
                // set actual backup size anyway
                safeConfigManager.setBackupSize(Int64(encryptedData.count))
                
                if encryptedData.count < safeConfigManager.getMaxBackupBytes() ?? 524_288 {
                    
                    safeApiService.upload(
                        backup: safeBackupURL,
                        user: safeServerAuth.user,
                        password: safeServerAuth.password,
                        encryptedData: encryptedData
                    ) { _, errorMessage in
                        if let errorMessage = errorMessage {
                            self.logger.logString(errorMessage)
                            
                            self.safeConfigManager
                                .setLastResult(
                                    errorMessage.contains("Payload Too Large") ? BundleUtil
                                        .localizedString(forKey: "safe_upload_size_exceeded") :
                                        "\(BundleUtil.localizedString(forKey: "safe_upload_failed")) (\(errorMessage))"
                                )
                        }
                        else {
                            self.safeConfigManager.setLastChecksum(self.checksum)
                            self.safeConfigManager.setLastBackup(Date())
                            self.safeConfigManager.setLastResult(BundleUtil.localizedString(forKey: "safe_successful"))
                            self.safeConfigManager.setLastAlertBackupFailed(nil)
                        }
                        
                        completionHandler()
                    }
                }
                else {
                    throw SafeError
                        .backupFailed(message: BundleUtil.localizedString(forKey: "safe_upload_size_exceeded"))
                }
            case let .failure(error):
                throw SafeError.backupFailed(message: "Invalid safe server url \(error)")
            }
        }
        catch {
            logger.logString(error.localizedDescription)
            
            safeConfigManager
                .setLastResult(
                    "\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(error.localizedDescription)"
                )

            completionHandler()
        }
    }
    
    func startRestore(
        identity: String,
        password: String,
        customServer: String?,
        server: String?,
        restoreIdentityOnly: Bool,
        activateSafeAnyway: Bool,
        completionHandler: @escaping (SafeError?) -> Void
    ) {
        
        if let key = safeStore.createKey(identity: identity, password: password),
           let backupID = safeStore.getBackupID(key: key) {
            
            if let server = server,
               !server.isEmpty {
                
                let safeServerURL = URL(string: server)!
                startRestoreFromURL(
                    backupID: backupID,
                    key: key,
                    identity: identity,
                    customServer: customServer,
                    restoreIdentityOnly: restoreIdentityOnly,
                    activateSafeAnyway: activateSafeAnyway,
                    safeServerURL: safeServerURL,
                    completionHandler: completionHandler
                )
            }
            else {
                safeStore.getSafeDefaultServer(key: key) { result in
                    switch result {
                    case let .success(safeServerURL):
                        self.startRestoreFromURL(
                            backupID: backupID,
                            key: key,
                            identity: identity,
                            customServer: customServer,
                            restoreIdentityOnly: restoreIdentityOnly,
                            activateSafeAnyway: activateSafeAnyway,
                            safeServerURL: safeServerURL,
                            completionHandler: completionHandler
                        )
                    case let .failure(error):
                        completionHandler(SafeError.restoreFailed(message: "Cannot get default server: \(error)"))
                    }
                }
            }
        }
        else {
            completionHandler(
                SafeError
                    .restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found"))
            )
        }
    }
    
    private func startRestoreFromURL(
        backupID: [UInt8],
        key: [UInt8],
        identity: String,
        customServer: String?,
        restoreIdentityOnly: Bool,
        activateSafeAnyway: Bool,
        safeServerURL: URL,
        completionHandler: @escaping (SafeError?) -> Void
    ) {
        let safeServerAuth = safeStore.extractSafeServerAuth(server: safeServerURL)
        let backupURL = safeServerAuth.server
            .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
        
        var decryptedData: [UInt8]?
        
        do {
            let safeApiService = SafeApiService()
            let encryptedData = try safeApiService.download(
                backup: backupURL,
                user: safeServerAuth.user,
                password: safeServerAuth.password
            )

            if encryptedData != nil {
                decryptedData = try safeStore.decryptBackupData(key: key, data: Array(encryptedData!))
                
                try safeStore.restoreData(
                    identity: identity,
                    data: decryptedData!,
                    onlyIdentity: restoreIdentityOnly,
                    completionHandler: { error in
                        if let error = error {
                            switch error {
                            case let .restoreError(message):
                                completionHandler(SafeError.restoreError(message: message))
                            case let .restoreFailed(message):
                                completionHandler(SafeError.restoreFailed(message: message))
                            default: break
                            }
                        }
                        else {
                
                            // Reset app migration and start a new run
                            let businessInjector = BusinessInjector()
                            if AppMigration.isMigrationRequired(userSettings: businessInjector.userSettings) {
                                AppMigration(businessInjector: businessInjector, reset: true).run()
                            }
                                                       
                            if !restoreIdentityOnly || activateSafeAnyway {
                                // activate Threema Safe
                                self.activate(
                                    key: key,
                                    customServer: customServer,
                                    server: safeServerURL.absoluteString,
                                    maxBackupBytes: nil,
                                    retentionDays: nil
                                ) { error in
                                    if error != nil {
                                        completionHandler(
                                            SafeError
                                                .restoreError(
                                                    message: BundleUtil
                                                        .localizedString(forKey: "safe_activation_failed")
                                                )
                                        )
                                    }
                                    else {
                                        // trigger backup
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name(kSafeBackupTrigger),
                                            object: nil
                                        )
                                        completionHandler(nil)
                                    }
                                }
                            }
                            else {
                                // show Threema Safe-Intro
                                UserSettings.shared()?.safeIntroShown = false
                                // trigger backup
                                NotificationCenter.default.post(
                                    name: NSNotification.Name(kSafeBackupTrigger),
                                    object: nil
                                )
                                completionHandler(nil)
                            }
                        }
                    }
                )
            }
        }
        catch let SafeApiService.SafeApiError.requestFailed(message) {
            completionHandler(
                SafeError
                    .restoreFailed(
                        message: "\(BundleUtil.localizedString(forKey: "safe_no_backup_found")) (\(message))"
                    )
            )
        }
        catch let SafeStore.SafeError.restoreFailed(message) {
            completionHandler(SafeError.restoreFailed(message: message))
            
            if let decryptedData = decryptedData {
                // Save decrypted backup data into application documents folder, for analyzing failures
                _ = FileUtility.write(
                    fileURL: FileUtility.appDocumentsDirectory?
                        .appendingPathComponent("safe-backup.json"),
                    text: String(bytes: decryptedData, encoding: .utf8)!
                )
            }
        }
        catch {
            completionHandler(
                SafeError
                    .restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found"))
            )
        }
    }
    
    @objc func initTrigger() {
        
        DDLogVerbose("Threema Safe triggered")
        
        if isActivated {
            if SafeManager.backupObserver == nil {
                SafeManager.backupObserver = NotificationCenter.default.addObserver(
                    forName: Notification.Name(kSafeBackupTrigger),
                    object: nil,
                    queue: nil
                ) { notification in
                    if !AppDelegate.shared().isAppInBackground(), self.isActivated {
                        
                        // start background task to give time to create backup file, if the app is going into background
                        BackgroundTaskManager.shared.newBackgroundTask(
                            key: kSafeBackgroundTask,
                            timeout: 60,
                            completionHandler: {
                                if SafeManager.backupDelay != nil {
                                    SafeManager.backupDelay?.invalidate()
                                }
                            
                                // set 5s delay timer to start backup (if delay time 0s, then force backup)
                                var interval = 5
                                if notification.object is Int {
                                    interval = notification.object as! Int
                                }
                                self.backupForce = interval == 0
                            
                                // async is necessary if the call is already within an operation queue (like after setup completion)
                                SafeManager.backupDelay = Timer.scheduledTimer(
                                    timeInterval: TimeInterval(interval),
                                    target: self,
                                    selector: #selector(self.trigger),
                                    userInfo: nil,
                                    repeats: false
                                )
                            }
                        )
                    }
                }
            }
            
            if safeConfigManager.getIsTriggered() || safeStore
                .isDateOlderThenDays(date: safeConfigManager.getLastBackup(), days: 1) {
                NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: nil)
            }
            
            // Show alert once a day, if is last successful backup older than 7 days
            if safeConfigManager.getLastResult() != BundleUtil.localizedString(forKey: "safe_successful"),
               safeConfigManager.getLastBackup() != nil,
               safeStore.isDateOlderThenDays(date: safeConfigManager.getLastBackup(), days: 7) {
                
                DDLogWarn("WARNING Threema Safe backup not successfully since 7 days or more")
                logger.logString("WARNING Threema Safe backup not successfully since 7 days or more")
            
                if safeStore.isDateOlderThenDays(date: safeConfigManager.getLastAlertBackupFailed(), days: 1),
                   let topViewController = AppDelegate.shared()?.currentTopViewController(),
                   let seconds = safeConfigManager.getLastBackup()?.timeIntervalSinceNow,
                   let days = Double(exactly: seconds / 86400)?.rounded(FloatingPointRoundingRule.up) {
                    
                    safeConfigManager.setLastAlertBackupFailed(Date())
                    
                    UIAlertTemplate.showAlert(
                        owner: topViewController,
                        title: BundleUtil.localizedString(forKey: "safe_setup_backup_title"),
                        message: String(
                            format: BundleUtil.localizedString(forKey: "safe_failed_notification"),
                            abs(days)
                        )
                    )
                }
            }
        }
    }
    
    @objc private func trigger() {
        DispatchQueue(label: "backupProcess").async {

            // if forced, try to start backup immediately, otherwise when backup process is already running or last backup not older then a day then just mark as triggered
            SafeManager.backupProcessLock.sync {
                SafeManager.backupProcessStart = false

                if self.backupForce, SafeManager.backupIsRunning {
                    self.safeConfigManager
                        .setLastResult("\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): is already running")
                }
                else if !self.backupForce, SafeManager.backupIsRunning || !self.safeStore.isDateOlderThenDays(
                    date: self.safeConfigManager.getLastBackup(),
                    days: 1
                ) {
                    
                    self.safeConfigManager.setIsTriggered(true)
                    self.logger.logString("Safe backup just triggered")
                }
                else {
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
            }
            else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: kSafeBackgroundTask)
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupUIRefresh), object: nil)
            }
        }
    }
}
