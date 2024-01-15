//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

class FSVersionObjectiveCSwiftCompatibilityCheck: XCTestCase {
    let allObjectiveCCases: [ObjcCspE2eFs_Version] = [
        ObjcCspE2eFs_Version.V10,
        ObjcCspE2eFs_Version.V11,
        ObjcCspE2eFs_Version.V12,
        ObjcCspE2eFs_Version.unspecified,
    ]
    
    func testAllCases() throws {
        for versionCase in CspE2eFs_Version.allCases {
            let objectiveCVersion = try XCTUnwrap(ObjcCspE2eFs_Version(rawValue: UInt(versionCase.rawValue)))
            XCTAssertTrue(allObjectiveCCases.contains(objectiveCVersion))
        }
    }
    
    func testOneCaseMissing() throws {
        let allObjectiveCCasesExceptUnspecified: [ObjcCspE2eFs_Version] = [
            ObjcCspE2eFs_Version.V10,
            ObjcCspE2eFs_Version.V11,
            ObjcCspE2eFs_Version.V12,
        ]
        
        for versionCase in CspE2eFs_Version.allCases {
            let objectiveCVersion = try XCTUnwrap(ObjcCspE2eFs_Version(rawValue: UInt(versionCase.rawValue)))
            if versionCase == .unspecified {
                XCTAssertFalse(allObjectiveCCasesExceptUnspecified.contains(objectiveCVersion))
            }
            else {
                XCTAssertTrue(allObjectiveCCasesExceptUnspecified.contains(objectiveCVersion))
            }
        }
    }
}
