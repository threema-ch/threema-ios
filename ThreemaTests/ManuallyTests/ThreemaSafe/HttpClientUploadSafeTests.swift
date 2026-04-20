import RemoteSecretProtocolTestHelper
import ThreemaEssentials

import ThreemaFramework
import XCTest

@testable import Threema
@testable import ThreemaFramework

final class HttpClientUploadSafeTests: XCTestCase {
    var receivedData: Data?

    override func setUp() {
        super.setUp()

        AppGroup.setGroupID("group.ch.threema")
        
        // Workaround to ensure remote secret is initialized
        let remoteSecretManagerMock = RemoteSecretManagerMock()
        AppLaunchManager.shared.setRemoteSecretManager(remoteSecretManagerMock)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSafeHttpClientUploadWithCompletionHandler() {
        let myIdentityStoreMock = MyIdentityStoreMock(identity: "ECHOECHO", secretKey: BytesUtility.generatePublicKey())
        let store = SafeStore(
            safeConfigManager: SafeConfigManager(),
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManagerMock(),
            myIdentityStore: myIdentityStoreMock
        )
                
        if let key = SafeStore.createKey(identity: "ECHOECHO", safePassword: "shootdeathstar"),
           let backupID = SafeStore.getBackupID(key: key) {
            if let data = store.backupData() {
                let encryptedData = try! store.encryptBackupData(key: key, data: data)
                
                let backupURL =
                    URL(string: "https://safe.threema.ch/backups/\(BytesUtility.toHexString(bytes: backupID))")
                let client = HTTPClient()
                client.uploadData(url: backupURL!, data: Data(encryptedData)) { data, response, error in
                    if let error {
                        print("http client upload error: \(error)")
                        XCTAssert(false)
                        return
                    }
                    guard let response = response as? HTTPURLResponse,
                          (200...299).contains(response.statusCode) else {
                        print("http client download wrong state")
                        if let data {
                            print("http client upload failed: \(String(data: data, encoding: .utf8)!)")
                        }
                        XCTAssert(false)
                        return
                    }
                }
            }
            else {
                print("missing private key")
                XCTAssert(false)
                return
            }
        }
    }

    func testHttpSafeClientUploadWithDelegate() {
        receivedData = Data()
        let myIdentityStoreMock = MyIdentityStoreMock()

        let store = SafeStore(
            safeConfigManager: SafeConfigManager(),
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManagerMock(),
            myIdentityStore: myIdentityStoreMock
        )
        
        if let key = SafeStore.createKey(identity: "ECHOECHO", safePassword: "shootdeathstar"),
           let backupID = SafeStore.getBackupID(key: key) {
            if let data = store.backupData() {
                let encryptedData = try! store.encryptBackupData(key: key, data: data)
                
                // save into local documents storage
                let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let backupFile = documents + "/backup-safe"
                let backupFileURL = URL(fileURLWithPath: documents + "/backup-safe")
                
                let fileManager = FileManager.default
                print(backupFileURL.absoluteString)
                if fileManager.fileExists(atPath: backupFile) {
                    do {
                        let attr = try FileManager.default.attributesOfItem(atPath: backupFile)
                        let fileSize = attr[FileAttributeKey.size] as! UInt64
                        print("safe backup size \(fileSize)")
                        
                        try fileManager.removeItem(atPath: backupFile)
                    }
                    catch let error as NSError {
                        print("deletion of safe backup file failed: \(error)")
                    }
                }
                
                fileManager.createFile(atPath: backupFile, contents: Data(encryptedData), attributes: nil)
                
                let backupURL =
                    URL(string: "https://safe.threema.ch/backups/\(BytesUtility.toHexString(bytes: backupID))")
                let client = HTTPClient()
                client.uploadData(url: backupURL!, file: backupFileURL, delegate: self)
            }
            else {
                print("backup failed: missing private key")
                XCTAssert(false)
            }
        }
    }
}

// MARK: - URLSessionDataDelegate

extension HttpClientUploadSafeTests: URLSessionDataDelegate {
    
    // delegate methods
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        print("bytes: expected \(totalBytesExpectedToSend) / sent \(bytesSent) / total \(totalBytesSent)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error {
                print("http client upload error \(error)")
                XCTAssert(false)
            }
            else if let receivedData = self.receivedData,
                    let receivedDataString = String(bytes: receivedData, encoding: .utf8) {
                print("http client upload failed \(receivedDataString)")
                XCTAssert(false)
            }
        }
    }
}

// MARK: - URLSessionDelegate

extension HttpClientUploadSafeTests: URLSessionDelegate {
    
    // call standard background session handler
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("session for download finished")
    }
}
