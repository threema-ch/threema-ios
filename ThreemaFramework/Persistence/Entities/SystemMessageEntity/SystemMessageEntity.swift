import CoreData
import Foundation
import ThreemaMacros

@objc(SystemMessageEntity)
public final class SystemMessageEntity: BaseMessageEntity {

    // MARK: Enums

    @objc public enum SystemMessageEntityType: Int {
        case renameGroup = 1 // The admin has renamed the group
        case groupMemberLeave = 2 // Another member has left the group
        case groupMemberAdd = 3 // The admin has added a member to the group
        case groupMemberForcedLeave = 4 // Another member was removed from the group
        case groupSelfAdded = 5 // I was added to the group
        case groupSelfRemoved = 6 // I was removed from the group
        case groupSelfLeft = 16 // I have left the group
        case groupCreatorLeft = 19 // Creator has left the group
        case startNoteGroupInfo = 17 // This is a note group without members
        case endNoteGroupInfo = 18 // This is no note group anymore
        case vote = 20
        case voteUpdated = 30
        case callMissed = 7
        case callRejected = 8
        case callRejectedBusy = 9
        case callRejectedTimeout = 10
        case callEnded = 11
        case callRejectedDisabled = 12
        case callRejectedUnknown = 13
        case contactOtherAppInfo = 14
        case callRejectedOffHours = 15
        case fsMessageWithoutForwardSecurity = 21
        case fsSessionEstablished = 22
        case fsSessionEstablishedRcvd = 23 // As of version 1.1. this status is not created anymore
        case fsMessagesSkipped = 24
        case fsSessionReset = 25
        case fsOutOfOrder = 26
        case fsEnabledOutgoing = 27
        case fsDisabledOutgoing = 28
        case fsNotSupportedAnymore = 29
        case unsupportedType = 31
        case groupProfilePictureChanged = 32
        case groupCallStartedBy = 33
        case groupCallStarted = 34
        case groupCallEnded = 35
        case fsDebugMessage = 36
        case fsIllegalSessionState = 37

        static let excludeTypesAsLastMessage: [Int] = [
            fsMessageWithoutForwardSecurity.rawValue,
            fsSessionEstablished.rawValue,
            fsSessionEstablishedRcvd.rawValue,
            fsMessagesSkipped.rawValue,
            fsSessionReset.rawValue,
            fsOutOfOrder.rawValue,
            fsEnabledOutgoing.rawValue,
            fsDisabledOutgoing.rawValue,
            fsNotSupportedAnymore.rawValue,
            fsDebugMessage.rawValue,
            fsIllegalSessionState.rawValue,

            vote.rawValue,
            voteUpdated.rawValue,
        ]
    }

    enum Field: String {
        case type

        static func name(for field: Field, encrypted: Bool) -> String {
            switch field {
            case .type:
                field.rawValue
            }
        }
    }

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var arg: Data? {
        get {
            getArg()
        }

        set {
            setArg(newValue)
        }
    }

    @NSManaged public var type: NSNumber

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedArg: Data?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - arg: Data belonging to the system message
    ///   - type: Type of system message
    ///   - conversation: Conversation the message belongs to
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        arg: Data? = nil,
        type: Int16,
        conversation: ConversationEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "SystemMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, sent: true, conversation: conversation)

        setArg(arg)
        self.type = type as NSNumber
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

    // MARK: Arg

    private func getArg() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedArg, forKey: Self.encryptedArgName)
            value = decryptedArg
        }
        else {
            willAccessValue(forKey: Self.argName)
            value = primitiveValue(forKey: Self.argName) as? Data
            didAccessValue(forKey: Self.argName)
        }
        return value
    }

    private func setArg(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedArgName)
            decryptedArg = newValue
        }
        else {
            willChangeValue(forKey: Self.argName)
            setPrimitiveValue(newValue, forKey: Self.argName)
            didChangeValue(forKey: Self.argName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedArgName {
            decryptedArg = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedArg = nil
        super.didTurnIntoFault()
    }
}
