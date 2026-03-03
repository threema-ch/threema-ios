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

@objc(AudioDataEntity)
public final class AudioDataEntity: ThreemaManagedObject, Identifiable {

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

    // MARK: Relationships

    @NSManaged public var message: AudioMessageEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedData: Data?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - data: Data for the entity
    ///   - message: `AudioMessageEntity` the entity belongs to
    init(context: NSManagedObjectContext, data: Data, message: AudioMessageEntity? = nil) {
        let entity = NSEntityDescription.entity(forEntityName: "AudioData", in: context)!
        super.init(entity: entity, insertInto: context)

        setData(data)
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

    // MARK: - Clearing cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedDataName {
            decryptedData = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedData = nil
        super.didTurnIntoFault()
    }
}
