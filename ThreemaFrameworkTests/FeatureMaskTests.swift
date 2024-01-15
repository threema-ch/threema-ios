//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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
@testable import ThreemaProtocols

class FeatureMaskTests: XCTestCase {
    private var deviceGroupKeys: DeviceGroupKeys!
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        deviceGroupKeys = MockData.deviceGroupKeys
    }
    
    override func tearDownWithError() throws { }
    
    func testCurrentFeatureMask0() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().build()
        
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue == 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue == 0)
    }
    
    func testCurrentFeatureMask1() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: true)
            .groupCalls(enabled: true)
            .build()
        
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue != 0)
    }
    
    func testCurrentFeatureMask2() {
        let featureMask: Int = FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: false)
            .groupCalls(enabled: true)
            .build()
        
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue != 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue == 0)
        XCTAssertTrue(featureMask & ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue != 0)
    }
}
