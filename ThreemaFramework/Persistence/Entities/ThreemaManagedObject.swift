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

public class ThreemaManagedObject: NSManagedObject {

    /// This will be set to `true` when an object is in the process to be deleted.
    ///
    /// This can be used to detect deletion in KVO-observers
    @objc public private(set) dynamic var willBeDeleted = false

    override public func prepareForDeletion() {
        super.prepareForDeletion() // We call this just to be safe

        willBeDeleted = true
    }

    // MARK: - Encrypted field getter & setter

    // MARK: Data
    
    func encryptOptional(_ newValue: Data?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
        
        // If `newValue` is not nil we encrypt it
        if let newValue {
            let encryptedNewValue = EntityCryptoManager.shared.encrypt(newValue)
            // Save the encrypted value to CoreData
            setPrimitiveValue(encryptedNewValue, forKey: fieldName)
        }
        // Else, set the value to `nil` in CoreData
        else {
            setPrimitiveValue(nil, forKey: fieldName)
        }
        
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Data?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Data, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
        
        // Encrypt `newValue`
        let encryptedNewValue = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedNewValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Data?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: String
    
    func encryptOptional(_ newValue: String?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // If `newValue` is not nil we encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout String?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: String, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout String?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Int16
    
    func encryptOptional(_ newValue: Int16?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Int16?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Int16, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Int16?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Int32
    
    func encryptOptional(_ newValue: Int32?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Int32?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Int32, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Int32?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Int64
    
    func encryptOptional(_ newValue: Int64?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Int64?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Int64, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Int64?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Double
    
    func encryptOptional(_ newValue: Double?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Double?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Double, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Double?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Float
    
    func encryptOptional(_ newValue: Float?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Float?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Float, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Float?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Date
    
    func encryptOptional(_ newValue: Date?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Date?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Date, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Date?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: Bool
    
    func encryptOptional(_ newValue: Bool?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encrypt it
        var encryptedValue: Data?
        if let newValue {
            encryptedValue = EntityCryptoManager.shared.encrypt(newValue)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout Bool?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value and assign it to `cache`
            cache = EntityCryptoManager.shared.decrypt(encrypted)
        }
        
        didAccessValue(forKey: fieldName)
    }

    func encrypt(_ newValue: Bool, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)

        // Encrypt `newValue`
        let encryptedValue: Data = EntityCryptoManager.shared.encrypt(newValue)
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decrypt(_ cache: inout Bool?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        defer {
            didAccessValue(forKey: fieldName)
        }
        
        // If there is a value in `cache` we do nothing
        guard cache == nil else {
            return
        }
        
        // Since the value is non optional in CoreData, we should never get `nil` when retrieving it
        guard let encryptedData = primitiveValue(forKey: fieldName) as? Data else {
            fatalError("[Persistence] Missing Core Data value for none optional value")
        }
        
        // Decrypt value from CoreData and assign it to `cache`
        cache = EntityCryptoManager.shared.decrypt(encryptedData)
    }
    
    // MARK: GroupDeliveryReceipt
    
    func encryptOptional(_ newValue: [GroupDeliveryReceipt]?, forKey fieldName: String) {
        willChangeValue(forKey: fieldName)
       
        // Encode them, then encrypt them
        var encryptedValue: Data?
        if let newValue {
            let transformer = GroupDeliveryReceiptValueTransformer()
            var encoded: Data = transformer.reverseTransformedValue(newValue) as! Data
            encryptedValue = EntityCryptoManager.shared.encrypt(encoded)
        }
        
        // Save to CoreData
        setPrimitiveValue(encryptedValue, forKey: fieldName)
        didChangeValue(forKey: fieldName)
    }
    
    func decryptOptional(_ cache: inout [GroupDeliveryReceipt]?, forKey fieldName: String) {
        willAccessValue(forKey: fieldName)
       
        // If `cache` is nil and there is a value in CoreData
        if cache == nil, let encrypted = primitiveValue(forKey: fieldName) as? Data {
            // Decrypt the value, decode it and assign it to `cache`
            let decryptedValue: Data = EntityCryptoManager.shared.decrypt(encrypted)
            let transformer = GroupDeliveryReceiptValueTransformer()
            cache = transformer.transformedValue(decryptedValue) as? [GroupDeliveryReceipt]
        }
        
        didAccessValue(forKey: fieldName)
    }
}
