import Foundation
import ThreemaEssentials
@testable import Keychain

// MARK: - KeychainItem + Hashable, Sendable

extension KeychainItem: Hashable, @unchecked Sendable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(accessibility as String)
    }
    
    public static func == (lhs: KeychainItem, rhs: KeychainItem) -> Bool {
        lhs.label == rhs.label && lhs.accessibility as String == rhs.accessibility as String
    }
}

final class KeychainProviderMock: KeychainProviding, @unchecked Sendable {
    
    enum ErrorType {
        case loadError(Error)
        case storeError(Error)
        case deleteError(Error)
    }
    
    struct LoadOperation: Hashable, Sendable {
        let searchItem: KeychainItem?
        let searchAccount: String?
        
        init(searchItem: KeychainItem?, searchAccount: String? = nil) {
            self.searchItem = searchItem
            self.searchAccount = searchAccount
        }
    }
    
    struct StoreOperation: Hashable, Sendable {
        let searchItem: KeychainItem?
        let searchAccount: String?
        let item: KeychainItem
        let account: String?
        let password: Data?
        let generic: Data?
        let service: String?
        
        init(
            searchItem: KeychainItem?,
            searchAccount: String?,
            item: KeychainItem,
            account: String?,
            password: Data?,
            generic: Data?,
            service: String?
        ) {
            self.searchItem = searchItem
            self.searchAccount = searchAccount
            self.item = item
            self.account = account
            self.password = password
            self.generic = generic
            self.service = service
        }
    }
    
    enum OperationType: Hashable, Sendable {
        case load(LoadOperation)
        case store(StoreOperation)
        case delete(KeychainItem)
        
        static func == (lhs: OperationType, rhs: OperationType) -> Bool {
            switch (lhs, rhs) {
            case let (.load(lhsOperation), .load(rhsOperation)):
                lhsOperation == rhsOperation
            case let (.store(lhsOperation), .store(rhsOperation)):
                lhsOperation == rhsOperation
            case let (.delete(lhsItem), .delete(rhsItem)):
                lhsItem == rhsItem
            default:
                false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case let .load(operation):
                hasher.combine("load")
                hasher.combine(operation)
            case let .store(operation):
                hasher.combine("store")
                hasher.combine(operation)
            case let .delete(item):
                hasher.combine("delete")
                hasher.combine(item)
            }
        }
        
        var isLoading: Bool {
            if case .load = self {
                true
            }
            else {
                false
            }
        }
        
        var isStoring: Bool {
            if case .store = self {
                true
            }
            else {
                false
            }
        }
        
        var isDeleting: Bool {
            if case .delete = self {
                true
            }
            else {
                false
            }
        }
    }
    
    @Atomic
    private(set) var loadError: Error?
    
    @Atomic
    private(set) var storeError: Error?
    
    @Atomic
    private(set) var deleteError: Error?
    
    @Atomic
    private(set) var calls = [OperationType]()
    
    @Atomic
    private var storage = [KeychainItem: KeychainItemData]()
    
    var loadCalls: [LoadOperation] {
        calls.compactMap { operation in
            if case let .load(loadOperation) = operation {
                return loadOperation
            }
            return nil
        }
    }
    
    var storeCalls: [StoreOperation] {
        calls.compactMap { operation in
            if case let .store(storeOperation) = operation {
                return storeOperation
            }
            return nil
        }
    }
    
    var deleteCalls: [KeychainItem] {
        calls.compactMap { operation in
            if case let .delete(item) = operation {
                return item
            }
            return nil
        }
    }
    
    func load(
        _ searchItem: KeychainItem?,
        searchAccount: String?
    ) throws -> KeychainItemData? {
        let operation = LoadOperation(searchItem: searchItem, searchAccount: searchAccount)
        $calls.append(.load(operation))
        
        if let error = loadError {
            throw error
        }
        
        let keychainItemData = storedData(for: searchItem)
        
        return keychainItemData
    }
    
    func store(
        searchItem: KeychainItem?,
        searchAccount: String?,
        _ item: KeychainItem,
        account: String?,
        password: Data?,
        generic: Data?,
        service: String?
    ) throws {
        let operation = StoreOperation(
            searchItem: searchItem,
            searchAccount: searchAccount,
            item: item,
            account: account,
            password: password,
            generic: generic,
            service: service
        )
        $calls.append(.store(operation))
        
        if let error = storeError {
            throw error
        }
        
        let data = KeychainItemData(
            accessibility: item.accessibility,
            label: item.label,
            account: account,
            password: password,
            generic: generic,
            service: service
        )
        $storage.set(searchItem ?? item, data)
    }
    
    func delete(_ searchItem: Keychain.KeychainItem) throws {
        $calls.append(.delete(searchItem))
        
        if let error = deleteError {
            throw error
        }
        
        $storage.removeValue(forKey: searchItem)
    }
    
    /// Clear all stored data and call history
    func reset() {
        $storage.removeAll()
        $calls.removeAll()
        loadError = nil
        storeError = nil
        deleteError = nil
    }
    
    func storedData(for item: Keychain.KeychainItem?) -> KeychainItemData? {
        guard let item,
              let keychainItemData = storage[item] else {
            return nil
        }
        
        return keychainItemData
    }
    
    func updateError(_ errorType: KeychainProviderMock.ErrorType) {
        switch errorType {
        case let .loadError(error):
            loadError = error
        case let .storeError(error):
            storeError = error
        case let .deleteError(error):
            deleteError = error
        }
    }
}
