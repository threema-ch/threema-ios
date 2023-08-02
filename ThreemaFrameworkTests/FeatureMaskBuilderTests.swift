//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
@testable import ThreemaFramework

final class FeatureMaskBuilderTests: XCTestCase {

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testForwardSecurityEnabled() throws {
        // Copied from previous implementation of FeatureMask
        let goldVal = 0x7F
        
        XCTAssertTrue(FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: true).build() ^ goldVal == 0)
    }
    
    func testForwardSecurityDisabled() throws {
        // Copied from previous implementation of FeatureMask
        let goldVal = 0x3F
        
        XCTAssertTrue(FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: false).build() ^ goldVal == 0)
    }
}
