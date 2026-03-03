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
import ThreemaMacros

@objc(VideoMessageEntity)
public final class VideoMessageEntity: BaseMessageEntity {

    enum Field: String {
        case video
        case videoBlobID

        static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .video:
                field.rawValue
            case .videoBlobID:
                encrypted ? encryptedVideoBlobIDName : videoBlobIDName
            }
        }
    }

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var duration: NSNumber {
        get {
            getDuration()
        }

        set {
            setDuration(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var encryptionKey: Data? {
        get {
            getEncryptionKey()
        }

        set {
            setEncryptionKey(newValue)
        }
    }

    @NSManaged public var progress: NSNumber?

    @EncryptedField(name: "videoBlobId")
    // swiftformat:disable:next acronyms
    @objc(videoBlobId) public dynamic var videoBlobID: Data? {
        get {
            getVideoBlobID()
        }

        set {
            setVideoBlobID(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var videoSize: NSNumber? {
        get {
            getVideoSize()
        }

        set {
            setVideoSize(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var thumbnail: ImageDataEntity?
    @NSManaged public var video: VideoDataEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedDuration: Float? // Non optional
    private var decryptedEncryptionKey: Data?
    private var decryptedVideoBlobID: Data?
    private var decryptedVideoSize: Int32?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - duration: Duration of the video
    ///   - encryptionKey: Key the video data is encrypted with
    ///   - progress: Progress
    ///   - videoBlobID: Blob id of the video data
    ///   - videoSize: Size of the video data
    ///   - conversation: Conversation the message belongs to
    ///   - thumbnail: `ImageDataEntity` of the thumbnail
    ///   - video: `VideoDataEntity` of the video
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        duration: NSNumber = 0,
        encryptionKey: Data? = nil,
        progress: NSNumber? = nil,
        videoBlobID: Data? = nil,
        videoSize: NSNumber? = nil,
        conversation: ConversationEntity,
        thumbnail: ImageDataEntity? = nil,
        video: VideoDataEntity? = nil,
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "VideoMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)

        setDuration(duration)
        setEncryptionKey(encryptionKey)
        if let progress {
            self.progress = progress as NSNumber
        }
        setVideoBlobID(videoBlobID)
        setVideoSize(videoSize)

        self.thumbnail = thumbnail
        self.video = video
    }

    @available(*, unavailable)
    init() {
        fatalError("\(#function) not implemented")
    }

    @available(*, unavailable)
    convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }

    // MARK: Public functions

    #if !DEBUG
        override public var debugDescription: String {
            """
            <\(type(of: self))>:\(VideoMessageEntity.self), \
            progress = \(progress?.description ?? "nil"), \
            videoBlobID = \("***"), \
            encryptionKey = \("***"), \
            videoSize = \(videoSize?.description ?? "nil"), \
            video = \(video?.description ?? "nil"), \
            thumbnail = \(thumbnail?.description ?? "nil"), \
            duration = \(duration.description)
            """
        }
    #endif

    // MARK: - Custom get/set functions

    // MARK: Duration

    private func getDuration() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedDuration, forKey: Self.encryptedDurationName)
            if let decryptedDuration {
                value = NSNumber(value: decryptedDuration)
            }
        }
        else {
            willAccessValue(forKey: Self.durationName)
            value = primitiveValue(forKey: Self.durationName) as? NSNumber ?? value
            didAccessValue(forKey: Self.durationName)
        }
        return value
    }

    private func setDuration(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.floatValue, forKey: Self.encryptedDurationName)
            decryptedDuration = newValue.floatValue
        }
        else {
            willChangeValue(forKey: Self.durationName)
            setPrimitiveValue(newValue, forKey: Self.durationName)
            didChangeValue(forKey: Self.durationName)
        }
    }

    // MARK: EncryptionKey

    private func getEncryptionKey() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedEncryptionKey, forKey: Self.encryptedEncryptionKeyName)
            value = decryptedEncryptionKey
        }
        else {
            willAccessValue(forKey: Self.encryptionKeyName)
            value = primitiveValue(forKey: Self.encryptionKeyName) as? Data
            didAccessValue(forKey: Self.encryptionKeyName)
        }
        return value
    }

    private func setEncryptionKey(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedEncryptionKeyName)
            decryptedEncryptionKey = newValue
        }
        else {
            willChangeValue(forKey: Self.encryptionKeyName)
            setPrimitiveValue(newValue, forKey: Self.encryptionKeyName)
            didChangeValue(forKey: Self.encryptionKeyName)
        }
    }

    // MARK: VideoBlobID

    private func getVideoBlobID() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedVideoBlobID, forKey: Self.encryptedVideoBlobIDName)
            value = decryptedVideoBlobID
        }
        else {
            willAccessValue(forKey: Self.videoBlobIDName)
            value = primitiveValue(forKey: Self.videoBlobIDName) as? Data
            didAccessValue(forKey: Self.videoBlobIDName)
        }
        return value
    }

    private func setVideoBlobID(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedVideoBlobIDName)
            decryptedVideoBlobID = newValue
        }
        else {
            willChangeValue(forKey: Self.videoBlobIDName)
            setPrimitiveValue(newValue, forKey: Self.videoBlobIDName)
            didChangeValue(forKey: Self.videoBlobIDName)
        }
    }

    // MARK: VideoSize

    private func getVideoSize() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedVideoSize, forKey: Self.encryptedVideoSizeName)
            if let decryptedVideoSize {
                value = NSNumber(integerLiteral: Int(decryptedVideoSize))
            }
        }
        else {
            willAccessValue(forKey: Self.videoSizeName)
            value = primitiveValue(forKey: Self.videoSizeName) as? NSNumber
            didAccessValue(forKey: Self.videoSizeName)
        }
        return value
    }

    private func setVideoSize(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedVideoSizeName)
            decryptedVideoSize = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.videoSizeName)
            setPrimitiveValue(newValue, forKey: Self.videoSizeName)
            didChangeValue(forKey: Self.videoSizeName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedDurationName {
            decryptedDuration = nil
        }
        else if key == Self.encryptedEncryptionKeyName {
            decryptedEncryptionKey = nil
        }
        else if key == Self.encryptedVideoBlobIDName {
            decryptedVideoBlobID = nil
        }
        else if key == Self.encryptedVideoSizeName {
            decryptedVideoSize = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedDuration = nil
        decryptedEncryptionKey = nil
        decryptedVideoBlobID = nil
        decryptedVideoSize = nil
        super.didTurnIntoFault()
    }
}
