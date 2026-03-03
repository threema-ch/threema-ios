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

@objc(WebClientSessionEntity)
public final class WebClientSessionEntity: ThreemaManagedObject {

    // MARK: Attributes

    @NSManaged public var active: NSNumber?

    @EncryptedField
    @objc public dynamic var browserName: String? {
        get {
            getBrowserName()
        }

        set {
            setBrowserName(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var browserVersion: NSNumber? {
        get {
            getBrowserVersion()
        }

        set {
            setBrowserVersion(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var initiatorPermanentPublicKey: Data {
        get {
            getInitiatorPermanentPublicKey()
        }

        set {
            setInitiatorPermanentPublicKey(newValue)
        }
    }

    @NSManaged public var initiatorPermanentPublicKeyHash: String?

    @EncryptedField
    @objc public dynamic var lastConnection: Date? {
        get {
            getLastConnection()
        }

        set {
            setLastConnection(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var name: String? {
        get {
            getName()
        }

        set {
            setName(newValue)
        }
    }

    @NSManaged public var permanent: NSNumber

    @EncryptedField
    @objc public dynamic var privateKey: Data? {
        get {
            getPrivateKey()
        }

        set {
            setPrivateKey(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var saltyRTCHost: String {
        get {
            getSaltyRTCHost()
        }

        set {
            setSaltyRTCHost(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var saltyRTCPort: NSNumber {
        get {
            getSaltyRTCPort()
        }

        set {
            setSaltyRTCPort(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var selfHosted: NSNumber {
        get {
            getSelfHosted()
        }

        set {
            setSelfHosted(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var serverPermanentPublicKey: Data {
        get {
            getServerPermanentPublicKey()
        }

        set {
            setServerPermanentPublicKey(newValue)
        }
    }

    @EncryptedField
    @objc public dynamic var version: NSNumber? {
        get {
            getVersion()
        }

        set {
            setVersion(newValue)
        }
    }

    // MARK: Non-CoreData Properties

    @objc public var isConnecting = false

    // MARK: Private properties

    // Cached decrypted values
    private var decryptedBrowserName: String?
    private var decryptedBrowserVersion: Int32?
    private var decryptedInitiatorPermanentPublicKey: Data? // Non optional
    private var decryptedLastConnection: Date?
    private var decryptedName: String?
    private var decryptedPrivateKey: Data?
    private var decryptedSaltyRTCHost: String? // Non optional
    private var decryptedSaltyRTCPort: Int64? // Non optional
    private var decryptedSelfHosted: Bool? // Non optional
    private var decryptedServerPermanentPublicKey: Data? // Non optional
    private var decryptedVersion: Int32?

    // MARK: - Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - active: `True` if the session active
    ///   - browserName: Name of the browser
    ///   - browserVersion: Version of the browser
    ///   - initiatorPermanentPublicKey: Public key of the initiator
    ///   - initiatorPermanentPublicKeyHash: Hash of the public key of the initiator
    ///   - lastConnection: `Date` of the last connection
    ///   - name: Name of the session
    ///   - permanent: `True` if session is permanent
    ///   - privateKey: Private key of the session
    ///   - saltyRTCHost: SaltyRTC host
    ///   - saltyRTCPort: SaltyRTC port
    ///   - selfHosted: True if is self hosted
    ///   - serverPermanentPublicKey: Public key of the server
    ///   - version: Version number
    init(
        context: NSManagedObjectContext,
        active: Bool? = nil,
        browserName: String? = nil,
        browserVersion: Int32? = nil,
        initiatorPermanentPublicKey: Data,
        initiatorPermanentPublicKeyHash: String? = nil,
        lastConnection: Date? = nil,
        name: String? = nil,
        permanent: Bool,
        privateKey: Data? = nil,
        saltyRTCHost: String,
        saltyRTCPort: Int64,
        selfHosted: Bool,
        serverPermanentPublicKey: Data,
        version: Int32? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "WebClientSession", in: context)!
        super.init(entity: entity, insertInto: context)

        if let active {
            self.active = NSNumber(booleanLiteral: active)
        }
        setBrowserName(browserName)
        if let browserVersion {
            setBrowserVersion(browserVersion as NSNumber)
        }
        setInitiatorPermanentPublicKey(initiatorPermanentPublicKey)
        self.initiatorPermanentPublicKeyHash = initiatorPermanentPublicKeyHash
        setLastConnection(lastConnection)
        setName(name)
        self.permanent = NSNumber(booleanLiteral: permanent)
        setPrivateKey(privateKey)
        setSaltyRTCHost(saltyRTCHost)
        setSaltyRTCPort(saltyRTCPort as NSNumber)
        setSelfHosted(NSNumber(booleanLiteral: selfHosted))
        setServerPermanentPublicKey(serverPermanentPublicKey)
        if let version {
            setVersion(version as NSNumber)
        }
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

    // MARK: BrowserName

    private func getBrowserName() -> String? {
        var value: String?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedBrowserName, forKey: Self.encryptedBrowserNameName)
            value = decryptedBrowserName
        }
        else {
            willAccessValue(forKey: Self.browserNameName)
            value = primitiveValue(forKey: Self.browserNameName) as? String
            didAccessValue(forKey: Self.browserNameName)
        }
        return value
    }

    private func setBrowserName(_ newValue: String?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedBrowserNameName)
            decryptedBrowserName = newValue
        }
        else {
            willChangeValue(forKey: Self.browserNameName)
            setPrimitiveValue(newValue, forKey: Self.browserNameName)
            didChangeValue(forKey: Self.browserNameName)
        }
    }

    // MARK: BrowserVersion

    private func getBrowserVersion() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedBrowserVersion, forKey: Self.encryptedBrowserVersionName)
            if let decryptedBrowserVersion {
                value = NSNumber(integerLiteral: Int(decryptedBrowserVersion))
            }
        }
        else {
            willAccessValue(forKey: Self.browserVersionName)
            value = primitiveValue(forKey: Self.browserVersionName) as? NSNumber
            didAccessValue(forKey: Self.browserVersionName)
        }
        return value
    }

    private func setBrowserVersion(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedBrowserVersionName)
            decryptedBrowserVersion = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.browserVersionName)
            setPrimitiveValue(newValue, forKey: Self.browserVersionName)
            didChangeValue(forKey: Self.browserVersionName)
        }
    }

    // MARK: InitiatorPermanentPublicKey

    private func getInitiatorPermanentPublicKey() -> Data {
        var value = Data()
        guard let managedObjectContext else {
            return Data()
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedInitiatorPermanentPublicKey, forKey: Self.encryptedInitiatorPermanentPublicKeyName)
            if let decryptedInitiatorPermanentPublicKey {
                value = decryptedInitiatorPermanentPublicKey
            }
        }
        else {
            willAccessValue(forKey: Self.initiatorPermanentPublicKeyName)
            value = primitiveValue(forKey: Self.initiatorPermanentPublicKeyName) as? Data ?? value
            didAccessValue(forKey: Self.initiatorPermanentPublicKeyName)
        }
        return value
    }

    private func setInitiatorPermanentPublicKey(_ newValue: Data) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedInitiatorPermanentPublicKeyName)
            decryptedInitiatorPermanentPublicKey = newValue
        }
        else {
            willChangeValue(forKey: Self.initiatorPermanentPublicKeyName)
            setPrimitiveValue(newValue, forKey: Self.initiatorPermanentPublicKeyName)
            didChangeValue(forKey: Self.initiatorPermanentPublicKeyName)
        }
    }

    // MARK: LastConnection

    private func getLastConnection() -> Date? {
        var value: Date?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedLastConnection, forKey: Self.encryptedLastConnectionName)
            value = decryptedLastConnection
        }
        else {
            willAccessValue(forKey: Self.lastConnectionName)
            value = primitiveValue(forKey: Self.lastConnectionName) as? Date
            didAccessValue(forKey: Self.lastConnectionName)
        }
        return value
    }

    private func setLastConnection(_ newValue: Date?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedLastConnectionName)
            decryptedLastConnection = newValue
        }
        else {
            willChangeValue(forKey: Self.lastConnectionName)
            setPrimitiveValue(newValue, forKey: Self.lastConnectionName)
            didChangeValue(forKey: Self.lastConnectionName)
        }
    }

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

    // MARK: PrivateKey

    private func getPrivateKey() -> Data? {
        var value: Data?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedPrivateKey, forKey: Self.encryptedPrivateKeyName)
            value = decryptedPrivateKey
        }
        else {
            willAccessValue(forKey: Self.privateKeyName)
            value = primitiveValue(forKey: Self.privateKeyName) as? Data
            didAccessValue(forKey: Self.privateKeyName)
        }
        return value
    }

    private func setPrivateKey(_ newValue: Data?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue, forKey: Self.encryptedPrivateKeyName)
            decryptedPrivateKey = newValue
        }
        else {
            willChangeValue(forKey: Self.privateKeyName)
            setPrimitiveValue(newValue, forKey: Self.privateKeyName)
            didChangeValue(forKey: Self.privateKeyName)
        }
    }

    // MARK: SaltyRTCHost

    private func getSaltyRTCHost() -> String {
        var value = ""
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedSaltyRTCHost, forKey: Self.encryptedSaltyRTCHostName)
            if let decryptedSaltyRTCHost {
                value = decryptedSaltyRTCHost
            }
        }
        else {
            willAccessValue(forKey: Self.saltyRTCHostName)
            value = primitiveValue(forKey: Self.saltyRTCHostName) as? String ?? ""
            didAccessValue(forKey: Self.saltyRTCHostName)
        }
        return value
    }

    private func setSaltyRTCHost(_ newValue: String) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedSaltyRTCHostName)
            decryptedSaltyRTCHost = newValue
        }
        else {
            willChangeValue(forKey: Self.saltyRTCHostName)
            setPrimitiveValue(newValue, forKey: Self.saltyRTCHostName)
            didChangeValue(forKey: Self.saltyRTCHostName)
        }
    }

    // MARK: SaltyRTCPort

    private func getSaltyRTCPort() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedSaltyRTCPort, forKey: Self.encryptedSaltyRTCPortName)
            if let decryptedSaltyRTCPort {
                value = NSNumber(integerLiteral: Int(decryptedSaltyRTCPort))
            }
        }
        else {
            willAccessValue(forKey: Self.saltyRTCPortName)
            value = primitiveValue(forKey: Self.saltyRTCPortName) as? NSNumber ?? 0
            didAccessValue(forKey: Self.saltyRTCPortName)
        }
        return value
    }

    private func setSaltyRTCPort(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.int64Value, forKey: Self.encryptedSaltyRTCPortName)
            decryptedSaltyRTCPort = newValue.int64Value
        }
        else {
            willChangeValue(forKey: Self.saltyRTCPortName)
            setPrimitiveValue(newValue, forKey: Self.saltyRTCPortName)
            didChangeValue(forKey: Self.saltyRTCPortName)
        }
    }

    // MARK: SelfHosted

    private func getSelfHosted() -> NSNumber {
        var value: NSNumber = 0 // Default value
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedSelfHosted, forKey: Self.encryptedSelfHostedName)
            if let decryptedSelfHosted {
                value = NSNumber(booleanLiteral: decryptedSelfHosted)
            }
        }
        else {
            willAccessValue(forKey: Self.selfHostedName)
            value = primitiveValue(forKey: Self.selfHostedName) as? NSNumber ?? value
            didAccessValue(forKey: Self.selfHostedName)
        }
        return value
    }

    private func setSelfHosted(_ newValue: NSNumber) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue.boolValue, forKey: Self.encryptedSelfHostedName)
            decryptedSelfHosted = newValue.boolValue
        }
        else {
            willChangeValue(forKey: Self.selfHostedName)
            setPrimitiveValue(newValue, forKey: Self.selfHostedName)
            didChangeValue(forKey: Self.selfHostedName)
        }
    }

    // MARK: ServerPermanentPublicKey

    private func getServerPermanentPublicKey() -> Data {
        var value = Data()
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decrypt(&decryptedServerPermanentPublicKey, forKey: Self.encryptedServerPermanentPublicKeyName)
            if let decryptedServerPermanentPublicKey {
                value = decryptedServerPermanentPublicKey
            }
        }
        else {
            willAccessValue(forKey: Self.serverPermanentPublicKeyName)
            value = primitiveValue(forKey: Self.serverPermanentPublicKeyName) as? Data ?? value
            didAccessValue(forKey: Self.serverPermanentPublicKeyName)
        }
        return value
    }

    private func setServerPermanentPublicKey(_ newValue: Data) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encrypt(newValue, forKey: Self.encryptedServerPermanentPublicKeyName)
            decryptedServerPermanentPublicKey = newValue
        }
        else {
            willChangeValue(forKey: Self.serverPermanentPublicKeyName)
            setPrimitiveValue(newValue, forKey: Self.serverPermanentPublicKeyName)
            didChangeValue(forKey: Self.serverPermanentPublicKeyName)
        }
    }

    // MARK: Version

    private func getVersion() -> NSNumber? {
        var value: NSNumber?
        guard let managedObjectContext else {
            return value
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            decryptOptional(&decryptedVersion, forKey: Self.encryptedVersionName)
            if let decryptedVersion {
                value = NSNumber(integerLiteral: Int(decryptedVersion))
            }
        }
        else {
            willAccessValue(forKey: Self.versionName)
            value = primitiveValue(forKey: Self.versionName) as? NSNumber
            didAccessValue(forKey: Self.versionName)
        }
        return value
    }

    private func setVersion(_ newValue: NSNumber?) {
        guard let managedObjectContext else {
            return
        }

        if managedObjectContext.usesAdditionallyEncryptedModel {
            encryptOptional(newValue?.int32Value, forKey: Self.encryptedVersionName)
            decryptedVersion = newValue?.int32Value
        }
        else {
            willChangeValue(forKey: Self.versionName)
            setPrimitiveValue(newValue, forKey: Self.versionName)
            didChangeValue(forKey: Self.versionName)
        }
    }

    // MARK: - Reset cached values

    override public func didChangeValue(forKey key: String) {
        if key == Self.encryptedBrowserNameName {
            decryptedBrowserName = nil
        }
        else if key == Self.encryptedBrowserVersionName {
            decryptedBrowserVersion = nil
        }
        else if key == Self.encryptedInitiatorPermanentPublicKeyName {
            decryptedInitiatorPermanentPublicKey = nil
        }
        else if key == Self.encryptedLastConnectionName {
            decryptedLastConnection = nil
        }
        else if key == Self.encryptedNameName {
            decryptedName = nil
        }
        else if key == Self.encryptedPrivateKeyName {
            decryptedPrivateKey = nil
        }
        else if key == Self.encryptedSaltyRTCHostName {
            decryptedSaltyRTCHost = nil
        }
        else if key == Self.encryptedSaltyRTCPortName {
            decryptedSaltyRTCPort = nil
        }
        else if key == Self.encryptedSelfHostedName {
            decryptedSelfHosted = nil
        }
        else if key == Self.encryptedServerPermanentPublicKeyName {
            decryptedServerPermanentPublicKey = nil
        }
        else if key == Self.encryptedVersionName {
            decryptedVersion = nil
        }
        super.didChangeValue(forKey: key)
    }

    override public func didTurnIntoFault() {
        decryptedBrowserName = nil
        decryptedBrowserVersion = nil
        decryptedInitiatorPermanentPublicKey = nil
        decryptedLastConnection = nil
        decryptedName = nil
        decryptedPrivateKey = nil
        decryptedSaltyRTCHost = nil
        decryptedSaltyRTCPort = nil
        decryptedSelfHosted = nil
        decryptedServerPermanentPublicKey = nil
        decryptedVersion = nil
        super.didTurnIntoFault()
    }
}
