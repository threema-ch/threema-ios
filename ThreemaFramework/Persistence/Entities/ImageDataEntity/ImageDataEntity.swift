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

@objc(ImageDataEntity)
public final class ImageDataEntity: ThreemaManagedObject {

    enum Field: String {
        case data

        static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .data:
                encrypted ? encryptedDataName : dataName
            }
        }
    }

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var data: Data {
        get {
            getData()
        }
        set {
            setData(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var height: Int16 {
        get {
            getHeight()
        }
        set {
            setHeight(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var width: Int16 {
        get {
            getWidth()
        }
        set {
            setWidth(newValue)
        }
    }

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedData: Data? // Non optional
    private var decryptedHeight: Int16? // Non optional
    private var decryptedWidth: Int16? // Non optional

    // MARK: Relationships

    @NSManaged public var message: ImageMessageEntity?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - data: `Data` for the entity
    ///   - height: Height of the underlying image
    ///   - width: Width of the underlying image
    ///   - message: `ImageMessageEntity` the entity belongs to
    init(
        context: NSManagedObjectContext,
        data: Data,
        height: Int16,
        width: Int16,
        message: ImageMessageEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "ImageData", in: context)!
        super.init(entity: entity, insertInto: context)

        setData(data)
        setHeight(height)
        setWidth(width)

        self.message = message
    }

    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
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

    // MARK: Data

    private func getData() -> Data {
        var value = Data()
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedData, forKey: Self.encryptedDataName)
            if let decryptedData {
                value = decryptedData
            }
        }
        else {
            willAccessValue(forKey: Self.dataName)
            value = primitiveValue(forKey: Self.dataName) as? Data ?? value
            didAccessValue(forKey: Self.dataName)
        }
        return value
    }

    private func setData(_ newValue: Data) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedDataName)
            decryptedData = newValue
        }
        else {
            willChangeValue(forKey: Self.dataName)
            setPrimitiveValue(newValue, forKey: Self.dataName)
            didChangeValue(forKey: Self.dataName)
        }
    }

    // MARK: Height

    private func getHeight() -> Int16 {
        var value: Int16 = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedHeight, forKey: Self.encryptedHeightName)
            if let decryptedHeight {
                value = decryptedHeight
            }
        }
        else {
            willAccessValue(forKey: Self.heightName)
            value = primitiveValue(forKey: Self.heightName) as? Int16 ?? value
            didAccessValue(forKey: Self.heightName)
        }
        return value
    }

    private func setHeight(_ newValue: Int16) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedHeightName)
            decryptedHeight = newValue
        }
        else {
            willChangeValue(forKey: Self.heightName)
            setPrimitiveValue(newValue, forKey: Self.heightName)
            didChangeValue(forKey: Self.heightName)
        }
    }

    // MARK: Width

    private func getWidth() -> Int16 {
        var value: Int16 = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedWidth, forKey: Self.encryptedWidthName)
            if let decryptedWidth {
                value = decryptedWidth
            }
        }
        else {
            willAccessValue(forKey: Self.widthName)
            value = primitiveValue(forKey: Self.widthName) as? Int16 ?? value
            didAccessValue(forKey: Self.widthName)
        }
        return value
    }

    private func setWidth(_ newValue: Int16) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedWidthName)
            decryptedWidth = newValue
        }
        else {
            willChangeValue(forKey: Self.widthName)
            setPrimitiveValue(newValue, forKey: Self.widthName)
            didChangeValue(forKey: Self.widthName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedDataName {
            decryptedData = nil
        }
        else if key == Self.encryptedHeightName {
            decryptedHeight = nil
        }
        else if key == Self.encryptedWidthName {
            decryptedWidth = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedData = nil
        decryptedHeight = nil
        decryptedWidth = nil
        super.didTurnIntoFault()
    }
}
