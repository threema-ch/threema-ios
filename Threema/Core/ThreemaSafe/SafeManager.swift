//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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
    private let userSettings: UserSettingsProtocol
    private var logger: ValidationLogger

    // Trigger safe backup states
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
        
        public var errorDescription: String? {
            switch self {
            case let .activateFailed(message),
                 let .backupFailed(message: message),
                 let .restoreError(message: message),
                 let .restoreFailed(message: message):
                return localizedDescription + " [\(message)]"
            }
        }
    }
    
    init(
        safeConfigManager: SafeConfigManagerProtocol,
        safeStore: SafeStore,
        safeApiService: SafeApiService,
        userSettings: UserSettingsProtocol = UserSettings.shared()
    ) {
        self.safeConfigManager = safeConfigManager
        self.safeStore = safeStore
        self.safeApiService = safeApiService
        self.userSettings = userSettings
        self.logger = ValidationLogger.shared()
    }
    
    convenience init(groupManager: GroupManagerProtocol) {
        let safeConfigManager = SafeConfigManager()
        let serverAPIConnector = ServerAPIConnector()
        let safeAPIService = SafeApiService()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: groupManager
        )
        self.init(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: safeAPIService)
    }
    
    @objc convenience init(groupManager: GroupManager) {
        let safeConfigManager = SafeConfigManager()
        let serverAPIConnector = ServerAPIConnector()
        let safeAPIService = SafeApiService()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: serverAPIConnector,
            groupManager: groupManager
        )
        self.init(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: safeAPIService)
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
    
    // Activate safe with password of MDM
    @objc func activateThroughMDM() {
        guard let mdm = MDMSetup(setup: false),
              let safePassword = mdm.safePassword() else {
            return
        }

        var customServer: String?
        var serverUser: String?
        var serverPassword: String?
        var server: String?

        if mdm.isSafeBackupServerPreset() {
            customServer = mdm.safeServerURL()
            serverUser = mdm.safeServerUsername()
            serverPassword = mdm.safeServerPassword()
            server = customServer
        }
        
        activate(
            identity: MyIdentityStore.shared().identity,
            safePassword: safePassword,
            customServer: customServer,
            serverUser: serverUser,
            serverPassword: serverPassword,
            server: server,
            maxBackupBytes: nil,
            retentionDays: nil
        ) { error in
            if let error = error as? NSError {
                if error.code == ThreemaProtocolError.safePasswordEmpty.rawValue {
                    Task { @MainActor in
                        LaunchModalManager.shared.checkLaunchModals()
                    }
                }
                DDLogError("Failed to activate Threema Safe: \(error)")
            }
        }
    }
    
    @objc func activate(
        identity: String,
        safePassword: String?,
        customServer: String?,
        serverUser: String?,
        serverPassword: String?,
        server: String?,
        maxBackupBytes: NSNumber?,
        retentionDays: NSNumber?,
        completion: @escaping (Error?) -> Void
    ) {
        guard let key = safeStore.createKey(identity: identity, safePassword: safePassword) else {
            completion(ThreemaProtocolError.safePasswordEmpty)
            return
        }
        
        activate(
            key: key,
            customServer: customServer,
            serverUser: serverUser,
            serverPassword: serverPassword,
            server: server,
            maxBackupBytes: maxBackupBytes?.intValue,
            retentionDays: retentionDays?.intValue,
            completion: completion
        )
    }
    
    func credentialsChanged() -> Bool {
        guard let mdm = MDMSetup(setup: false) else {
            return false
        }
        
        let current = safeConfigManager.getKey()
        let poss = safeStore.createKey(identity: MyIdentityStore.shared().identity, safePassword: mdm.safePassword())
        return current != poss
    }
    
    func isSafePasswordDefinedByAdmin() -> Bool {
        guard let mdm = MDMSetup(setup: false), mdm.safePassword() != nil else {
            return false
        }
        let current = safeConfigManager.getKey()
        let poss = safeStore.createKey(identity: MyIdentityStore.shared().identity, safePassword: mdm.safePassword())
        return current == poss
    }
    
    private func activate(
        key: [UInt8],
        customServer: String?,
        serverUser: String?,
        serverPassword: String?,
        server: String?,
        maxBackupBytes: Int?,
        retentionDays: Int?,
        completion: @escaping (Error?) -> Void
    ) {
        if let customServer,
           let serverUser,
           let serverPassword {

            safeConfigManager.setKey(key)
            safeConfigManager.setCustomServer(customServer)
            safeConfigManager.setServerUser(serverUser)
            safeConfigManager.setServerPassword(serverPassword)
            safeConfigManager.setServer(customServer)
            safeConfigManager.setMaxBackupBytes(maxBackupBytes)
            safeConfigManager.setRetentionDays(retentionDays)

            initTrigger()

            // Show Threema Safe intro next time if is deactivated
            userSettings.safeIntroShown = false

            completion(nil)
        }
        else {
            safeStore.getSafeDefaultServer(key: key) { result in
                switch result {
                case let .success(safeServer):
                    self.testServer(
                        serverURL: safeServer.server,
                        user: safeServer.serverUser,
                        password: safeServer.serverPassword
                    ) { errorMessage, maxBackupBytes, retentionDays in
                        if let errorMessage {
                            completion(SafeError.activateFailed(message: "Test default server: \(errorMessage)"))
                        }
                        else {
                            self.safeConfigManager.setKey(key)
                            self.safeConfigManager.setCustomServer(nil)
                            self.safeConfigManager.setServerUser(nil)
                            self.safeConfigManager.setServerPassword(nil)
                            self.safeConfigManager.setServer(safeServer.server.absoluteString)
                            self.safeConfigManager.setMaxBackupBytes(maxBackupBytes)
                            self.safeConfigManager.setRetentionDays(retentionDays)

                            self.initTrigger()

                            // Show Threema Safe intro next time if is deactivated
                            self.userSettings.safeIntroShown = false

                            completion(nil)
                        }
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
                    let safeBackupURL = safeServer.server
                        .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                    self.safeApiService.delete(
                        server: safeBackupURL,
                        user: safeServer.serverUser,
                        password: safeServer.serverPassword,
                        completion: { errorMessage in
                            if let errorMessage {
                                self.logger.logString("Safe backup could not be deleted: \(errorMessage)")
                            }
                        }
                    )
                case .failure: break
                }
            }
        }
        
        safeConfigManager.setKey(nil)
        safeConfigManager.setCustomServer(nil)
        safeConfigManager.setServerUser(nil)
        safeConfigManager.setServerPassword(nil)
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

        let delimiter = Data(String(stringLiteral: "\n").utf8)
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
                    notification.body = String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "safe_failed_notification"),
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
                if let error {
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
    
    /// Tests a given server URL for Threema Safe
    /// - Parameters:
    ///   - serverURL: Server URL to test
    ///   - user: User name for basic authentication
    ///   - password: Password for basic authentication
    ///   - completion: Closure that accepts (errorMessage: String?, maxBackupDays: Int?, retentionDays: Int?)
    func testServer(
        serverURL: URL,
        user: String?,
        password: String?,
        completion: @escaping (String?, Int?, Int?) -> Void
    ) {
        safeApiService.testServer(
            server: serverURL,
            user: user,
            password: password
        ) { comp in
            do {
                let serverConfig = try comp()
                let parser = SafeJsonParser()
                guard let config = parser.getSafeServerConfig(from: serverConfig) else {
                            
                    completion("Invalid response data", nil, nil)
                    return
                }
                    
                completion(nil, config.maxBackupBytes, config.retentionDays)
            }
            catch {
                completion("Invalid response data: \(error)", nil, nil)
            }
        }
    }
    
    /// Apply Threema Safe server it has changed
    @objc func applyServer(server: String?, user: String?, password: String?) {
        if isActivated {
            let doApply: (String?, String?, URL) -> Void = { user, password, serverURL in
                if let server {
                    if self.safeConfigManager.getServer() != server {
                        // Save Threema Safe server config and reset result and control config
                        self.safeConfigManager.setCustomServer(server)
                        self.safeConfigManager.setServerUser(user)
                        self.safeConfigManager.setServerPassword(password)
                        self.safeConfigManager.setServer(serverURL.absoluteString)
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

            if let server, let serverURL = URL(string: server) {
                doApply(user, password, serverURL)
            }
            else {
                safeStore.getSafeDefaultServer(key: safeConfigManager.getKey()!) { result in
                    switch result {
                    case let .success(safeServer):
                        doApply(safeServer.serverUser, safeServer.serverPassword, safeServer.server)
                    case let .failure(error):
                        self.logger.logString("Cannot obtain default server: \(error)")
                    }
                }
            }
        }
    }

    func startBackupForDeviceLinking(password: String) async throws {

        guard !isPasswordBad(password: password) else {
            throw SafeError.backupFailed(message: "This password is bad, please try another")
        }

        guard let key = safeStore.createKey(identity: MyIdentityStore.shared().identity, safePassword: password) else {
            throw SafeError.backupFailed(message: "Missing backup key")
        }

        guard let backupID = safeStore.getBackupID(key: key) else {
            throw SafeError.backupFailed(message: "Missing backup ID")
        }

        guard let data = safeStore.backupData(backupDeviceGroupKey: true) else {
            throw SafeError.backupFailed(message: "Missing backup data")
        }

        return try await withCheckedThrowingContinuation { continuation in
            safeStore.getSafeServer(key: key) { result in
                switch result {
                case let .success(safeServer):
                    let safeBackupURL = safeServer.server
                        .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                    self.testServer(
                        serverURL: safeServer.server,
                        user: safeServer.serverUser,
                        password: safeServer.serverPassword
                    ) { errorMessage, maxBackupBytes, _ in

                        if let error = errorMessage {
                            continuation.resume(throwing: SafeError.backupFailed(message: error))
                        }

                        // Encrypt backup data and upload it
                        do {
                            let encryptedData = try self.safeStore.encryptBackupData(key: key, data: data)
                            guard encryptedData.count < maxBackupBytes ?? 524_288 else {
                                continuation.resume(
                                    throwing: SafeError
                                        .backupFailed(
                                            message: BundleUtil
                                                .localizedString(forKey: "safe_upload_size_exceeded")
                                        )
                                )
                                return
                            }

                            self.safeApiService.upload(
                                backup: safeBackupURL,
                                user: safeServer.serverUser,
                                password: safeServer.serverPassword,
                                encryptedData: encryptedData
                            ) { _, error in
                                if let error {
                                    continuation.resume(throwing: SafeError.backupFailed(
                                        message: error.contains("Payload Too Large") ? BundleUtil
                                            .localizedString(forKey: "safe_upload_size_exceeded") :
                                            "\(BundleUtil.localizedString(forKey: "safe_upload_failed")) (\(error))"
                                    ))
                                }
                                else {
                                    continuation.resume()
                                }
                            }
                        }
                        catch {
                            continuation
                                .resume(throwing: SafeError.backupFailed(message: "Encryption of backup failed."))
                        }
                    }

                case let .failure(error):
                    continuation.resume(throwing: SafeError.backupFailed(message: "Invalid safe server url \(error)"))
                }
            }
        }
    }

    func deleteBackupForDeviceLinking(password: String) {
        if let key = safeStore.createKey(identity: MyIdentityStore.shared().identity, safePassword: password),
           let backupID = safeStore.getBackupID(key: key) {

            safeStore.getSafeServer(key: key) { result in
                switch result {
                case let .success(safeServer):
                    let safeBackupURL = safeServer.server
                        .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                    self.safeApiService.delete(
                        server: safeBackupURL,
                        user: safeServer.serverUser,
                        password: safeServer.serverPassword,
                        completion: { errorMessage in
                            if let errorMessage {
                                self.logger.logString("Safe backup could not be deleted: \(errorMessage)")
                            }
                        }
                    )
                case .failure: break
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
        result: Swift.Result<(serverUser: String?, serverPassword: String?, server: URL), Error>,
        completionHandler: @escaping () -> Void
    ) {
        do {
            switch result {
            case let .success(safeServer):
                let safeBackupURL = safeServer.server
                    .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
                
                testServer(
                    serverURL: safeServer.server,
                    user: safeServer.serverUser,
                    password: safeServer.serverPassword
                ) { errorMessage, maxBackupBytes, retentionDays in
                    do {
                        if let errorMessage {
                            throw SafeError.backupFailed(message: errorMessage)
                        }
                        else {
                            self.safeConfigManager.setMaxBackupBytes(maxBackupBytes)
                            self.safeConfigManager.setRetentionDays(retentionDays)
                        }
                        
                        // encrypt backup data and upload it
                        let encryptedData = try self.safeStore.encryptBackupData(key: key, data: data)
                        
                        // set actual backup size anyway
                        self.safeConfigManager.setBackupSize(Int64(encryptedData.count))
                        
                        if encryptedData.count < self.safeConfigManager.getMaxBackupBytes() ?? 524_288 {
                            
                            self.safeApiService.upload(
                                backup: safeBackupURL,
                                user: safeServer.serverUser,
                                password: safeServer.serverPassword,
                                encryptedData: encryptedData
                            ) { _, errorMessage in
                                if let errorMessage {
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
                                    self.safeConfigManager
                                        .setLastResult(BundleUtil.localizedString(forKey: "safe_successful"))
                                    self.safeConfigManager.setLastAlertBackupFailed(nil)
                                }
                                
                                completionHandler()
                            }
                        }
                        else {
                            throw SafeError
                                .backupFailed(message: BundleUtil.localizedString(forKey: "safe_upload_size_exceeded"))
                        }
                    }
                    catch {
                        if let safeError = error as? SafeError {
                            self.logger.logString(safeError.errorDescription)
                        }
                        else {
                            self.logger.logString(error.localizedDescription)
                        }
                        
                        self.safeConfigManager
                            .setLastResult(
                                "\(BundleUtil.localizedString(forKey: "safe_unsuccessful")): \(error.localizedDescription)"
                            )

                        completionHandler()
                    }
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
        safePassword: String,
        customServer: String?,
        serverUser: String?,
        serverPassword: String?,
        server: String?,
        restoreIdentityOnly: Bool,
        activateSafeAnyway: Bool,
        completionHandler: @escaping (SafeError?) -> Void
    ) {
        
        if let key = safeStore.createKey(identity: identity, safePassword: safePassword),
           let backupID = safeStore.getBackupID(key: key) {
            
            if let server,
               !server.isEmpty {

                startRestoreFromURL(
                    backupID: backupID,
                    key: key,
                    identity: identity,
                    customServer: customServer,
                    serverUser: serverUser,
                    serverPassword: serverPassword,
                    server: URL(string: server)!,
                    restoreIdentityOnly: restoreIdentityOnly,
                    activateSafeAnyway: activateSafeAnyway,
                    completionHandler: completionHandler
                )
            }
            else {
                safeStore.getSafeDefaultServer(key: key) { result in
                    switch result {
                    case let .success(safeServer):
                        self.startRestoreFromURL(
                            backupID: backupID,
                            key: key,
                            identity: identity,
                            customServer: customServer,
                            serverUser: serverUser,
                            serverPassword: serverPassword,
                            server: safeServer.server,
                            restoreIdentityOnly: restoreIdentityOnly,
                            activateSafeAnyway: activateSafeAnyway,
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
        serverUser: String?,
        serverPassword: String?,
        server: URL,
        restoreIdentityOnly: Bool,
        activateSafeAnyway: Bool,
        completionHandler: @escaping (SafeError?) -> Void
    ) {
        let backupURL = server
            .appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
        
        var decryptedData: [UInt8]?
        
        let safeApiService = SafeApiService()
        safeApiService.download(
            backup: backupURL,
            user: serverUser,
            password: serverPassword,
            completionHandler: { comp in
                do {
                    let encryptedData = try comp()
                    
                    if encryptedData != nil {
                        decryptedData = try self.safeStore.decryptBackupData(key: key, data: Array(encryptedData!))
                        
                        try? self.safeStore.restoreData(
                            identity: identity,
                            data: decryptedData!,
                            onlyIdentity: restoreIdentityOnly,
                            completionHandler: { error in
                                if let error {
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
                                    if AppMigrationVersion
                                        .isMigrationRequired(userSettings: businessInjector.userSettings) {
                                        do {
                                            try AppMigration(reset: true).run()
                                        }
                                        catch {
                                            let msg = BundleUtil
                                                .localizedString(
                                                    forKey: "safe_activation_app_migration_failed_error_message"
                                                )
                                            completionHandler(SafeError.restoreError(message: msg))
                                            return
                                        }
                                    }
                                    
                                    if !restoreIdentityOnly || activateSafeAnyway {
                                        // activate Threema Safe
                                        self.activate(
                                            key: key,
                                            customServer: customServer,
                                            serverUser: serverUser,
                                            serverPassword: serverPassword,
                                            server: server.absoluteString,
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
                    
                    if let decryptedData {
                        // Save decrypted backup data into application documents folder, for analyzing failures
                        _ = FileUtility.shared.write(
                            fileURL: FileUtility.shared.appDocumentsDirectory?
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
        )
    }
    
    @objc func initTrigger() {
                
        guard isActivated else {
            return
        }
        
        DDLogVerbose("Threema Safe triggered")
        
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
                            
                            // async is necessary if the call is already within an operation queue (like after setup
                            // completion)
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
                    message: String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "safe_failed_notification"),
                        abs(days)
                    )
                )
            }
        }
    }
    
    @objc private func trigger() {
        let businessInjector = BusinessInjector()
        if businessInjector.userSettings.blockCommunication {
            DDLogWarn("Communication is blocked")
            return
        }

        DispatchQueue(label: "backupProcess").async {

            // if forced, try to start backup immediately, otherwise when backup process is already running or last
            // backup not older then a day then just mark as triggered
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
    
    /// Checks Threema Safe configuration for Threema Work and OnPrem
    @objc func performThreemaSafeLaunchChecks() {
        guard LicenseStore.shared().getRequiresLicenseKey(),
              let mdm = MDMSetup(setup: false) else {
            return
        }
        // We abort if we are currently creating a backup, e.g. from app setup
        if safeConfigManager.getIsTriggered() {
            return
        }
        // Check if Threema Safe is forced and not activated yet
        if !isActivated, mdm.isSafeBackupForce() {
            activateThroughMDM()
        }
        // Else if Threema Safe is disabled by MDM and Safe is activated, deactivate Safe
        else if isActivated, mdm.isSafeBackupDisable() {
            deactivate()
        }
        // Else if Safe activated, check if server has been changed by MDM
        else if isActivated {
            safeStore.isSafeServerChanged(mdmSetup: mdm) { changed in
                guard changed else {
                    return
                }
                self.deactivate()
                self.activateThroughMDM()
            }
        }
    }
}
