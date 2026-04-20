import CoreData
import Foundation
import ThreemaMacros

@objc(GroupCallEntity)
public final class GroupCallEntity: ThreemaManagedObject, Identifiable {

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var gck: Data? {
        get {
            getGck()
        }

        set {
            setGck(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var protocolVersion: NSNumber? {
        get {
            getProtocolVersion()
        }

        set {
            setProtocolVersion(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var sfuBaseURL: String? {
        get {
            getSfuBaseURL()
        }

        set {
            setSfuBaseURL(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var startMessageReceiveDate: Date? {
        get {
            getStartMessageReceiveDate()
        }

        set {
            setStartMessageReceiveDate(newValue)
        }
    }

    // MARK: Relationships

    @NSManaged public var group: GroupEntity?

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedGck: Data?
    private var decryptedProtocolVersion: Int32?
    private var decryptedSfuBaseURL: String?
    private var decryptedStartMessageReceiveDate: Date?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - gck: Group call key
    ///   - protocolVersion: Version of the protocol
    ///   - sfuBaseURL: String of group call base URL
    ///   - startMessageReceiveDate: `Date` the start message was received
    ///   - group: `GroupEntity` of the group the start message was received in
    init(
        context: NSManagedObjectContext,
        gck: Data? = nil,
        protocolVersion: Int32? = nil,
        sfuBaseURL: String? = nil,
        startMessageReceiveDate: Date? = nil,
        group: GroupEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "GroupCallEntity", in: context)!
        super.init(entity: entity, insertInto: context)

        setGck(gck)
        if let protocolVersion {
            setProtocolVersion(protocolVersion as NSNumber)
        }
        setSfuBaseURL(sfuBaseURL)
        setStartMessageReceiveDate(startMessageReceiveDate)

        self.group = group
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

    // MARK: Gck

    private func getGck() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedGck, forKey: Self.encryptedGckName)
            value = decryptedGck
        }
        else {
            willAccessValue(forKey: Self.gckName)
            value = primitiveValue(forKey: Self.gckName) as? Data
            didAccessValue(forKey: Self.gckName)
        }
        return value
    }

    private func setGck(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedGckName)
            decryptedGck = newValue
        }
        else {
            willChangeValue(forKey: Self.gckName)
            setPrimitiveValue(newValue, forKey: Self.gckName)
            didChangeValue(forKey: Self.gckName)
        }
    }

    // MARK: ProtocolVersion

    private func getProtocolVersion() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedProtocolVersion, forKey: Self.encryptedProtocolVersionName)
            if let decryptedProtocolVersion {
                value = NSNumber(integerLiteral: Int(decryptedProtocolVersion))
            }
        }
        else {
            willAccessValue(forKey: Self.protocolVersionName)
            value = primitiveValue(forKey: Self.protocolVersionName) as? NSNumber
            didAccessValue(forKey: Self.protocolVersionName)
        }
        return value
    }

    private func setProtocolVersion(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedProtocolVersionName)
            decryptedProtocolVersion = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.protocolVersionName)
            setPrimitiveValue(newValue, forKey: Self.protocolVersionName)
            didChangeValue(forKey: Self.protocolVersionName)
        }
    }

    // MARK: SfuBaseURL

    private func getSfuBaseURL() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedSfuBaseURL, forKey: Self.encryptedSfuBaseURLName)
            value = decryptedSfuBaseURL
        }
        else {
            willAccessValue(forKey: Self.sfuBaseURLName)
            value = primitiveValue(forKey: Self.sfuBaseURLName) as? String
            didAccessValue(forKey: Self.sfuBaseURLName)
        }
        return value
    }

    private func setSfuBaseURL(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedSfuBaseURLName)
            decryptedSfuBaseURL = newValue
        }
        else {
            willChangeValue(forKey: Self.sfuBaseURLName)
            setPrimitiveValue(newValue, forKey: Self.sfuBaseURLName)
            didChangeValue(forKey: Self.sfuBaseURLName)
        }
    }

    // MARK: StartMessageReceiveDate

    private func getStartMessageReceiveDate() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedStartMessageReceiveDate, forKey: Self.encryptedStartMessageReceiveDateName)
            value = decryptedStartMessageReceiveDate
        }
        else {
            willAccessValue(forKey: Self.startMessageReceiveDateName)
            value = primitiveValue(forKey: Self.startMessageReceiveDateName) as? Date
            didAccessValue(forKey: Self.startMessageReceiveDateName)
        }
        return value
    }

    private func setStartMessageReceiveDate(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedStartMessageReceiveDateName)
            decryptedStartMessageReceiveDate = newValue
        }
        else {
            willChangeValue(forKey: Self.startMessageReceiveDateName)
            setPrimitiveValue(newValue, forKey: Self.startMessageReceiveDateName)
            didChangeValue(forKey: Self.startMessageReceiveDateName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedGckName {
            decryptedGck = nil
        }
        else if key == Self.encryptedProtocolVersionName {
            decryptedProtocolVersion = nil
        }
        else if key == Self.encryptedSfuBaseURLName {
            decryptedSfuBaseURL = nil
        }
        else if key == Self.encryptedStartMessageReceiveDateName {
            decryptedStartMessageReceiveDate = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedGck = nil
        decryptedProtocolVersion = nil
        decryptedSfuBaseURL = nil
        decryptedStartMessageReceiveDate = nil
        super.didTurnIntoFault()
    }
}
