import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaEssentials
import ThreemaMacros

final class SafeBackupDataDownloader {
    
    // MARK: - Public functions
    
    func getSafeBackupData(
        identity: String,
        safePassword: String,
        serverUser: String?,
        serverPassword: String?,
        server: String?
    ) async throws -> SafeJsonParser.SafeBackupData {
        
        let encodedData: [UInt8]? = try await withCheckedThrowingContinuation { continuation in
            guard let key = SafeStore.createKey(identity: identity, safePassword: safePassword),
                  let backupID = SafeStore.getBackupID(key: key) else {
                DDLogError("[ThreemaSafe Restore] No backup found")
                continuation.resume(throwing: SafeError.restoreError(.noBackupFound))
                return
            }
            
            // Custom server
            if let server, !server.isEmpty {
                guard let url = URL(string: server) else {
                    DDLogError("[ThreemaSafe Restore] Invalid url")
                    continuation.resume(throwing: SafeError.invalidURL)
                    return
                }
                
                fetchBackupData(
                    backupID: backupID,
                    key: key,
                    serverUser: serverUser,
                    serverPassword: serverPassword,
                    server: url
                ) { error, data in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: data)
                }
            }
            // Default server
            else {
                SafeStore.getSafeDefaultServer(key: key) { result in
                    switch result {
                    case let .success(safeServer):
                        self.fetchBackupData(
                            backupID: backupID,
                            key: key,
                            serverUser: serverUser,
                            serverPassword: serverPassword,
                            server: safeServer.server,
                        ) { error, data in
                            if let error {
                                continuation.resume(throwing: error)
                                return
                            }
                            continuation.resume(returning: data)
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        guard let encodedData else {
            DDLogError("[ThreemaSafe Restore] Response missing data")
            throw SafeError.restoreError(.invalidResponse)
        }
        
        // Decode and return the fetched safe data
        return try decode(encodedData: encodedData)
    }

    // MARK: - Private functions

    private func decode(encodedData: [UInt8]) throws -> SafeJsonParser.SafeBackupData {
        do {
            DDLogNotice("[ThreemaSafe Restore] Decoding of backup data")
            let parser = SafeJsonParser()
            removeCleanedData()
            
            let decoded = try parser.getSafeBackupData(from: Data(encodedData))
            // We remove possible previous data if decoding was successful
            removeCleanedData()
            
            return decoded
        }
        catch let error as DecodingError {
            // Log more informations about the parser error
            switch error {
            case let .typeMismatch(_, value):
                DDLogError(
                    "[ThreemaSafe Restore] Decoding backup failed with error: TypeMismatch: \(value.debugDescription), \(self.allKeys(from: value.codingPath))"
                )

            case let .valueNotFound(_, value):
                DDLogError(
                    "[ThreemaSafe Restore] Decoding backup failed with error: ValueNotFound: \(value.debugDescription), \(self.allKeys(from: value.codingPath))"
                )

            case let .keyNotFound(_, value):
                DDLogError(
                    "[ThreemaSafe Restore] Decoding backup failed with error: ValueNotFound: \(value.debugDescription), \(self.allKeys(from: value.codingPath))"
                )

            case let .dataCorrupted(context):
                DDLogError(
                    "[ThreemaSafe Restore] Decoding backup failed with error: (DataCorrupted: \(context.debugDescription), \(context.codingPath)"
                )

            default:
                DDLogError(
                    "[ThreemaSafe Restore] Decoding backup failed with error: ValueNotFound: \(error.localizedDescription))"
                )
            }
            
            cleanAndSaveData(encodedData)
            throw SafeError.restoreError(.decodingFailed)
        }
        catch {
            cleanAndSaveData(encodedData)
            throw SafeError.restoreError(.decodingFailed)
        }
    }
    
    private func fetchBackupData(
        backupID: [UInt8],
        key: [UInt8],
        serverUser: String?,
        serverPassword: String?,
        server: URL,
        completionHandler: @escaping (Error?, [UInt8]?) -> Void
    ) {
        DDLogNotice("[ThreemaSafe Restore] Fetching backup")
        
        let backupURL = server.appendingPathComponent("backups/\(BytesUtility.toHexString(bytes: backupID))")
        var decryptedData: [UInt8]?
        
        let safeApiService = SafeApiService()
        safeApiService.download(
            backup: backupURL,
            user: serverUser,
            password: serverPassword
        ) { completion in
            do {
                if let encryptedData = try completion() {
                    decryptedData = try SafeStore.decryptBackupData(key: key, data: Array(encryptedData))
                    completionHandler(nil, decryptedData)
                }
                else {
                    completionHandler(nil, nil)
                }
            }
            catch {
                if let err = error as? SafeApiService.SafeApiError {
                    switch err {
                    case .invalidServerURL:
                        completionHandler(SafeError.invalidURL, nil)
                    case .requestFailed:
                        completionHandler(SafeError.restoreError(.noBackupFound), nil)
                    }
                }
                else {
                    completionHandler(error, nil)
                }
            }
        }
    }
    
    private func cleanAndSaveData(_ decryptedData: [UInt8]) {
        DDLogNotice("[ThreemaSafe Restore] Cleaning and saving decrypted data")

        guard let json = try? JSONSerialization.jsonObject(
            with: Data(decryptedData),
            options: .mutableContainers
        ),
            var json = json as? [String: Any],
            var user = json["user"] as? [String: Any] else {
            return
        }
        // Remove sensitive data
        if user.removeValue(forKey: "privatekey") != nil {
            json["user"] = user
            
            guard let dataWithoutPrimaryKey = try? JSONSerialization.data(withJSONObject: json),
                  let dataWithoutPrimaryKeyString = String(bytes: dataWithoutPrimaryKey, encoding: .utf8)
            else {
                return
            }
            
            // Save decrypted backup data into application documents folder, for analyzing failures
            FileUtility.shared.write(
                contents: Data(dataWithoutPrimaryKeyString.utf8),
                to: FileUtility.shared.appDocumentsDirectory?
                    .appendingPathComponent("safe-backup.json")
            )
        }
    }
    
    private func removeCleanedData() {
        DDLogNotice("[ThreemaSafe Restore] Removing cleaned data if existing")
        if let url = FileUtility.shared.appDocumentsDirectory?
            .appendingPathComponent("safe-backup.json") {
            try? FileUtility.shared.delete(at: url)
        }
    }
    
    private func allKeys(from codingKeys: [CodingKey]) -> [String] {
        codingKeys.map(\.stringValue)
    }
}
