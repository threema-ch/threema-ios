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
//import ThreemaFramework

@testable import Threema

class SafeTests: XCTestCase {
    override func setUp() {
        super.setUp()

        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSafeSha1() {
        let safeStore = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())

        let sha1a = safeStore.sha1(data: Data([1]))
        let sha1b = safeStore.sha1(data: Data([1]))

        XCTAssertTrue(sha1a == sha1b)
    }

    func testSafeJsonParserCreate() -> Void {
        let parser = SafeJsonParser()
        let safeBackupData = parser.getSafeBackupData()
        let json = parser.getJsonAsString(from: safeBackupData)

        XCTAssertNotNil(json)
        XCTAssertEqual(json, "{\"info\":{\"version\":1,\"device\":\"ios\"}}")
    }

    func testSafeJsonParserUser() -> Void {
        let user = SafeJsonParser.SafeBackupData.User(privatekey: "key123")
        user.nickname = "nicki"
        user.profilePic = "pic source"
        user.profilePicRelease = ["ECHOECHO", "TEST1234"]
        user.links = [SafeJsonParser.SafeBackupData.User.Link (type: "email", value: "a@a.a")]

        let parser = SafeJsonParser()
        var safeBackupData = parser.getSafeBackupData()
        safeBackupData.user = user

        let json = parser.getJsonAsString(from: safeBackupData)

        XCTAssertNotNil(json)
        XCTAssertNotNil(json?.range(of: "\"privatekey\":\"key123\""))
        XCTAssertNotNil(json?.range(of: "\"nickname\":\"nicki\""))
        XCTAssertNotNil(json?.range(of: "\"profilePic\":\"pic source\""))
        XCTAssertNotNil(json?.range(of: "\"profilePicRelease\":[\"ECHOECHO\",\"TEST1234\"]"))
        XCTAssertNotNil(json?.range(of: "{\"links\":[{"))
        XCTAssertNotNil(json?.range(of: "\"type\":\"email\""))
        XCTAssertNotNil(json?.range(of: "\"value\":\"a@a.a\""))
        XCTAssertNotNil(json?.range(of: "}]"))
    }

    func testSafeJsonParserLoad() -> Void {
        let json = "{\"info\":{\"version\":1,\"device\":\"ios\"},\"user\":{\"links\":[{\"type\":\"email\",\"name\":\"privat\",\"value\":\"a@a.a\"}],\"nickname\":\"nicki\",\"privatekey\":\"key123\",\"profilePic\":\"pic source\",\"profilePicRelease\":[\"ECHOECHO\",\"TEST1234\"]}}"
        let parser = SafeJsonParser()
        let safeBackupData = try! parser.getSafeBackupData(from: json.data(using: .utf8)!)

        XCTAssertNotNil(safeBackupData)
        XCTAssertEqual(safeBackupData.user?.nickname, "nicki")
    }

    func testSafeStoreCreateKey() -> Void {
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())

        let result = store.createKey(identity: "ECHOECHO", password: "shootdeathstar")

        XCTAssertEqual(hexString(data: result!),
            "066384d3695fbbd9f31a7d533900fd0cd8d1373beb6a28678522d2a49980c9c351c3d8d752fb6e1fd3199ead7f0895d6e3893ff691f2a5ee1976ed0897fc2f66")
    }

    func testSafeStoreGetBackupIdAndGetEncrptionKey() -> Void {
        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())

        let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar")
        let backupId = store.getBackupId(key: key!)
        let encryptionKey = store.getEncryptionKey(key: key!)

        XCTAssertNotNil(backupId)
        XCTAssertNotNil(encryptionKey)
        XCTAssertEqual(32, backupId?.count)
        XCTAssertEqual(32, encryptionKey?.count)
        XCTAssertFalse(backupId!.elementsEqual(encryptionKey!))
    }

    private func hexString(data: [UInt8]) -> String {
        return data.map { String(format: "%02hhx", $0) }.joined(separator: "")
    }

    func testSafeStoreBackupDataEncryptDecrypt() {
        let user = SafeJsonParser.SafeBackupData.User(privatekey: "key123")
        user.nickname = "nicki"
        let parser = SafeJsonParser()
        var dataIn = parser.getSafeBackupData()
        dataIn.user = user;

        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
        let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar")
        let encryptedData = try! store.encryptBackupData(key: key!, data: parser.getJsonAsBytes(from: dataIn)!)
        let decryptedData = try! store.decryptBackupData(key: key!, data: encryptedData)

        let dataOut = try! parser.getSafeBackupData(from: Data(decryptedData))

        XCTAssertNotNil(dataOut.user)
        XCTAssertEqual("key123", dataOut.user?.privatekey)
        XCTAssertEqual("nicki", dataOut.user?.nickname)
    }

    func testSafeManagerIsPasswordBad() {
        let passwordTests = [
            ["", true],
            ["1", true],
            ["a", true],
            ["aaaaaaaa", true],
            ["11111111", true],
            ["1111111w", false],
            ["83497585", true],
            ["123456789012345", true],
            ["1234567890123456", false],
            ["7777777777777777", true],
            ["834975 8", false],
            ["83497 8", true],
            ["        ", true],
            ["0000000000d", true],
            ["ronaldo7", true],
            ["Zzzzzzz1", true]
        ]

        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        let safeManager: SafeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())

        for passwordTest in passwordTests {
            let isBad = safeManager.isPasswordBad(password: passwordTest[0] as! String)

            if passwordTest[1] as! Bool {
                XCTAssert(isBad, "\(passwordTest[0]) isBad:\(isBad)")
            } else {
                XCTAssertFalse(isBad, "\(passwordTest[0]) isBad:\(isBad)")
            }
        }
    }

    func testSafeManagerIsPasswordPatternValid() {
        let passwordTests = [
            ["", false],
            ["12345678aA", true],
            ["123456789aA", true],
            ["1234567aA", false],
            ["12345678aa", false],
        ]

        // Password min. length 10 with min. one lowercase and one uppercase character
        let regExPattern: String = "(?=(.*[0-9]))(?=.*[a-z])(?=(.*[A-Z]))(?=(.*)).{10,}"
        
        for passwordTest in passwordTests {
            let result = try? SafeManager.isPasswordPatternValid(password: passwordTest[0] as! String, regExPattern: regExPattern)
            
            XCTAssertEqual(result, passwordTest[1] as! Bool)
        }
    }
    
    /*
    func testApi() {
        let asyncDone = expectation(description: "async func")

        var identity: String?

        let api = ServerAPIConnector()
        api.fetchBulkIdentityInfo(["ECHOECHO"], onCompletion: { (identities, publicKeys, featureLevels, featureMasks, states, types) in

            if let identities = identities as? [String] {
                print(identities.count)
                identity = identities[0] as String
            }

            asyncDone.fulfill()
        }) { (error) in
            print(error)

            asyncDone.fulfill()
        }

        wait(for: [asyncDone], timeout: 10)

        XCTAssertEqual("ECHOECHO", identity)
    }
    */

    func testSafeSeverToDisplay() {
        let store = SafeStore(safeConfigManager: SafeConfigManagerMock(server: nil), serverApiConnector: ServerAPIConnector())

        let result = store.getSafeServerToDisplay()

        XCTAssertNotNil(result)
    }

    func testSafeServerUrlDefault() {
        let store = SafeStore(safeConfigManager: SafeConfigManagerMock(server: nil), serverApiConnector: ServerAPIConnector())
        let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar")!

        let url = store.getSafeServer(key: key)

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://safe-06.threema.ch")

        XCTAssertEqual(url?.appendingPathComponent("backups/\(SafeStore.dataToHexString(store.getBackupId(key: key)!))").absoluteString, "https://safe-06.threema.ch/backups/066384d3695fbbd9f31a7d533900fd0cd8d1373beb6a28678522d2a49980c9c3")
    }

    func testSafeServerUrlCustom() {
        let store = SafeStore(safeConfigManager: SafeConfigManagerMock(server: "http://test.com"), serverApiConnector: ServerAPIConnector())
        let key = store.createKey(identity: "ECHOECHO", password: "shootdeathstar")!

        let url = store.getSafeServer(key: key)

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://test.com")

        XCTAssertEqual(url?.appendingPathComponent("backups/\(SafeStore.dataToHexString(store.getBackupId(key: key)!))").absoluteString, "http://test.com/backups/066384d3695fbbd9f31a7d533900fd0cd8d1373beb6a28678522d2a49980c9c3")
    }

    func testComposeSafeServerAuth() {
        let serverUrlTests = [
            [nil, nil, nil, nil],
            ["https://example.com/", nil, nil, "https://example.com/"],
            ["https://example.com/", "test.tester@app.com", nil, "https://test.tester%40app.com:@example.com/"],
            ["https://example.com/", "test.tester@app.com", "passphrase", "https://test.tester%40app.com:passphrase@example.com/"],
            ["https://example.com", "test.tester@app.com", "püssiKösch", "https://test.tester%40app.com:p%C3%BCssiK%C3%B6sch@example.com"],
            ["example.com", "test.tester@app.com", "püssiKösch", "https://test.tester%40app.com:p%C3%BCssiK%C3%B6sch@example.com"],
            ["https://example.com/", nil, "passphrase", "https://:passphrase@example.com/"],
            ["HTTPS://example.com", nil, nil, "HTTPS://example.com"],
            ["HTtPS://example.com", nil, nil, "HTtPS://example.com"],
            ["http://example.com", nil, nil, nil],
            ["https://exämple.com", nil, nil, nil],
        ]

        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())

        for serverUrlTest in serverUrlTests {
            let url = store.composeSafeServerAuth(server: serverUrlTest[0], user: serverUrlTest[1], password: serverUrlTest[2])

            if serverUrlTest[3] != nil {
                XCTAssertNotNil(url)
                XCTAssertEqual(url?.absoluteString, serverUrlTest[3])

            } else {
                XCTAssertNil(url)
            }
        }
    }

    func testExtractSafeServerAuth() {
        let serverUrlTests = [
            ["https://example.com/", nil, nil, "https://example.com/"],
            ["https://test.tester%40app.com:@example.com/", "test.tester@app.com", "", "https://example.com/"],
            ["https://test.tester%40app.com:passphrase@example.com/", "test.tester@app.com", "passphrase", "https://example.com/"],
            ["https://test.tester%40app.com:p%C3%BCssiK%C3%B6sch@example.com", "test.tester@app.com", "püssiKösch", "https://example.com"],
            ["https://:passphrase@example.com/", "", "passphrase", "https://example.com/"],
            ["https://passphrase@example.com/", "passphrase", nil, "https://example.com/"],
            ["HTTPS://example.com", nil, nil, "HTTPS://example.com"],
            ["HTtPS://example.com", nil, nil, "HTtPS://example.com"],
            ["http://example.com", nil, nil, "http://example.com"],
        ]

        let store = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())

        for serverUrlTest in serverUrlTests {
            let safeServerAuth = store.extractSafeServerAuth(server: URL(string: serverUrlTest[0]!)!)

            XCTAssertEqual(serverUrlTest[1], safeServerAuth.user)
            XCTAssertEqual(serverUrlTest[2], safeServerAuth.password)
            XCTAssertEqual(URL(string: serverUrlTest[3]!)!, safeServerAuth.server)
        }
    }
}
