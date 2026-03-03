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

@objc(MessageReactionEntity)
public final class MessageReactionEntity: ThreemaManagedObject {

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var reaction: String {
        get {
            getReaction()
        }

        set {
            setReaction(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var date: Date {
        get {
            getDate()
        }

        set {
            setDate(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var message: BaseMessageEntity
    @NSManaged public var creator: ContactEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedDate: Date? // Non optional
    private var decryptedReaction: String? // Non optional

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - creator: The `ContactEntity` of the creator of the reaction, nil if we reacted
    ///   - reaction: The string of the reaction itself, e.g. the emoji
    ///   - message: `BaseMessageEntity` the entity belongs to
    init(
        context: NSManagedObjectContext,
        date: Date = Date(),
        reaction: String,
        contact: ContactEntity? = nil,
        message: BaseMessageEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "MessageReaction", in: context)!
        super.init(entity: entity, insertInto: context)

        setDate(date)
        setReaction(reaction)

        self.message = message
        self.creator = contact
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

    // MARK: Date

    private func getDate() -> Date {
        var value: Date = .now
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedDate, forKey: Self.encryptedDateName)
            if let decryptedDate {
                value = decryptedDate
            }
        }
        else {
            willAccessValue(forKey: Self.dateName)
            value = primitiveValue(forKey: Self.dateName) as! Date
            didAccessValue(forKey: Self.dateName)
        }
        return value
    }

    private func setDate(_ newValue: Date) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedDateName)
            decryptedDate = newValue
        }
        else {
            willChangeValue(forKey: Self.dateName)
            setPrimitiveValue(newValue, forKey: Self.dateName)
            didChangeValue(forKey: Self.dateName)
        }
    }

    // MARK: Reaction

    private func getReaction() -> String {
        var value = ""
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedReaction, forKey: Self.encryptedReactionName)
            if let decryptedReaction {
                value = decryptedReaction
            }
        }
        else {
            willAccessValue(forKey: Self.reactionName)
            value = primitiveValue(forKey: Self.reactionName) as! String
            didAccessValue(forKey: Self.reactionName)
        }
        return value
    }

    private func setReaction(_ newValue: String) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedReactionName)
            decryptedReaction = newValue
        }
        else {
            willChangeValue(forKey: Self.reactionName)
            setPrimitiveValue(newValue, forKey: Self.reactionName)
            didChangeValue(forKey: Self.reactionName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedDateName {
            decryptedDate = nil
        }
        else if key == Self.encryptedReactionName {
            decryptedReaction = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedDate = nil
        decryptedReaction = nil
        super.didTurnIntoFault()
    }
}
