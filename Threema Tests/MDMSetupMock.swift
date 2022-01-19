//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@testable import Threema

class MDMSetupMock: MDMSetup {
    
    private var _disabelBackups: Bool?
    private var _safeEanble: Int?
    private var _safeServerUrl: String?
    private var _safePassword: String?
    private var _safeRestoreEnable: Bool?
    private var _safeRestoreId: String?

    override convenience init() {
        self.init()
    }
    
    convenience init(disableBackups: Bool?, safeEnable: Int?, safeServerUrl: String?, safePassword: String?, safeRestoreEnable: Bool?, safeRestoreId: String?) {
        self.init(setup: false)
        self._disabelBackups = disableBackups
        self._safeEanble = safeEnable
        self._safeServerUrl = safeServerUrl
        self._safePassword = safePassword
        self._safeRestoreEnable = safeRestoreEnable
        self._safeRestoreId = safeRestoreId
    }
    
    override func disableBackups() -> Bool {
        return self._disabelBackups != nil ? self._disabelBackups! : false
    }
    
    override func safeEnable() -> NSNumber? {
        return self._safeEanble != nil ? NSNumber(value: self._safeEanble!) : nil
    }
    
    override func safeServerUrl() -> String? {
        return self._safeServerUrl
    }
    
    override func safePassword() -> String? {
        return self._safePassword
    }
    
    override func safeRestoreEnable() -> Bool {
        return self._safeRestoreEnable != nil ? self._safeRestoreEnable! : true
    }
    
    override func safeRestoreId() -> String? {
        return self._safeRestoreId
    }
}
