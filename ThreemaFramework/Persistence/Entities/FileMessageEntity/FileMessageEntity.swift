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

import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaMacros

@objc(FileMessageEntity)
public final class FileMessageEntity: BaseMessageEntity {

    public enum FileMessageBaseType: Int {
        // Default file message
        case file = 0
        // Media file message (e.g. image or audio message)
        case media = 1
        // Sticker (for transparent images), typically rendered without a bubble
        case sticker = 2
    }

    private struct FileMessageMetadataJSON: Codable {
        var height: Int?
        var width: Int?
        var duration: Double?

        enum CodingKeys: String, CodingKey {
            case height = "h"
            case width = "w"
            case duration = "d"
        }
    }

    private struct FileMessageJSON: Codable {
        var correlationID: String?
        var mimeTypeThumbnail: String?
        var description: String?
        var metadata: FileMessageMetadataJSON?

        enum CodingKeys: String, CodingKey {
            case correlationID = "c"
            case mimeTypeThumbnail = "p"
            case description = "d"
            case metadata = "x"
        }
    }

    enum Field: String {
        case blobID
        case data
        case mimeType

        static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .blobID:
                encrypted ? encryptedBlobIDName : blobIDName
            case .data:
                field.rawValue
            case .mimeType:
                encrypted ? encryptedMimeTypeName : mimeTypeName
            }
        }
    }

    // MARK: Attributes

    @EncryptedField(name: "blobId")
    // swiftformat:disable acronyms
    @objc(blobId) public dynamic var blobID: Data? {
        get {
            getBlobID()
        }

        set {
            setBlobID(newValue)
        }
    }

    @EncryptedField(name: "blobThumbnailId")
    // swiftformat:disable acronyms
    @objc(blobThumbnailId) public dynamic var blobThumbnailID: Data? {
        get {
            getBlobThumbnailID()
        }

        set {
            setBlobThumbnailID(newValue)
        }
    }

    // swiftformat:enable acronyms
    @EncryptedField
    @objc public dynamic var caption: String? {
        get {
            getCaption()
        }

        set {
            setCaption(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var consumed: Date? {
        get {
            getConsumed()
        }

        set {
            setConsumed(newValue)
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

    @EncryptedField
    @objc public dynamic var fileName: String? {
        get {
            getFileName()
        }

        set {
            setFileName(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var fileSize: NSNumber? {
        get {
            getFileSize()
        }

        set {
            setFileSize(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var json: String? {
        get {
            getJson()
        }

        set {
            setJson(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var mimeType: String? {
        get {
            getMimeType()
        }

        set {
            setMimeType(newValue)
        }
    }

    @NSManaged public var origin: NSNumber?
    @NSManaged public var progress: NSNumber?

    @EncryptedField
    @objc public dynamic var type: NSNumber? {
        get {
            getType()
        }

        set {
            setType(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var data: FileDataEntity?
    @NSManaged public var thumbnail: ImageDataEntity?

    // MARK: Private properties
   
    private lazy var jsonDecoder = JSONDecoder()
    private lazy var jsonEncoder = JSONEncoder()

    // Cached decrypted values
    private var decryptedBlobID: Data?
    private var decryptedBlobThumbnailID: Data?
    private var decryptedCaption: String?
    private var decryptedConsumed: Date?
    private var decryptedEncryptionKey: Data?
    private var decryptedFileName: String?
    private var decryptedFileSize: Int32?
    private var decryptedJson: String?
    private var decryptedMimeType: String?
    private var decryptedType: Int16?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - blobID: BlobID of the file data
    ///   - blobThumbnailID: BlobID of the thumbnail data
    ///   - caption: Caption describing the data
    ///   - consumed: Has the file been consumed?
    ///   - encryptionKey: Key the file data is encrypted with
    ///   - fileName: Name of the file
    ///   - fileSize: Size of the file
    ///   - json: JSON where additional info is stored in
    ///   - mimeType: MIME type of the data
    ///   - origin: Origin of the blob
    ///   - progress: Download progress of the data
    ///   - type: Type of the file
    ///   - conversation: Conversation the message belongs to
    ///   - thumbnail: Thumbnail of the data
    ///   - data: Data of the file
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        blobID: Data? = nil,
        blobThumbnailID: Data? = nil,
        caption: String? = nil,
        consumed: Date? = nil,
        encryptionKey: Data? = nil,
        fileName: String? = nil,
        fileSize: NSNumber? = nil,
        json: String? = nil,
        mimeType: String? = nil,
        origin: NSNumber? = nil,
        progress: NSNumber? = nil,
        type: NSNumber? = nil,
        conversation: ConversationEntity,
        thumbnail: ImageDataEntity? = nil,
        data: FileDataEntity? = nil,
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FileMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)

        setBlobID(blobID)
        setBlobThumbnailID(blobThumbnailID)
        setCaption(caption)
        setConsumed(consumed)
        setEncryptionKey(encryptionKey)
        setFileName(fileName)
        setFileSize(fileSize)
        setJson(json)
        setMimeType(mimeType)
        self.origin = origin
        if let progress {
            self.progress = progress as NSNumber
        }
        setType(type)

        self.thumbnail = thumbnail
        self.data = data
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

    // MARK: BlobID

    private func getBlobID() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedBlobID, forKey: Self.encryptedBlobIDName)
            value = decryptedBlobID
        }
        else {
            willAccessValue(forKey: Self.blobIDName)
            value = primitiveValue(forKey: Self.blobIDName) as? Data
            didAccessValue(forKey: Self.blobIDName)
        }

        return value
    }

    private func setBlobID(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedBlobIDName)
            decryptedBlobID = newValue
        }
        else {
            willChangeValue(forKey: Self.blobIDName)
            setPrimitiveValue(newValue, forKey: Self.blobIDName)
            didChangeValue(forKey: Self.blobIDName)
        }
    }

    // MARK: BlobThumbnailID

    private func getBlobThumbnailID() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(
                &decryptedBlobThumbnailID,
                forKey: Self.encryptedBlobThumbnailIDName
            )
            value = decryptedBlobThumbnailID
        }
        else {
            willAccessValue(forKey: Self.blobThumbnailIDName)
            value = primitiveValue(forKey: Self.blobThumbnailIDName) as? Data
            didAccessValue(forKey: Self.blobThumbnailIDName)
        }
        return value
    }

    private func setBlobThumbnailID(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedBlobThumbnailIDName)
            decryptedBlobThumbnailID = newValue
        }
        else {
            willChangeValue(forKey: Self.blobThumbnailIDName)
            setPrimitiveValue(newValue, forKey: Self.blobThumbnailIDName)
            didChangeValue(forKey: Self.blobThumbnailIDName)
        }
    }

    // MARK: Caption

    private func getCaption() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedCaption, forKey: Self.encryptedCaptionName)
            value = decryptedCaption
        }
        else {
            willAccessValue(forKey: Self.captionName)
            value = primitiveValue(forKey: Self.captionName) as? String
            didAccessValue(forKey: Self.captionName)
        }
        return value
    }

    private func setCaption(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedCaptionName)
            decryptedCaption = newValue
        }
        else {
            willChangeValue(forKey: Self.captionName)
            setPrimitiveValue(newValue, forKey: Self.captionName)
            didChangeValue(forKey: Self.captionName)
        }
    }

    // MARK: Consumed

    private func getConsumed() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedConsumed, forKey: Self.encryptedConsumedName)
            value = decryptedConsumed
        }
        else {
            willAccessValue(forKey: Self.consumedName)
            value = primitiveValue(forKey: Self.consumedName) as? Date
            didAccessValue(forKey: Self.consumedName)
        }
        return value
    }

    private func setConsumed(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedConsumedName)
            decryptedConsumed = newValue
        }
        else {
            willChangeValue(forKey: Self.consumedName)
            setPrimitiveValue(newValue, forKey: Self.consumedName)
            didChangeValue(forKey: Self.consumedName)
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

    // MARK: FileName

    private func getFileName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedFileName, forKey: Self.encryptedFileNameName)
            value = decryptedFileName
        }
        else {
            willAccessValue(forKey: Self.fileNameName)
            value = primitiveValue(forKey: Self.fileNameName) as? String
            didAccessValue(forKey: Self.fileNameName)
        }
        return value
    }

    private func setFileName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedFileNameName)
            decryptedFileName = newValue
        }
        else {
            willChangeValue(forKey: Self.fileNameName)
            setPrimitiveValue(newValue, forKey: Self.fileNameName)
            didChangeValue(forKey: Self.fileNameName)
        }
    }

    // MARK: FileSize

    private func getFileSize() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return nil
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedFileSize, forKey: Self.encryptedFileSizeName)
            if let decryptedFileSize {
                value = NSNumber(integerLiteral: Int(decryptedFileSize))
            }
        }
        else {
            willAccessValue(forKey: Self.fileSizeName)
            value = primitiveValue(forKey: Self.fileSizeName) as? NSNumber
            didAccessValue(forKey: Self.fileSizeName)
        }
        return value
    }

    private func setFileSize(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedFileSizeName)
            decryptedFileSize = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.fileSizeName)
            setPrimitiveValue(newValue, forKey: Self.fileSizeName)
            didChangeValue(forKey: Self.fileSizeName)
        }
    }

    // MARK: JSON

    private func getJson() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedJson, forKey: Self.encryptedJsonName)
            value = decryptedJson
        }
        else {
            willAccessValue(forKey: Self.jsonName)
            value = primitiveValue(forKey: Self.jsonName) as? String
            didAccessValue(forKey: Self.jsonName)
        }
        return value
    }

    private func setJson(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedJsonName)
            decryptedJson = newValue
        }
        else {
            willChangeValue(forKey: Self.jsonName)
            setPrimitiveValue(newValue, forKey: Self.jsonName)
            didChangeValue(forKey: Self.jsonName)
        }
    }

    // MARK: MimeType

    private func getMimeType() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedMimeType, forKey: Self.encryptedMimeTypeName)
            value = decryptedMimeType
        }
        else {
            willAccessValue(forKey: Self.mimeTypeName)
            value = primitiveValue(forKey: Self.mimeTypeName) as? String
            didAccessValue(forKey: Self.mimeTypeName)
        }
        return value
    }

    private func setMimeType(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedMimeTypeName)
            decryptedMimeType = newValue
        }
        else {
            willChangeValue(forKey: Self.mimeTypeName)
            setPrimitiveValue(newValue, forKey: Self.mimeTypeName)
            didChangeValue(forKey: Self.mimeTypeName)
        }
    }

    // MARK: Type

    private func getType() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedType, forKey: Self.encryptedTypeName)
            if let decryptedType {
                value = NSNumber(integerLiteral: Int(decryptedType))
            }
        }
        else {
            willAccessValue(forKey: Self.typeName)
            value = primitiveValue(forKey: Self.typeName) as? NSNumber
            didAccessValue(forKey: Self.typeName)
        }
        return value
    }

    private func setType(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedTypeName)
            decryptedType = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.typeName)
            setPrimitiveValue(newValue, forKey: Self.typeName)
            didChangeValue(forKey: Self.typeName)
        }
    }

    // MARK: - Properties

    @objc public var correlationID: String? {
        get {
            decodeJsonObjectFromJson()?.correlationID
        }
        set {
            if var jsonObject = decodeJsonObjectFromJson() {
                jsonObject.correlationID = newValue
                json = encodeJsonObjectToJson(jsonObject: jsonObject)
            }
        }
    }

    @objc public var mimeTypeThumbnail: String? {
        get {
            decodeJsonObjectFromJson()?.mimeTypeThumbnail
        }
        set {
            if var jsonObject = decodeJsonObjectFromJson() {
                jsonObject.mimeTypeThumbnail = newValue
                json = encodeJsonObjectToJson(jsonObject: jsonObject)
            }
        }
    }

    public var height: Int? {
        get {
            decodeJsonObjectFromJson()?.metadata?.height
        }
        set {
            if var jsonObject = decodeJsonObjectFromJson() {
                jsonObject.metadata?.height = newValue
                json = encodeJsonObjectToJson(jsonObject: jsonObject)
            }
        }
    }

    @objc public lazy var heightObjc: NSNumber? = height as? NSNumber

    public var width: Int? {
        get {
            decodeJsonObjectFromJson()?.metadata?.width
        }
        set {
            if var jsonObject = decodeJsonObjectFromJson() {
                jsonObject.metadata?.width = newValue
                json = encodeJsonObjectToJson(jsonObject: jsonObject)
            }
        }
    }

    @objc public lazy var widthObjc: NSNumber? = width as? NSNumber

    public var duration: Double? {
        get {
            decodeJsonObjectFromJson()?.metadata?.duration
        }
        set {
            if var jsonObject = decodeJsonObjectFromJson() {
                jsonObject.metadata?.duration = newValue
                json = encodeJsonObjectToJson(jsonObject: jsonObject)
            }
        }
    }

    @available(*, deprecated, renamed: "caption")
    public var jsonDescription: String? {
        decodeJsonObjectFromJson()?.description
    }

    @objc public lazy var durationObjc: NSNumber? = duration as? NSNumber

    // MARK: Public functions

    override public func contentToCheckForMentions() -> String? {
        caption
    }

    #if !DEBUG
        override public var debugDescription: String {
            "<\(Swift.type(of: self))>:\(Self.self), encryptionKey = ***, blobId = ***, blobThumbnailID = ****, fileName = \(fileName?.description ?? "nil"), progress = \(progress?.description ?? "nil"), type = \(type?.description ?? "nil"), mimeType = \(mimeType?.description ?? "nil"), data = \(data?.description ?? "nil"), thumbnail = \(thumbnail?.description ?? "nil"), json = ****,"
        }
    #endif

    private func decodeJsonObjectFromJson() -> FileMessageJSON? {
        guard let json else {
            return FileMessageJSON(metadata: FileMessageMetadataJSON())
        }

        do {
            let jsonData = Data(json.utf8)
            return try jsonDecoder.decode(FileMessageJSON.self, from: jsonData)
        }
        catch {
            DDLogError("[FileMessageEntity] Failed to decode JSON.")
            return nil
        }
    }

    private func encodeJsonObjectToJson(jsonObject: FileMessageJSON) -> String? {
        do {
            let jsonData = try jsonEncoder.encode(jsonObject)
            return String(data: jsonData, encoding: .utf8)
        }
        catch {
            DDLogError("[FileMessageEntity] Failed to encode JSON.")
            return nil
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedBlobIDName {
            decryptedBlobID = nil
        }
        else if key == Self.encryptedBlobThumbnailIDName {
            decryptedBlobThumbnailID = nil
        }
        else if key == Self.encryptedCaptionName {
            decryptedCaption = nil
        }
        else if key == Self.encryptedConsumedName {
            decryptedConsumed = nil
        }
        else if key == Self.encryptedEncryptionKeyName {
            decryptedEncryptionKey = nil
        }
        else if key == Self.encryptedFileNameName {
            decryptedFileName = nil
        }
        else if key == Self.encryptedFileSizeName {
            decryptedFileSize = nil
        }
        else if key == Self.encryptedJsonName {
            decryptedJson = nil
        }
        else if key == Self.encryptedMimeTypeName {
            decryptedMimeType = nil
        }
        else if key == Self.encryptedTypeName {
            decryptedType = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedBlobID = nil
        decryptedBlobThumbnailID = nil
        decryptedCaption = nil
        decryptedConsumed = nil
        decryptedEncryptionKey = nil
        decryptedFileName = nil
        decryptedFileSize = nil
        decryptedJson = nil
        decryptedMimeType = nil
        decryptedType = nil
        super.didTurnIntoFault()
    }
}
