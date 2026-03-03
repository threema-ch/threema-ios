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

@objc(GroupEntity)
public final class GroupEntity: ThreemaManagedObject {

    // MARK: Attributes

    @NSManaged public var groupCreator: String?
    // swiftformat:disable:next acronyms
    @NSManaged @objc(groupId) public var groupID: Data

    @EncryptedField
    @objc public dynamic var lastPeriodicSync: Date? {
        get {
            getLastPeriodicSync()
        }

        set {
            setLastPeriodicSync(newValue)
        }
    }

    @NSManaged public var state: NSNumber

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedLastPeriodicSync: Date?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - groupCreator: Threema ID of the creator
    ///   - groupID: Group ID
    ///   - lastPeriodicSync: `Date` of last periodic group sync
    ///   - state: Our current state for the group
    init(
        context: NSManagedObjectContext,
        groupCreator: String? = nil,
        groupID: Data,
        lastPeriodicSync: Date? = nil,
        state: NSNumber
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Group", in: context)!
        super.init(entity: entity, insertInto: context)

        self.groupCreator = groupCreator
        self.groupID = groupID
        setLastPeriodicSync(lastPeriodicSync)
        self.state = state
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

    // MARK: LastPeriodicSync

    private func getLastPeriodicSync() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedLastPeriodicSync, forKey: Self.encryptedLastPeriodicSyncName)
            value = decryptedLastPeriodicSync
        }
        else {
            willAccessValue(forKey: Self.lastPeriodicSyncName)
            value = primitiveValue(forKey: Self.lastPeriodicSyncName) as? Date
            didAccessValue(forKey: Self.lastPeriodicSyncName)
        }
        return value
    }

    private func setLastPeriodicSync(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedLastPeriodicSyncName)
            decryptedLastPeriodicSync = newValue
        }
        else {
            willChangeValue(forKey: Self.lastPeriodicSyncName)
            setPrimitiveValue(newValue, forKey: Self.lastPeriodicSyncName)
            didChangeValue(forKey: Self.lastPeriodicSyncName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedLastPeriodicSyncName {
            decryptedLastPeriodicSync = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedLastPeriodicSync = nil
        super.didTurnIntoFault()
    }
}
