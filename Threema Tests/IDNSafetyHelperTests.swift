//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

@testable import Threema

class IDNSafetyHelperTests: XCTestCase {    
    func testIsLegalUrl() {
        // Note: URL/NSURL cannot handle Unicode hostnames directly, so we need to pre-Punycode them
        XCTAssertTrue(IDNSafetyHelper.isLegalURL(url: URL(string: "https://threema.ch")!))
        XCTAssertFalse(IDNSafetyHelper.isLegalURL(url: URL(string: "https://xn--threem-8nf.ch")!))
        XCTAssertTrue(IDNSafetyHelper.isLegalURL(url: URL(string: "https://xn--gmqa5019b.xn--55qx5d")!))
        XCTAssertFalse(IDNSafetyHelper.isLegalURL(url: URL(string: "https://xn--gfrr-7qa.li")!))
        XCTAssertTrue(IDNSafetyHelper.isLegalURL(url: URL(string: "https://wikipedia.org")!))
        XCTAssertFalse(IDNSafetyHelper.isLegalURL(url: URL(string: "https://xn--wikipedi-86g.org")!))
        XCTAssertFalse(IDNSafetyHelper.isLegalURL(url: URL(string: "https://xn--wkipedia-c2a.org")!))
    }
}
