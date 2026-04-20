import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaMacros

@objc(TextMessageEntity)
public final class TextMessageEntity: BaseMessageEntity {

    // MARK: Attributes

    @EncryptedField(name: "quotedMessageId")
    // swiftformat:disable:next acronyms
    @objc(quotedMessageId) public dynamic var quotedMessageID: Data? {
        get {
            getQuotedMessageID()
        }
        set {
            setQuotedMessageID(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var text: String {
        get {
            getText()
        }
        set {
            setText(newValue)
        }
    }

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedQuotedMessageID: Data?
    private var decryptedText: String? // Non optional

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - text: Text of text message
    ///   - quotedMessageID: ID of message that was quotes if any
    ///   - conversation: Conversation the message belongs to
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        text: String,
        quotedMessageID: Data? = nil,
        conversation: ConversationEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "TextMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)

        setText(text)
        setQuotedMessageID(quotedMessageID)
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

    // MARK: QuotedMessageID

    private func getQuotedMessageID() -> Data? {
        var value: Data? = nil
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedQuotedMessageID, forKey: Self.encryptedQuotedMessageIDName)
            value = decryptedQuotedMessageID
        }
        else {
            willAccessValue(forKey: Self.quotedMessageIDName)
            value = primitiveValue(forKey: Self.quotedMessageIDName) as? Data
            didAccessValue(forKey: Self.quotedMessageIDName)
        }
        return value
    }

    private func setQuotedMessageID(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedQuotedMessageIDName)
            decryptedQuotedMessageID = newValue
        }
        else {
            willChangeValue(forKey: Self.quotedMessageIDName)
            setPrimitiveValue(newValue, forKey: Self.quotedMessageIDName)
            didChangeValue(forKey: Self.quotedMessageIDName)
        }
    }

    // MARK: Text

    private func getText() -> String {
        var value = "" // Default value
        guard let managedObjectContext,
              !willBeDeleted,
              !wasDeleted
        else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedText, forKey: Self.encryptedTextName)
            if let decryptedText {
                value = decryptedText
            }
        }
        else {
            willAccessValue(forKey: Self.textName)
            value = primitiveValue(forKey: Self.textName) as? String ?? value
            didAccessValue(forKey: Self.textName)
        }
        return value
    }

    private func setText(_ newValue: String) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedTextName)
            decryptedText = newValue
        }
        else {
            willChangeValue(forKey: Self.textName)
            setPrimitiveValue(newValue, forKey: Self.textName)
            didChangeValue(forKey: Self.textName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedQuotedMessageIDName {
            decryptedQuotedMessageID = nil
        }
        else if key == Self.encryptedTextName {
            decryptedText = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedQuotedMessageID = nil
        decryptedText = nil
        super.didTurnIntoFault()
    }
}
