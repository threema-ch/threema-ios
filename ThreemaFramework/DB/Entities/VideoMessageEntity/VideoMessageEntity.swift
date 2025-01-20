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

@objc(VideoMessageEntity)
public final class VideoMessageEntity: BaseMessage {
    
    // Attributes
    @NSManaged @objc(duration) public var duration: NSNumber
    @NSManaged @objc(encryptionKey) public var encryptionKey: Data?
    @NSManaged @objc(progress) public var progress: NSNumber?
    // swiftformat:disable:next acronyms
    @NSManaged @objc(videoBlobId) public var videoBlobId: Data?
    @NSManaged @objc(videoSize) public var videoSize: NSNumber?

    // Relationships
    @NSManaged public var thumbnail: ImageDataEntity?
    @NSManaged public var video: VideoDataEntity?
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - duration: Duration of the video
    ///   - encryptionKey: Key the video data is encrypted with
    ///   - progress: Progress
    ///   - videoBlobID: Blob id of the video data
    ///   - videoSize: Size of the video data
    ///   - thumbnail: ImageDataEntity of the thumbnail
    ///   - video: VideoDataEntity in which the video is saved
    public init(
        context: NSManagedObjectContext,
        duration: NSNumber = 0,
        encryptionKey: Data? = nil,
        progress: NSNumber? = nil,
        videoBlobID: Data? = nil,
        videoSize: NSNumber? = nil,
        thumbnail: ImageDataEntity,
        video: VideoDataEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "VideoMessage", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.duration = duration
        self.encryptionKey = encryptionKey
        self.progress = progress
        // swiftformat:disable:next acronyms
        self.videoBlobId = videoBlobID
        self.videoSize = videoSize
        
        self.thumbnail = thumbnail
        self.video = video
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
