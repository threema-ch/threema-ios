//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class HttpClientDownloadSafeTests: XCTestCase {
    var receivedData: Data?

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSafeHttpClientDownloadWithCompletionHandler() {
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"), let backupId = store.getBackupId(key: key) {
            let safeServer = store.getSafeDefaultServer(key: key)!
            let backupUrl = URL(string: "\(safeServer)/backups/\(hexString(data: backupId))")
            let client = HttpClient()
            client.downloadData(url: backupUrl!, contentType: .octetStream) { (data, response, error) in
                if let error = error {
                    print ("http client download error: \(error)")
                    XCTAssert(false)
                    return
                }
                guard let response = response as? HTTPURLResponse,
                    (200...299).contains(response.statusCode) else {
                        print ("http client download wrong state")
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
        }
    }

    func testSafeHttpClientDownloadWithDelegate() {
        self.receivedData = Data()
        
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
        if let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar"), let backupId = store.getBackupId(key: key) {
            let backupUrl = URL(string: "https://safe.threema.ch/backups/\(hexString(data: backupId))")
            let client = HttpClient()
            client.downloadData(url: backupUrl!, delegate: self)
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

extension HttpClientDownloadSafeTests : URLSessionDataDelegate {
    
    // delegate methods
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
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
        self.receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("http client download error \(error)")
                XCTAssert(false)
            } else if let receivedData = self.receivedData {
                 let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
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

extension HttpClientDownloadSafeTests: URLSessionDelegate {
    
    // call standard background session handler
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("session for download finished")
    }
}
