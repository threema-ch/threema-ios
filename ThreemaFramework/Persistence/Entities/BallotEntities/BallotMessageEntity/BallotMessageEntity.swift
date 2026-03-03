//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

@objc(BallotMessageEntity)
public final class BallotMessageEntity: BaseMessageEntity {

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var ballotState: NSNumber? {
        get {
            getBallotState()
        }
        
        set {
            setBallotState(newValue)
        }
    }
    
    // MARK: Relationships

    @NSManaged public var ballot: BallotEntity?
    
    // MARK: Private properties
    
    // Cached decrypted values
    private var decryptedBallotState: Int16?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - ballotState: State of the ballot
    ///   - ballot: `BallotEntity` the entity belongs to
    ///   - conversation: Conversation the message belongs to
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        ballotState: NSNumber? = nil,
        ballot: BallotEntity? = nil,
        conversation: ConversationEntity,
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BallotMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)
        
        setBallotState(ballotState)
        
        self.ballot = ballot
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

    // MARK: BallotState

    private func getBallotState() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedBallotState, forKey: Self.encryptedBallotStateName)
            if let decryptedBallotState {
                value = NSNumber(integerLiteral: Int(decryptedBallotState))
            }
        }
        else {
            willAccessValue(forKey: Self.ballotStateName)
            value = primitiveValue(forKey: Self.ballotStateName) as? NSNumber
            didAccessValue(forKey: Self.ballotStateName)
        }
        return value
    }
    
    private func setBallotState(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }
        
        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int16Value, forKey: Self.encryptedBallotStateName)
            decryptedBallotState = newValue?.int16Value
        }
        else {
            willChangeValue(forKey: Self.ballotStateName)
            setPrimitiveValue(newValue, forKey: Self.ballotStateName)
            didChangeValue(forKey: Self.ballotStateName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedBallotStateName {
            decryptedBallotState = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedBallotState = nil
        super.didTurnIntoFault()
    }
}
