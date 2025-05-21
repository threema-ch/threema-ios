//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import CoreData
import Foundation

@objc(AudioMessageEntity)
public final class AudioMessageEntity: BaseMessageEntity {
    
    // MARK: Attributes

    // swiftformat:disable:next acronyms
    @NSManaged public var audioBlobId: Data?
    @NSManaged public var audioSize: NSNumber?
    @NSManaged public var duration: NSNumber
    @NSManaged public var encryptionKey: Data?
    @NSManaged public var progress: NSNumber?

    // MARK: Relationships

    @NSManaged public var audio: AudioDataEntity?
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - audioBlobID: BlobID of the audio data
    ///   - audioSize: Size of the audio data
    ///   - duration: Duration of the audio
    ///   - encryptionKey: Key the audio data is encrypted with
    ///   - progress: Progress
    ///   - audio: `AudioDataEntity` to which the audio is saved
    public init(
        context: NSManagedObjectContext,
        audioBlobID: Data? = nil,
        audioSize: NSNumber? = nil,
        duration: NSNumber = 0,
        encryptionKey: Data? = nil,
        progress: NSNumber? = nil,
        audio: AudioDataEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "AudioMessage", in: context)!
        super.init(entity: entity, insertInto: context)
        
        // swiftformat:disable:next acronyms
        self.audioBlobId = audioBlobID
        self.audioSize = audioSize
        self.duration = duration
        self.encryptionKey = encryptionKey
        self.progress = progress
        
        self.audio = audio
    }
    
    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    public init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    public convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }
}
