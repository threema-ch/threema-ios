//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

class BlobManagerMock: BlobManagerProtocol {
    
    var syncHandler: (NSManagedObjectID) throws -> BlobManagerResult = { _ in
        .failed
    }
    
    // MARK: BlobManagerProtocol
    
    func autoSyncBlobs(for objectID: NSManagedObjectID) async {
        // no-op
    }
    
    func syncBlobs(for objectID: NSManagedObjectID) async -> BlobManagerResult {
        do {
            return try await syncBlobsThrows(for: objectID)
        }
        catch {
            return .failed
        }
    }
    
    func syncBlobsThrows(for objectID: NSManagedObjectID) async throws -> ThreemaFramework.BlobManagerResult {
        try syncHandler(objectID)
    }
    
    func cancelBlobsSync(for objectID: NSManagedObjectID) async {
        // no-op
    }
}
