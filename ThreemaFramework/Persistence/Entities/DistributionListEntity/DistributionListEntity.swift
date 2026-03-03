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

@objc(DistributionListEntity)
public final class DistributionListEntity: ThreemaManagedObject, Identifiable {

    // MARK: Attributes

    @NSManaged public var distributionListID: Int64

    @EncryptedField
    @objc public dynamic var name: String? {
        get {
            getName()
        }

        set {
            setName(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var conversation: ConversationEntity

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedName: String?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - distributionListID: ID of the list
    ///   - name: Name of the list
    ///   - conversation: `ConversationEntity` of the list
    init(
        context: NSManagedObjectContext,
        distributionListID: Int64,
        name: String? = nil,
        conversation: ConversationEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "DistributionList", in: context)!
        super.init(entity: entity, insertInto: context)

        self.distributionListID = distributionListID
        setName(name)

        self.conversation = conversation
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

    // MARK: Name

    private func getName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedName, forKey: Self.encryptedNameName)
            value = decryptedName
        }
        else {
            willAccessValue(forKey: Self.nameName)
            value = primitiveValue(forKey: Self.nameName) as? String
            didAccessValue(forKey: Self.nameName)
        }
        return value
    }

    private func setName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedNameName)
            decryptedName = newValue
        }
        else {
            willChangeValue(forKey: Self.nameName)
            setPrimitiveValue(newValue, forKey: Self.nameName)
            didChangeValue(forKey: Self.nameName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedNameName {
            decryptedName = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedName = nil
        super.didTurnIntoFault()
    }
}
