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

/// Provides the public attributes to access the information and data from data containing message types.
@objc public protocol BlobData {
    var blobIdentifier: Data? { get set }
    var blobThumbnailIdentifier: Data? { get set }
    var blobData: Data? { get set }
    var blobThumbnail: Data? { get set }
    var blobIsOutgoing: Bool { get }
    var blobEncryptionKey: Data? { get }
    // TODO: IOS-3057: Replace with the actual UTTypeIdentifier
    var blobUTTypeIdentifier: String? { get }
    var blobSize: Int { get }
    var blobOrigin: BlobOrigin { get set }
    var blobProgress: NSNumber? { get set }
    var blobError: Bool { get set }
    var blobFilename: String? { get }
    var blobWebFilename: String { get }
    var blobExternalFilename: String? { get }
    var blobThumbnailExternalFilename: String? { get }
    var deletedAt: Date? { get }
    var isPersistingBlob: Bool { get }
}
