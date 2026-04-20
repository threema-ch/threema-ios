import CoreData
import Foundation
import ThreemaMacros

@objc(LocationMessageEntity)
public final class LocationMessageEntity: BaseMessageEntity {

    // MARK: Attributes

    @EncryptedField
    @objc public dynamic var accuracy: NSNumber? {
        get {
            getAccuracy()
        }

        set {
            setAccuracy(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var latitude: NSNumber {
        get {
            getLatitude()
        }

        set {
            setLatitude(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var longitude: NSNumber {
        get {
            getLongitude()
        }

        set {
            setLongitude(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var poiAddress: String? {
        get {
            getPoiAddress()
        }

        set {
            setPoiAddress(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var poiName: String? {
        get {
            getPoiName()
        }

        set {
            setPoiName(newValue)
        }
    }

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedAccuracy: Double?
    private var decryptedLatitude: Double? // Non optional
    private var decryptedLongitude: Double? // Non optional
    private var decryptedPoiAddress: String?
    private var decryptedPoiName: String?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - id: Message ID
    ///   - isOwn: Did I send the message?
    ///   - accuracy: Accuracy of the POI
    ///   - latitude: Latitude of the POI
    ///   - longitude: Longitude of the POI
    ///   - poiAddress: Address of the POI
    ///   - poiName: Name of the POI
    ///   - conversation: Conversation the message belongs to
    init(
        context: NSManagedObjectContext,
        id: Data,
        isOwn: Bool,
        accuracy: Double? = nil,
        latitude: Double,
        longitude: Double,
        poiAddress: String? = nil,
        poiName: String? = nil,
        conversation: ConversationEntity,
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "LocationMessage", in: context)!
        super.init(entity: entity, insertInto: context, id: id, isOwn: isOwn, conversation: conversation)

        if let accuracy {
            setAccuracy(accuracy as NSNumber)
        }
        setLatitude(latitude as NSNumber)
        setLongitude(longitude as NSNumber)
        setPoiAddress(poiAddress)
        setPoiName(poiName)
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

    // MARK: Accuracy

    private func getAccuracy() -> NSNumber? {
        guard let managedObjectContext else {
            return nil
        }

        var value: NSNumber?
        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedAccuracy, forKey: Self.encryptedAccuracyName)
            value = decryptedAccuracy as? NSNumber
        }
        else {
            willAccessValue(forKey: Self.accuracyName)
            value = primitiveValue(forKey: Self.accuracyName) as? NSNumber
            didAccessValue(forKey: Self.accuracyName)
        }
        return value
    }

    private func setAccuracy(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.doubleValue, forKey: Self.encryptedAccuracyName)
            decryptedAccuracy = newValue?.doubleValue
        }
        else {
            willChangeValue(forKey: Self.accuracyName)
            setPrimitiveValue(newValue, forKey: Self.accuracyName)
            didChangeValue(forKey: Self.accuracyName)
        }
    }

    // MARK: Latitude

    private func getLatitude() -> NSNumber {
        guard let managedObjectContext else {
            return 0.0
        }

        var value: NSNumber = 0.0 // Default value
        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedLatitude, forKey: Self.encryptedLatitudeName)
            if let decryptedLatitude {
                value = NSNumber(floatLiteral: decryptedLatitude)
            }
        }
        else {
            willAccessValue(forKey: Self.latitudeName)
            value = primitiveValue(forKey: Self.latitudeName) as! NSNumber
            didAccessValue(forKey: Self.latitudeName)
        }
        return value
    }

    private func setLatitude(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.doubleValue, forKey: Self.encryptedLatitudeName)
            decryptedLatitude = newValue.doubleValue
        }
        else {
            willChangeValue(forKey: Self.latitudeName)
            setPrimitiveValue(newValue, forKey: Self.latitudeName)
            didChangeValue(forKey: Self.latitudeName)
        }
    }

    // MARK: Longitude

    private func getLongitude() -> NSNumber {
        var value: NSNumber = 0.0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedLongitude, forKey: Self.encryptedLongitudeName)
            if let decryptedLongitude {
                value = NSNumber(floatLiteral: decryptedLongitude)
            }
        }
        else {
            willAccessValue(forKey: Self.longitudeName)
            value = primitiveValue(forKey: Self.longitudeName) as! NSNumber
            didAccessValue(forKey: Self.longitudeName)
        }
        return value
    }

    private func setLongitude(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.doubleValue, forKey: Self.encryptedLongitudeName)
            decryptedLongitude = newValue.doubleValue
        }
        else {
            willChangeValue(forKey: Self.longitudeName)
            setPrimitiveValue(newValue, forKey: Self.longitudeName)
            didChangeValue(forKey: Self.longitudeName)
        }
    }

    // MARK: POIAddress

    private func getPoiAddress() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedPoiAddress, forKey: Self.encryptedPoiAddressName)
            value = decryptedPoiAddress
        }
        else {
            willAccessValue(forKey: Self.poiAddressName)
            value = primitiveValue(forKey: Self.poiAddressName) as? String
            didAccessValue(forKey: Self.poiAddressName)
        }
        return value
    }

    private func setPoiAddress(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedPoiAddressName)
            decryptedPoiAddress = newValue
        }
        else {
            willChangeValue(forKey: Self.poiAddressName)
            setPrimitiveValue(newValue, forKey: Self.poiAddressName)
            didChangeValue(forKey: Self.poiAddressName)
        }
    }

    // MARK: POIName

    private func getPoiName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedPoiName, forKey: Self.encryptedPoiNameName)
            value = decryptedPoiName
        }
        else {
            willAccessValue(forKey: Self.poiNameName)
            value = primitiveValue(forKey: Self.poiNameName) as? String
            didAccessValue(forKey: Self.poiNameName)
        }
        return value
    }

    private func setPoiName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedPoiNameName)
            decryptedPoiName = newValue
        }
        else {
            willChangeValue(forKey: Self.poiNameName)
            setPrimitiveValue(newValue, forKey: Self.poiNameName)
            didChangeValue(forKey: Self.poiNameName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedAccuracyName {
            decryptedAccuracy = nil
        }
        else if key == Self.encryptedLatitudeName {
            decryptedLatitude = nil
        }
        else if key == Self.encryptedLongitudeName {
            decryptedLongitude = nil
        }
        else if key == Self.encryptedPoiAddressName {
            decryptedPoiAddress = nil
        }
        else if key == Self.encryptedPoiNameName {
            decryptedPoiName = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedAccuracy = nil
        decryptedLatitude = nil
        decryptedLongitude = nil
        decryptedPoiAddress = nil
        decryptedPoiName = nil
        super.didTurnIntoFault()
    }
}
