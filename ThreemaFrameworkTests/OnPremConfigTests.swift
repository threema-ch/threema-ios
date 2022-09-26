//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

// swiftformat:disable acronyms

import XCTest

@testable import ThreemaFramework

class OnPremConfigTests: XCTestCase {

    static let publicKeys = ["jae1lgwR3W7YyKiGQlsbdqObG13FR1EvjVci2aDNIi8="]
    // Use the secret key below to regenerate the test OPPF data
    static let secretKey = "ezDKBie96Hnu39gpM2iiIYwfE6cRXzON32K/KbLusYk="
    
    // Wrong key that is not trusted
    static let wrongPublicKeys = ["3z1cAHQRAkeY+NJg3/st5DGUdEXICcvRWeMT4y5l0CQ="]
    
    // An OPPF that is valid, unexpired and has a good signature
    static let goodOppf = """
        {
            "license": {
                "expires": "2099-12-31",
                "count": 100,
                "id": "DUMMY-00000001"
            },
            "blob": {
                "uploadUrl": "https://blob.threemaonprem.initrode.com/blob/upload",
                "downloadUrl": "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}",
                "doneUrl": "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}/done"
            },
            "chat": {
                "hostname": "chat.threemaonprem.initrode.com",
                "publicKey": "r9utIHN9ngo21q9OlZcotsQu1f2HwAW2Wi+u6Psp4Wc=",
                "ports": [
                    5222,
                    443
                ]
            },
            "work": {"url": "https://work.threemaonprem.initrode.com/"},
            "signatureKey": "jae1lgwR3W7YyKiGQlsbdqObG13FR1EvjVci2aDNIi8=",
            "safe": {"url": "https://safe.threemaonprem.initrode.com/"},
            "refresh": 86400,
            "avatar": {"url": "https://avatar.threemaonprem.initrode.com/"},
            "mediator": {
                "blob": {
                    "uploadUrl": "https://mediator.threemaonprem.initrode.com/blob/upload",
                    "downloadUrl": "https://mediator.threemaonprem.initrode.com/blob/{blobId}",
                    "doneUrl": "https://mediator.threemaonprem.initrode.com/blob/{blobId}/done"
                },
                "url": "https://mediator.threemaonprem.initrode.com/"
            },
            "version": "1.0",
            "directory": {"url": "https://dir.threemaonprem.initrode.com/directory"}
        }
        oq6Z5le4wVmThTQTx2IMPJ+CsvSATFsfGQEbYJD0nfZTPDUKpwWk8VfLShX7cT2HLwWyWp9CY8d/pDn/9Vs3Ag==
        """
    
    // An OPPF that is expired but has a good signature
    static let expiredOppf = """
        {
            "license": {
                "expires": "2020-12-31",
                "count": 100,
                "id": "DUMMY-00000001"
            },
            "blob": {
                "uploadUrl": "https://blob.threemaonprem.initrode.com/blob/upload",
                "downloadUrl": "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}",
                "doneUrl": "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}/done"
            },
            "chat": {
                "hostname": "chat.threemaonprem.initrode.com",
                "publicKey": "r9utIHN9ngo21q9OlZcotsQu1f2HwAW2Wi+u6Psp4Wc=",
                "ports": [
                    5222,
                    443
                ]
            },
            "work": {"url": "https://work.threemaonprem.initrode.com/"},
            "signatureKey": "jae1lgwR3W7YyKiGQlsbdqObG13FR1EvjVci2aDNIi8=",
            "safe": {"url": "https://safe.threemaonprem.initrode.com/"},
            "refresh": 86400,
            "avatar": {"url": "https://avatar.threemaonprem.initrode.com/"},
            "mediator": {
                "blob": {
                    "uploadUrl": "https://mediator.threemaonprem.initrode.com/blob/upload",
                    "downloadUrl": "https://mediator.threemaonprem.initrode.com/blob/{blobId}",
                    "doneUrl": "https://mediator.threemaonprem.initrode.com/blob/{blobId}/done"
                },
                "url": "https://mediator.threemaonprem.initrode.com/"
            },
            "version": "1.0",
            "directory": {"url": "https://dir.threemaonprem.initrode.com/directory"}
        }
        oo0gLBRSi7148KbPqF9KkVL2KLzNIOzvEuoGQ2otlT0gk6d/b/gxYAWyoKHj78YtkwY/2OS/pT1pH/GVqZ02DQ==
        """
    
    static var config: OnPremConfig?
    
    override class func setUp() {
        let verifier = OnPremConfigVerifier(trustedPublicKeys: OnPremConfigTests.publicKeys)
        do {
            config = try verifier.verify(oppfData: OnPremConfigTests.goodOppf)
        }
        catch {
            print("setUp error: \(error)")
        }
    }

    func testVerifyVersion() throws {
        XCTAssertEqual("1.0", OnPremConfigTests.config!.version)
    }
    
    func testVerifyBad() throws {
        // Create a damaged signature by flipping a character
        let badOppf = OnPremConfigTests.goodOppf.replacingOccurrences(of: "initrode", with: "inytrode")
        
        let verifier = OnPremConfigVerifier(trustedPublicKeys: OnPremConfigTests.publicKeys)
        XCTAssertThrowsError(try verifier.verify(oppfData: badOppf)) { error in
            XCTAssertEqual(error as! OnPremConfigError, OnPremConfigError.badSignature)
        }
    }
    
    func testVerifyUntrustedKey() throws {
        let verifier = OnPremConfigVerifier(trustedPublicKeys: OnPremConfigTests.wrongPublicKeys)
        XCTAssertThrowsError(try verifier.verify(oppfData: OnPremConfigTests.goodOppf))
    }
    
    func testRefresh() {
        XCTAssertEqual(OnPremConfigTests.config!.refresh, 86400)
    }
    
    func testExpiration() {
        let verifier = OnPremConfigVerifier(trustedPublicKeys: OnPremConfigTests.publicKeys)
        XCTAssertThrowsError(try verifier.verify(oppfData: OnPremConfigTests.expiredOppf)) { error in
            XCTAssertEqual(error as! OnPremConfigError, OnPremConfigError.licenseExpired)
        }
    }
    
    func testChatConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.chat.hostname, "chat.threemaonprem.initrode.com")
        XCTAssertEqual(OnPremConfigTests.config!.chat.ports, [5222, 443])
        XCTAssertEqual(
            OnPremConfigTests.config!.chat.publicKey,
            Data(base64Encoded: "r9utIHN9ngo21q9OlZcotsQu1f2HwAW2Wi+u6Psp4Wc=")
        )
    }
    
    func testDirectoryConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.directory.url, "https://dir.threemaonprem.initrode.com/directory")
    }
    
    func testBlobConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.blob.uploadUrl, "https://blob.threemaonprem.initrode.com/blob/upload")
        XCTAssertEqual(
            OnPremConfigTests.config!.blob.downloadUrl,
            "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}"
        )
        XCTAssertEqual(
            OnPremConfigTests.config!.blob.doneUrl,
            "https://blob-{blobIdPrefix}.threemaonprem.initrode.com/blob/{blobId}/done"
        )
    }
    
    func testWorkConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.work!.url, "https://work.threemaonprem.initrode.com/")
    }
    
    func testAvatarConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.avatar!.url, "https://avatar.threemaonprem.initrode.com/")
    }
    
    func testSafeConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.safe!.url, "https://safe.threemaonprem.initrode.com/")
    }
    
    func testMediatorConfig() {
        XCTAssertEqual(OnPremConfigTests.config!.mediator!.url, "https://mediator.threemaonprem.initrode.com/")
        XCTAssertEqual(
            OnPremConfigTests.config!.mediator!.blob.uploadUrl,
            "https://mediator.threemaonprem.initrode.com/blob/upload"
        )
        XCTAssertEqual(
            OnPremConfigTests.config!.mediator!.blob.downloadUrl,
            "https://mediator.threemaonprem.initrode.com/blob/{blobId}"
        )
        XCTAssertEqual(
            OnPremConfigTests.config!.mediator!.blob.doneUrl,
            "https://mediator.threemaonprem.initrode.com/blob/{blobId}/done"
        )
    }
}
