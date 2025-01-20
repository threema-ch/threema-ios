//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

class ResourceLoader {
    
    static func urlResource(_ filename: String, _ fileExtension: String) -> URL? {
        let testBundle = Bundle(for: ResourceLoader.self)
        return testBundle.url(forResource: filename, withExtension: fileExtension)
    }
    
    static func contentAsString(_ fileName: String, _ fileExtension: String) -> String? {
        let testBundle = Bundle(for: ResourceLoader.self)
        if let filePath = testBundle.path(forResource: fileName, ofType: fileExtension) {
            return try? String(contentsOfFile: filePath, encoding: .utf8)
        }
        return nil
    }
}
