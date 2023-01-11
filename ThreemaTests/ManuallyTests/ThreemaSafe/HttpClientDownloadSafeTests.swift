//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import ThreemaFramework
import XCTest

@testable import Threema

class HttpClientDownloadSafeTests: XCTestCase {
    var receivedData: Data?

    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSafeHttpClientDownloadWithCompletionHandler() {
        let store = SafeStore(
            safeConfigManager: SafeConfigManager(),
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"),
           let backupID = store.getBackupID(key: key) {
            store.getSafeDefaultServer(key: key) { result in
                switch result {
                case let .success(safeServer):
                    let backupURL = URL(string: "\(safeServer)/backups/\(BytesUtility.toHexString(bytes: backupID))")
                    let client = HTTPClient()
                    client.downloadData(url: backupURL!, contentType: .octetStream) { data, response, error in
                        if let error = error {
                            print("http client download error: \(error)")
                            XCTAssert(false)
                            return
                        }
                        guard let response = response as? HTTPURLResponse,
                              (200...299).contains(response.statusCode) else {
                            print("http client download wrong state")
                            if let data = data {
                                print("http client download failed: \(String(data: data, encoding: .utf8)!)")
                            }
                            XCTAssert(false)
                            return
                        }
                        
                        if let encryptedData = data {
                            let decryptedData = try! store.decryptBackupData(key: key, data: Array(encryptedData))
                            
                            let parser = SafeJsonParser()
                            let safeBackupData = try! parser.getSafeBackupData(from: Data(decryptedData))
                            XCTAssertEqual(1, safeBackupData.info.version)
                        }
                        else {
                            XCTAssert(false)
                        }
                    }
                case let .failure(error):
                    XCTFail("\(error)")
                }
            }
        }
    }

    func testSafeHttpClientDownloadWithDelegate() {
        receivedData = Data()
        
        let store = SafeStore(
            safeConfigManager: SafeConfigManager(),
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"),
           let backupID = store.getBackupID(key: key) {
            let backupURL = URL(string: "https://safe.threema.ch/backups/\(BytesUtility.toHexString(bytes: backupID))")
            let client = HTTPClient()
            client.downloadData(url: backupURL!, delegate: self)
        }
    }
}

// MARK: - URLSessionDataDelegate

extension HttpClientDownloadSafeTests: URLSessionDataDelegate {
    
    // delegate methods
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode),
              let mimeType = response.mimeType,
              mimeType == "application/octet-stream" else {
            completionHandler(.cancel)
            return
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("http client download error \(error)")
                XCTAssert(false)
            }
            else if let receivedData = self.receivedData {
                let store = SafeStore(
                    safeConfigManager: SafeConfigManager(),
                    serverApiConnector: ServerAPIConnector(),
                    groupManager: GroupManager()
                )
                if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar") {
                    
                    let decryptedData = try! store.decryptBackupData(key: key, data: Array(receivedData))

                    let parser = SafeJsonParser()
                    let safeBackupData = try! parser.getSafeBackupData(from: Data(decryptedData))
                    XCTAssertEqual(1, safeBackupData.info.version)
                }
            }
        }
    }
}

// MARK: - URLSessionDelegate

extension HttpClientDownloadSafeTests: URLSessionDelegate {
    
    // call standard background session handler
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("session for download finished")
    }
}
