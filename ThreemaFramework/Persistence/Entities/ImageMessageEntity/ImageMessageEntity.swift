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

@objc(ImageMessageEntity)
public final class ImageMessageEntity: BaseMessageEntity {

    enum Field: String {
        case image
        case imageBlobID

        static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .image:
                field.rawValue
            case .imageBlobID:
                encrypted ? encryptedImageBlobIDName : imageBlobIDName
            }
        }
    }

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var encryptionKey: Data? {
        get {
            getEncryptionKey()
        }

        set {
            setEncryptionKey(newValue)
        }
    }

    @EncryptedField(name: "imageBlobId")
    // swiftformat:disable:next acronyms
    @objc(imageBlobId) public dynamic var imageBlobID: Data? {
        get {
            getImageBlobID()
        }

        set {
            setImageBlobID(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var imageNonce: Data? {
        get {
            getImageNonce()
        }

        set {
            setImageNonce(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var imageSize: NSNumber? {
        get {
            getImageSize()
        }

        set {
            setImageSize(newValue)
        }
    }

    @NSManaged public var progress: NSNumber?

    // MARK: Relationships

    @NSManaged public var image: ImageDataEntity?
    @NSManaged public var thumbnail: ImageDataEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedEncryptionKey: Data?
    private var decryptedImageBlobID: Data?
    private var decryptedImageNonce: Data?
    private var decryptedImageSize: Int32?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - encryptionKey: Key the image data is encrypted with
    ///   - imageBlobID: BlobID of the image data
    ///   - imageNonce: Nonce of the image
    ///   - imageSize: Size of the image data
    ///   - progress: Progress
    ///   - image: `ImageDataEntity` of the image
    ///   - thumbnail: `ImageDataEntity` of the thumbnail
    ///   - conversation: Conversation the message belongs to
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        encryptionKey: Data? = nil,
        imageBlobID: Data? = nil,
        imageNonce: Data? = nil,
        imageSize: NSNumber? = nil,
        progress: NSNumber? = nil,
        image: ImageDataEntity? = nil,
        thumbnail: ImageDataEntity? = nil,
        conversation: ConversationEntity,
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "ImageMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)

        setEncryptionKey(encryptionKey)
        setImageBlobID(imageBlobID)
        setImageNonce(imageNonce)
        setImageSize(imageSize)

        if let progress {
            self.progress = progress as NSNumber
        }

        self.image = image
        self.thumbnail = thumbnail
    }

    @available(*, unavailable)
    init() {
        fatalError("\(#function) not implemented")
    }

    @available(*, unavailable)
    convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }

    // MARK: - Custom get/set functions

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

    // MARK: ImageBlobID

    private func getImageBlobID() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedImageBlobID, forKey: Self.encryptedImageBlobIDName)
            value = decryptedImageBlobID
        }
        else {
            willAccessValue(forKey: Self.imageBlobIDName)
            value = primitiveValue(forKey: Self.imageBlobIDName) as? Data
            didAccessValue(forKey: Self.imageBlobIDName)
        }
        return value
    }

    private func setImageBlobID(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedImageBlobIDName)
            decryptedImageBlobID = newValue
        }
        else {
            willChangeValue(forKey: Self.imageBlobIDName)
            setPrimitiveValue(newValue, forKey: Self.imageBlobIDName)
            didChangeValue(forKey: Self.imageBlobIDName)
        }
    }

    // MARK: ImageNonce

    private func getImageNonce() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedImageNonce, forKey: Self.encryptedImageNonceName)
            value = decryptedImageNonce
        }
        else {
            willAccessValue(forKey: Self.imageNonceName)
            value = primitiveValue(forKey: Self.imageNonceName) as? Data
            didAccessValue(forKey: Self.imageNonceName)
        }
        return value
    }

    private func setImageNonce(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedImageNonceName)
            decryptedImageNonce = newValue
        }
        else {
            willChangeValue(forKey: Self.imageNonceName)
            setPrimitiveValue(newValue, forKey: Self.imageNonceName)
            didChangeValue(forKey: Self.imageNonceName)
        }
    }

    // MARK: ImageSize

    private func getImageSize() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedImageSize, forKey: Self.encryptedImageSizeName)
            if let decryptedImageSize {
                value = NSNumber(integerLiteral: Int(decryptedImageSize))
            }
        }
        else {
            willAccessValue(forKey: Self.imageSizeName)
            value = primitiveValue(forKey: Self.imageSizeName) as? NSNumber
            didAccessValue(forKey: Self.imageSizeName)
        }
        return value
    }

    private func setImageSize(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedImageSizeName)
            decryptedImageSize = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.imageSizeName)
            setPrimitiveValue(newValue, forKey: Self.imageSizeName)
            didChangeValue(forKey: Self.imageSizeName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedEncryptionKeyName {
            decryptedEncryptionKey = nil
        }
        else if key == Self.encryptedImageBlobIDName {
            decryptedImageBlobID = nil
        }
        else if key == Self.encryptedImageNonceName {
            decryptedImageNonce = nil
        }
        else if key == Self.encryptedImageSizeName {
            decryptedImageSize = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedEncryptionKey = nil
        decryptedImageBlobID = nil
        decryptedImageNonce = nil
        decryptedImageSize = nil
        super.didTurnIntoFault()
    }
}
