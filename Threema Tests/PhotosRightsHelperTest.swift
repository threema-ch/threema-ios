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

import XCTest
@testable import Threema

class PhotosRightsHelperTest: XCTestCase {

    func testPhotosRights() throws {        
        let table : [([Bool], PhotosRights)] = [([true, true, true, true, true, true, false], .full),
                                                ([true, true, true, true, true, true, true], .full),
                                                ([false, true, true, true, true, true, false], .full),
                                                ([false, true, true, true, true, true, true], .write),
                                                ([false, true, true, true, true, true, false], .full),
                                                ([false, true, true, true, true, true, true], .write),
                                                ([false, false, false, true, true, true, false], .potentialWrite),
                                                ([false, false, false, true, true, true, true], .none),
                                                ([true, true, true, true, false, true, false], .write),
                                                ([true, true, true, true, false, false, false], .potentialWrite)]
        
        var mock : PhotosRightsHelperMock
        
        for item in table{
            mock = PhotosRightsHelperMock(accessLevelDetermined: item.0[0], requestWriteAccess: item.0[1], requestReadAccess: item.0[2], readAccess: item.0[3], fullAccess: item.0[4], writeAccess: item.0[5], newPhotosApi: item.0[6])
            let result = PhotosRightsHelper.checkAccessAllowed(rightsHelper: mock)
            XCTAssert(result == item.1, "Result is \(result), but should be \(item.1). For input \(item)")
        }
    }
}
