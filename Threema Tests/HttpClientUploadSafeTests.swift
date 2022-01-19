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

import XCTest
import ThreemaFramework

@testable import Threema

class HttpClientUploadSafeTests: XCTestCase {
    var receivedData: Data?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSafeHttpClientUploadWithCompletionHandler() {
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"), let backupId = store.getBackupId(key: key) {
            if let data = store.backupData() {
                let encryptedData = try! store.encryptBackupData(key: key, data: data)
                
                let backupUrl = URL(string: "https://safe.threema.ch/backups/\(hexString(data: backupId))")
                let client = HttpClient()
                client.uploadData(url: backupUrl!, data: Data(encryptedData)) { (data, response, error) in
                    if let error = error {
                        print ("http client upload error: \(error)")
                        XCTAssert(false)
                        return
                    }
                    guard let response = response as? HTTPURLResponse,
                        (200...299).contains(response.statusCode) else {
                            print ("http client download wrong state")
                            if let data = data {
                                print("http client upload failed: \(String(data: data, encoding: .utf8)!)")
                            }
                            XCTAssert(false)
                            return
                    }
                }
            } else {
                print ("missing private key")
                XCTAssert(false)
                return
            }
        }
    }

    func testHttpSafeClientUploadWithDelegate() {
        self.receivedData = Data()
        
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"), let backupId = store.getBackupId(key: key) {
            if let data = store.backupData() {
                let encryptedData = try! store.encryptBackupData(key: key, data: data)
                
                //save into local documents storage
                let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let backupFile = documents + "/backup-safe"
                let backupFileUrl = URL(fileURLWithPath: documents + "/backup-safe")
                
                let fileManager = FileManager.default
                print(backupFileUrl.absoluteString)
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
                
                let backupUrl = URL(string: "https://safe.threema.ch/backups/\(hexString(data: backupId))")
                let client = HttpClient()
                client.uploadData(url: backupUrl!, file: backupFileUrl, delegate: self)
            } else {
                print ("backup failed: missing private key")
            }
        }
    }
    
    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    */
    
    private func hexString(data: [UInt8]) -> String {
        return data.map { String(format: "%02hhx", $0) }.joined(separator: "")
    }
}

extension HttpClientUploadSafeTests : URLSessionDataDelegate {
    
    // delegate methods
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print("bytes: expected \(totalBytesExpectedToSend) / sent \(bytesSent) / total \(totalBytesSent)")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("http client upload error \(error)")
                XCTAssert(false)
            } else if let receivedData = self.receivedData,
                let receivedDataString = String(bytes: receivedData, encoding: .utf8) {
                print("http client upload failed \(receivedDataString)")
                XCTAssert(false)
            }
        }
    }
}

extension HttpClientUploadSafeTests: URLSessionDelegate {
    
    // call standard background session handler
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("session for download finished")
    }
}
