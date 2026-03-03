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

import Foundation
import RemoteSecretProtocol
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
@testable import Keychain
@testable import KeychainTestHelper

@Suite("KeychainManagerTests")
struct KeychainManagerTests {
    
    // MARK: - Identity Tests
    
    @Test("Store Identity (Remote Secret Disabled)")
    func testStoreIdentityWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)

        let identity = try keychainManager.storeTestIdentity()
        
        let storeKeychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = storeKeychainCall else {
            Issue.record("Expected call to be .store, but got \(storeKeychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(storeKeychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .identity())
        #expect(storeOperation.account == identity.$identity)
        #expect(storeOperation.password == identity.$clientKey)
        #expect(storeOperation.generic == identity.$publicKey)
        #expect(storeOperation.service == identity.$serverGroup)

        #expect(cryptoMock.calls == [])
        #expect(keychainMock.calls.count == 1)
    }
    
    @Test("Store Identity (Remote Secret Enabled)")
    func testStoreIdentityWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let identity = try keychainManager.storeTestIdentity()
        
        let storeKeychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = storeKeychainCall else {
            Issue.record("Expected call to be .store, but got \(storeKeychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(storeKeychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .identity())
        #expect(storeOperation.account == identity.$identity)
        
        /// Because we lose the real values, we just check if they exist
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic != nil)
        #expect(storeOperation.service != nil)

        #expect(cryptoMock.calls == [
            .encryptData(identity.$clientKey),
            .encryptData(identity.$publicKey),
            .encryptString(identity.$serverGroup),
        ])
        #expect(keychainMock.calls.count == 1)
    }
    
    @Test("Load Identity (Remote Secret Disabled)")
    func testLoadIdentityWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let identity = try keychainManager.storeTestIdentity()
        
        let loadedItem = try #require(try keychainManager.loadIdentity())
        #expect(loadedItem == identity)
        #expect(keychainMock.calls.count == 2)
        #expect(cryptoMock.calls.isEmpty)
        
        let loadKeychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = loadKeychainCall else {
            Issue.record("Expected call to be .load, but got \(loadKeychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(loadKeychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .identity())
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test("Load Identity (Remote Secret Enabled)")
    func testLoadIdentityWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let identity = try keychainManager.storeTestIdentity()
        
        let loadedItem = try #require(try keychainManager.loadIdentity())
        #expect(loadedItem.$identity == identity.$identity)
        
        /// 1 from storing, 1 from loading
        #expect(keychainMock.calls.count == 2)
        
        /// 3 calls are from the storing operation, 3 from loading
        #expect(cryptoMock.calls.count == 6)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 3
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptData = decryptFirstCall else {
            Issue.record("Expected decryptData at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptSecondCallIndex = 4
        let decryptSecondCall = cryptoMock.calls[decryptSecondCallIndex]
        guard case .decryptData = decryptSecondCall else {
            Issue.record("Expected decryptData at index \(decryptSecondCallIndex), but got \(decryptSecondCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptThirdCallIndex = 5
        let decryptThirdCall = cryptoMock.calls[decryptThirdCallIndex]
        guard case .decryptDataToString = decryptThirdCall else {
            Issue.record("Expected decryptDataToString at index \(decryptThirdCallIndex), but got \(decryptThirdCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let loadKeychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = loadKeychainCall else {
            Issue.record("Expected call to be .load, but got \(loadKeychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(loadKeychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .identity())
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test
    func testDeleteIdentity() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteIdentity()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .identity())
        #expect(cryptoMock.calls.isEmpty)
    }
    
    // MARK: - Device Cookie Tests

    @Test("Store Device Cookie (Remote Secret Disabled)")
    func testStoreDeviceCookieWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let cookieData = Data("device_cookie".utf8)
        
        try keychainManager.storeDeviceCookie(cookieData)
        #expect(cryptoMock.calls == [])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.deviceCookie()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password == cookieData)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }
    
    @Test("Store Device Cookie (Remote Secret Enabled)")
    func testStoreDeviceCookieWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let cookieData = Data("device_cookie".utf8)
        
        try keychainManager.storeDeviceCookie(cookieData)
        #expect(cryptoMock.calls == [
            .encryptData(cookieData),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.deviceCookie()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }
    
    @Test("Load Device Cookie (Remote Secret Disabled)")
    func testLoadDeviceCookieWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let cookieData = Data("device_cookie".utf8)
        try keychainManager.storeDeviceCookie(cookieData)
        
        _ = try #require(try keychainManager.loadDeviceCookie())
        
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .deviceCookie())
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test("Load Device Cookie (Remote Secret Enabled)")
    func testLoadDeviceCookieWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let cookieData = Data("device_cookie".utf8)
        try keychainManager.storeDeviceCookie(cookieData)
        
        _ = try #require(try keychainManager.loadDeviceCookie())
        
        #expect(keychainMock.calls.count == 2)
        
        /// 1 from storing operation, 1 from loading
        #expect(cryptoMock.calls.count == 2)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 1
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptData = decryptFirstCall else {
            Issue.record("Expected decryptData at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected first call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .deviceCookie())
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test
    func testLoadDeviceCookieNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadDeviceCookie() == nil)
        #expect(keychainMock.loadCalls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .deviceCookie())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testDeleteDeviceCookie() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteDeviceCookie()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .deviceCookie())
        #expect(cryptoMock.calls.isEmpty)
    }
    
    // MARK: - Multi-Device Group Key Tests
    
    @Test("Store Multi-Device Group Key (Remote Secret Disabled)")
    func testStoreMultiDeviceGroupKeyWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let keyData = Data("multi_device_group_key".utf8)
        
        try keychainManager.storeMultiDeviceGroupKey(key: keyData)
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.multiDeviceGroupKey()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password == keyData)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }
    
    @Test("Store Multi-Device Group Key (Remote Secret Enabled)")
    func testStoreMultiDeviceGroupKeyWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let keyData = Data("multi_device_group_key".utf8)
        
        try keychainManager.storeMultiDeviceGroupKey(key: keyData)
        #expect(cryptoMock.calls == [
            .encryptData(keyData),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.multiDeviceGroupKey()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }
    
    @Test("Load Multi-Device Group Key (Remote Secret Disabled)")
    func testLoadMultiDeviceGroupKeyWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let keyData = Data("multi_device_group_key".utf8)
        let keychainItem = KeychainItem.multiDeviceGroupKey()
        try keychainManager.storeMultiDeviceGroupKey(key: keyData)
        
        _ = try #require(try keychainManager.loadMultiDeviceGroupKey())
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == keychainItem)
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test("Load Multi-Device Group Key (Remote Secret Enabled)")
    func testLoadMultiDeviceGroupKeyWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let keyData = Data("multi_device_group_key".utf8)
        let keychainItem = KeychainItem.multiDeviceGroupKey()
        try keychainManager.storeMultiDeviceGroupKey(key: keyData)
        
        _ = try #require(try keychainManager.loadMultiDeviceGroupKey())
        #expect(keychainMock.calls.count == 2)
        
        /// 1 from storing operation, 1 from loading
        #expect(cryptoMock.calls.count == 2)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 1
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptData = decryptFirstCall else {
            Issue.record("Expected decryptData at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == keychainItem)
        #expect(loadOperation.searchAccount == nil)
    }
    
    @Test
    func testLoadMultiDeviceGroupKeyNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadMultiDeviceGroupKey() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
                
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .multiDeviceGroupKey())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }
    
    // MARK: - Multi-Device ID Tests
    
    @Test("Store Multi-Device ID (Remote Secret Disabled)")
    func testStoreMultiDeviceIDWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let idData = Data("multi_device_id".utf8)
        try keychainManager.storeMultiDeviceID(id: idData)
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.multiDeviceID()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password == idData)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }
    
    @Test("Store Multi-Device ID (Remote Secret Enabled)")
    func testStoreMultiDeviceIDWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let idData = Data("multi_device_id".utf8)
        
        try keychainManager.storeMultiDeviceID(id: idData)
        #expect(cryptoMock.calls == [
            .encryptData(idData),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.multiDeviceID()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }

    @Test("Load Multi-Device ID (Remote Secret Disabled)")
    func testLoadMultiDeviceIDWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let idData = Data("multi_device_id".utf8)
        try keychainManager.storeMultiDeviceID(id: idData)
        
        _ = try #require(try keychainManager.loadMultiDeviceID())
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .multiDeviceID())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test("Load Multi-Device ID (Remote Secret Enabled)")
    func testLoadMultiDeviceIDWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let idData = Data("multi_device_id".utf8)
        try keychainManager.storeMultiDeviceID(id: idData)
        
        _ = try #require(try keychainManager.loadMultiDeviceID())
        #expect(keychainMock.calls.count == 2)
        
        /// 1 from storing operation, 1 from loading
        #expect(cryptoMock.calls.count == 2)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 1
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptData = decryptFirstCall else {
            Issue.record("Expected decryptData at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .multiDeviceID())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test
    func testLoadMultiDeviceIDNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadMultiDeviceID() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .multiDeviceID())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testDeleteMultiDeviceID() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteMultiDeviceID()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .multiDeviceID())
        #expect(cryptoMock.calls.isEmpty)
    }

    // MARK: - Forward Security Key Tests

    @Test("Store Forward Security Wrapping Key (Remote Secret Disabled)")
    func testStoreForwardSecurityWrappingKeyWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let keyData = Data("forward_security_key".utf8)
        
        try keychainManager.storeForwardSecurityWrappingKey(keyData)
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.forwardSecurityWrappingKey()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password == keyData)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }

    @Test("Store Forward Security Wrapping Key (Remote Secret Enabled)")
    func testStoreForwardSecurityWrappingKeyWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let keyData = Data("forward_security_key".utf8)
        
        try keychainManager.storeForwardSecurityWrappingKey(keyData)
        #expect(cryptoMock.calls == [
            .encryptData(keyData),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.forwardSecurityWrappingKey()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic == nil)
        #expect(storeOperation.service == nil)
    }

    @Test("Load Forward Security Wrapping Key (Remote Secret Disabled)")
    func testLoadForwardSecurityWrappingKeyWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let keyData = Data("forward_security_key".utf8)
        try keychainManager.storeForwardSecurityWrappingKey(keyData)
        
        _ = try #require(try keychainManager.loadForwardSecurityWrappingKey())
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .forwardSecurityWrappingKey())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test("Load Forward Security Wrapping Key (Remote Secret Enabled)")
    func testLoadForwardSecurityWrappingKeyWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let keyData = Data("forward_security_key".utf8)
        try keychainManager.storeForwardSecurityWrappingKey(keyData)
        
        _ = try #require(try keychainManager.loadForwardSecurityWrappingKey())
        #expect(keychainMock.calls.count == 2)
        
        /// 1 from storing operation, 1 from loading
        #expect(cryptoMock.calls.count == 2)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 1
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptData = decryptFirstCall else {
            Issue.record("Expected decryptData at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .forwardSecurityWrappingKey())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test
    func testLoadForwardSecurityWrappingKeyNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadForwardSecurityWrappingKey() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .forwardSecurityWrappingKey())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testDeleteForwardSecurityKey() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteForwardSecurityKey()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .forwardSecurityWrappingKey())
        #expect(cryptoMock.calls.isEmpty)
    }

    // MARK: - License Tests

    @Test("Store License (Remote Secret Disabled)")
    func testStoreLicenseWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let license = Keychain.ThreemaLicense(
            user: "test_user",
            password: "test_password",
            deviceID: "device123",
            onPremServer: "test.server.com"
        )
        
        try keychainManager.storeLicense(license)
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .license())
        #expect(storeOperation.account == license.user)
        #expect(storeOperation.password == Data(license.password.utf8))
        #expect(storeOperation.generic == Data(license.deviceID!.utf8))
        #expect(storeOperation.service == license.onPremServer)
    }

    @Test("Store License (Remote Secret Enabled)")
    func testStoreLicenseWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let license = Keychain.ThreemaLicense(
            user: "test_user",
            password: "test_password",
            deviceID: "device123",
            onPremServer: "test.server.com"
        )
        
        try keychainManager.storeLicense(license)
        #expect(cryptoMock.calls == [
            .encryptString(license.user),
            .encryptString(license.password),
            .encryptString(license.deviceID!),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .license())
        #expect(storeOperation.account != nil)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.generic != nil)
        #expect(storeOperation.service == license.onPremServer)
    }

    @Test("Load License (Remote Secret Disabled)")
    func testLoadLicenseWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let license = Keychain.ThreemaLicense(
            user: "test_user",
            password: "test_password",
            deviceID: "device123",
            onPremServer: "test.server.com"
        )
        try keychainManager.storeLicense(license)
        
        _ = try #require(try keychainManager.loadLicense())
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .license())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test("Load License (Remote Secret Enabled)")
    func testLoadLicenseWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let license = Keychain.ThreemaLicense(
            user: "test_user",
            password: "test_password",
            deviceID: "device123",
            onPremServer: "test.server.com"
        )
        try keychainManager.storeLicense(license)
        
        _ = try #require(try keychainManager.loadLicense())
        #expect(keychainMock.calls.count == 2)
        
        /// 3 from storing operation, 3 from loading
        #expect(cryptoMock.calls.count == 6)

        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 3
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptDataToString = decryptFirstCall else {
            Issue.record("Expected decryptDataToString at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptSecondCallIndex = 4
        let decryptSecondCall = cryptoMock.calls[decryptSecondCallIndex]
        guard case .decryptData = decryptSecondCall else {
            Issue
                .record("Expected decryptData at index \(decryptSecondCallIndex), but got \(decryptSecondCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptThirdCallIndex = 5
        let decryptThirdCall = cryptoMock.calls[decryptThirdCallIndex]
        guard case .decryptData = decryptThirdCall else {
            Issue.record("Expected decryptData at index \(decryptThirdCallIndex), but got \(decryptThirdCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .license())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test
    func testLoadLicenseNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadLicense() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .license())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testDeleteLicense() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteLicense()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .license())
        #expect(cryptoMock.calls.isEmpty)
    }

    // MARK: - Threema Safe Key Tests (No remote secret encryption)

    @Test
    func testLoadThreemaSafeKey() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        let keyData = Data("threema_safe_key".utf8)
        try keychainManager.storeThreemaSafeKey(key: keyData)
        
        let loadedItem = try #require(try keychainManager.loadThreemaSafeKey())
        #expect(loadedItem == keyData)
        #expect(keychainMock.calls.count == 2)
        #expect(cryptoMock.calls.isEmpty)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .threemaSafeKey())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test
    func testLoadThreemaSafeKeyNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadThreemaSafeKey() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .threemaSafeKey())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testStoreThreemaSafeKey() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        let keyData = Data("threema_safe_key".utf8)
        try keychainManager.storeThreemaSafeKey(key: keyData)
        #expect(keychainMock.calls.count == 1)
        #expect(cryptoMock.calls.isEmpty)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        
        let keychainItem = KeychainItem.threemaSafeKey()
        #expect(storeOperation.item == keychainItem)
        #expect(storeOperation.account == keychainItem.label)
        #expect(storeOperation.password == keyData)
    }

    @Test
    func testDeleteThreemaSafeKey() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteThreemaSafeKey()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .threemaSafeKey())
        #expect(cryptoMock.calls.isEmpty)
    }

    // MARK: - Threema Safe Server Tests

    @Test("Store Threema Safe Server (Remote Secret Disabled)")
    func testStoreThreemaSafeServerWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let server = Keychain.ThreemaSafeServerInfo(
            user: "safe_user",
            password: "safe_password",
            server: "safe.threema.ch"
        )
        
        try keychainManager.storeThreemaSafeServer(server)
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .threemaSafeServer())
        #expect(storeOperation.account == server.user)
        #expect(storeOperation.password == Data(server.password!.utf8))
        #expect(storeOperation.service == server.server)
    }

    @Test("Store Threema Safe Server (Remote Secret Enabled)")
    func testStoreThreemaSafeServerWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let server = Keychain.ThreemaSafeServerInfo(
            user: "safe_user",
            password: "safe_password",
            server: "safe.threema.ch"
        )
        
        try keychainManager.storeThreemaSafeServer(server)
        #expect(cryptoMock.calls == [
            .encryptString(server.user!),
            .encryptString(server.password!),
            .encryptString(server.server),
        ])
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .store(storeOperation) = keychainCall else {
            Issue.record("Expected call to be .store, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isStoring == true)
        #expect(storeOperation.searchItem == nil)
        #expect(storeOperation.searchAccount == nil)
        #expect(storeOperation.item == .threemaSafeServer())
        #expect(storeOperation.account != nil)
        #expect(storeOperation.password != nil)
        #expect(storeOperation.service != nil)
    }

    @Test("Load Threema Safe Server (Remote Secret Disabled)")
    func testLoadThreemaSafeServerWithRemoteSecretDisabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: false)
        
        let server = Keychain.ThreemaSafeServerInfo(
            user: "safe_user",
            password: "safe_password",
            server: "safe.threema.ch"
        )
        try keychainManager.storeThreemaSafeServer(server)
        
        _ = try #require(try keychainManager.loadThreemaSafeServer())
        #expect(cryptoMock.calls.isEmpty)
        #expect(keychainMock.calls.count == 2)
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .threemaSafeServer())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test("Load Threema Safe Server (Remote Secret Enabled)")
    func testLoadThreemaSafeServerWithRemoteSecretEnabled() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT(isRemoteSecretEnabled: true)
        
        let server = Keychain.ThreemaSafeServerInfo(
            user: "safe_user",
            password: "safe_password",
            server: "safe.threema.ch"
        )
        try keychainManager.storeThreemaSafeServer(server)
        
        _ = try #require(try keychainManager.loadThreemaSafeServer())
        #expect(keychainMock.calls.count == 2)
        
        /// 3 from storing operation, 3 from loading
        #expect(cryptoMock.calls.count == 6)
        
        /// Verify the types of calls without caring about data, as the previous
        /// storing operations cleared up the data.
        let decryptFirstCallIndex = 3
        let decryptFirstCall = cryptoMock.calls[decryptFirstCallIndex]
        guard case .decryptDataToString = decryptFirstCall else {
            Issue.record("Expected decryptString at index \(decryptFirstCallIndex), but got \(decryptFirstCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptSecondCallIndex = 4
        let decryptSecondCall = cryptoMock.calls[decryptSecondCallIndex]
        guard case .decryptDataToString = decryptSecondCall else {
            // swiftformat:disable:next all
            Issue.record("Expected decryptDataToString at index \(decryptSecondCallIndex), but got \(decryptSecondCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let decryptThirdCallIndex = 5
        let decryptThirdCall = cryptoMock.calls[decryptThirdCallIndex]
        guard case .decryptData = decryptThirdCall else {
            Issue.record("Expected decryptData at index \(decryptThirdCallIndex), but got \(decryptThirdCall)")
            throw NSError(domain: "", code: -1)
        }
        
        let keychainCall = try #require(keychainMock.calls.last)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .threemaSafeServer())
        #expect(loadOperation.searchAccount == nil)
    }

    @Test
    func testLoadThreemaSafeServerNotFound() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try #require(try keychainManager.loadThreemaSafeServer() == nil)
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .load(loadOperation) = keychainCall else {
            Issue.record("Expected call to be .load, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isLoading == true)
        #expect(loadOperation.searchItem == .threemaSafeServer())
        #expect(loadOperation.searchAccount == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testDeleteThreemaSafeServer() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        try keychainManager.deleteThreemaSafeServer()
        #expect(keychainMock.calls.count == 1)
        
        let keychainCall = try #require(keychainMock.calls.first)
        guard case let .delete(keychainItem) = keychainCall else {
            Issue.record("Expected call to be .delete, but got \(keychainCall)")
            throw NSError(domain: "", code: -1)
        }
        
        #expect(keychainCall.isDeleting == true)
        #expect(keychainItem == .threemaSafeServer())
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test
    func testKeychainError() throws {
        let (
            keychainManager,
            keychainMock,
            cryptoMock,
            _
        ) = makeSUT()
        
        let expectedError = KeychainProviderError.loadFailed(osStatus: -1)
        keychainMock.updateError(.loadError(expectedError))
        
        #expect(throws: KeychainProviderError.self) {
            _ = try keychainManager.loadIdentity()
        }
        
        #expect(keychainMock.calls.count == 1)
        #expect(keychainMock.calls.first?.isLoading == true)
        #expect(cryptoMock.calls.isEmpty)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(isRemoteSecretEnabled: Bool = false) -> (
        KeychainManager,
        KeychainProviderMock,
        RemoteSecretCryptoMock,
        RemoteSecretManagerMock
    ) {
        let keychainMock = KeychainProviderMock()
        let cryptoMock = RemoteSecretCryptoMock()
        let remoteSecretManagerMock = RemoteSecretManagerMock(
            isRemoteSecretEnabled: isRemoteSecretEnabled,
            crypto: cryptoMock
        )
        
        let keychainManager = KeychainManager(
            remoteSecretManager: remoteSecretManagerMock,
            keychainProvider: keychainMock
        )
        
        return (
            keychainManager,
            keychainMock,
            cryptoMock,
            remoteSecretManagerMock
        )
    }
}

// MARK: Keychain Manager Helpers

extension KeychainManager {
    func storeTestIdentity(
        identity: String = "ECHOECHO",
        clientKey: Data = Data("clientKey".utf8),
        publicKey: Data = Data("publicKey".utf8),
        serverGroup: String = "serverGroup"
    ) throws -> Keychain.MyIdentity {
        let identity = Keychain.MyIdentity(
            identity: ThreemaIdentity(identity),
            clientKey: ThreemaClientKey(clientKey),
            publicKey: ThreemaPublicKey(publicKey),
            serverGroup: ServerGroup(serverGroup)
        )
        try storeIdentity(identity)
        return identity
    }
}

// MARK: - Keychain.MyIdentity + Equatable

extension Keychain.MyIdentity: Equatable {
    public static func == (lhs: Keychain.MyIdentity, rhs: Keychain.MyIdentity) -> Bool {
        lhs.$identity == rhs.$identity
            && lhs.$clientKey == rhs.$clientKey
            && lhs.$publicKey == rhs.$publicKey
            && lhs.$serverGroup == rhs.$serverGroup
    }
}
