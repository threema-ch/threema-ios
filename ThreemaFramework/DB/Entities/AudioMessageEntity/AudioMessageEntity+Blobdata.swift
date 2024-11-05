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

import CocoaLumberjackSwift
import Foundation

extension AudioMessageEntity: BlobData {
    
    public var blobIdentifier: Data? {
        get {
            // swiftformat:disable:next acronyms
            audioBlobId
        }
        set {
            // swiftformat:disable:next acronyms
            audioBlobId = newValue
        }
    }
    
    public var blobThumbnailIdentifier: Data? {
        get {
            nil
        }
        set {
            assertionFailure("AudioMessageEntity does not have a thumbnailID.")
            return
        }
    }
    
    public var blobData: Data? {
        get {
            audio?.data as? Data
        }
        set {
            guard let newValue else {
                if let audio {
                    managedObjectContext?.delete(audio)
                    self.audio = nil
                }
                
                return
            }
            
            let resolvedAudioDataEntity: AudioDataEntity
            
            // We only create a new data if we do not have one already
            if let audio {
                resolvedAudioDataEntity = audio
            }
            else if let managedObjectContext,
                    let newData = NSEntityDescription.insertNewObject(
                        forEntityName: "AudioData",
                        into: managedObjectContext
                    ) as? AudioDataEntity {
                resolvedAudioDataEntity = newData
            }
            else {
                DDLogError("Unable to load managed object context or create new audio data entity")
                return
            }
            
            resolvedAudioDataEntity.data = newValue
            audio = resolvedAudioDataEntity
        }
    }
    
    public var blobThumbnail: Data? {
        get {
            nil
        }
        set {
            assertionFailure("AudioMessageEntity does not have a thumbnail.")
            return
        }
    }
    
    public var blobIsOutgoing: Bool {
        isOwnMessage
    }
    
    public var blobEncryptionKey: Data? {
        encryptionKey
    }
    
    public var blobUTTypeIdentifier: String? {
        UTType.audio.identifier
    }
    
    public var blobSize: Int {
        Int(truncating: audioSize ?? 0)
    }
    
    public var blobOrigin: BlobOrigin {
        get {
            .public
        }
        set {
            assertionFailure("AudioMessageEntity origin is always .public .")
            return
        }
    }
    
    public var blobProgress: NSNumber? {
        get {
            progress
        }
        set {
            progress = newValue
        }
    }
    
    public var blobError: Bool {
        get {
            sendFailed?.boolValue ?? false
        }
        set {
            sendFailed = NSNumber(booleanLiteral: newValue)
        }
    }
    
    public var blobFilename: String? {
        "\(id.hexString).\(MEDIA_EXTENSION_AUDIO)"
    }
    
    public var blobWebFilename: String {
        "threema-\(DateFormatter.getDateForFilename(date))-audio.\(MEDIA_EXTENSION_AUDIO)"
    }
    
    public var blobExternalFilename: String? {
        audio?.getFilename()
    }
    
    public var blobThumbnailExternalFilename: String? {
        nil
    }
}
