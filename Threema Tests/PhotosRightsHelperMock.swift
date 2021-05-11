//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

import Foundation
import Threema

class PhotosRightsHelperMock : PhotosRightsHelperProtocol {
    private var accessLevelDeterminedResult : Bool
    private var requestWriteAccessResult : Bool
    private var requestReadAccessResult : Bool
    private var readAccess : Bool
    private var fullAccess : Bool
    private var writeAccess : Bool
    private var newPhotosApi : Bool
    
    init(accessLevelDetermined : Bool, requestWriteAccess : Bool, requestReadAccess : Bool, readAccess : Bool, fullAccess : Bool, writeAccess : Bool, newPhotosApi : Bool) {
        self.accessLevelDeterminedResult = accessLevelDetermined
        self.writeAccess = writeAccess
        self.readAccess = readAccess
        self.fullAccess = fullAccess
        self.requestWriteAccessResult = requestWriteAccess
        self.requestReadAccessResult = requestReadAccess
        self.newPhotosApi = newPhotosApi
    }
    
    func accessLevelDetermined() -> Bool {
        return accessLevelDeterminedResult
    }
    func requestWriteAccess() -> Bool {
        return requestWriteAccessResult
    }
    func requestReadAccess() -> Bool {
        return requestReadAccessResult
    }
    func haveFullAccess() -> Bool {
        return fullAccess
    }
    func haveWriteAccess() -> Bool {
        return writeAccess
    }
    
    func checknewPhotosApi() -> Bool {
        return newPhotosApi
    }
}
