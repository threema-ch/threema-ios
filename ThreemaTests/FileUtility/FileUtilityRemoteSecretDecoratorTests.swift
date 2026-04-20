import FileUtility
import FileUtilityTestHelper
import Foundation
import RemoteSecretProtocolTestHelper
import Testing
@testable import RemoteSecret
@testable import RemoteSecretProtocol
@testable import ThreemaFramework

@Suite("FileUtilityRemoteSecretDecoratorTests")
struct FileUtilityRemoteSecretDecoratorTests {
    
    @Test("Properties delegate to wrapped implementation")
    func testDecoratorPropertyDelegation() throws {
        let (fileUtilityDecorator, fileUtility, _, _) = try makeSUT()
        
        #expect(fileUtilityDecorator.appDocumentsDirectory == fileUtility.appDocumentsDirectory)
        #expect(fileUtilityDecorator.appCachesDirectory == fileUtility.appCachesDirectory)
        #expect(fileUtilityDecorator.appTemporaryDirectory == fileUtility.appTemporaryDirectory)
        #expect(fileUtilityDecorator.appTemporaryUnencryptedDirectory == fileUtility.appTemporaryUnencryptedDirectory)
    }
    
    @Test("Encrypt and decrypts data when remote secret is enabled")
    func testEncryptAndDecryptData() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: true)
        let testURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("test_read_decrypt.txt")
        let encryptedData = Data("encrypted".utf8)
        
        defer { cleanupTestFile(at: testURL) }
        
        #expect(fileUtilityDecorator.write(contents: encryptedData, to: testURL) == true)
        
        let result = fileUtilityDecorator.read(fileURL: testURL)
        
        #expect(result != nil)
        #expect(cryptoMock.calls.count == 2)
        
        if case let .encryptData(data) = cryptoMock.calls.first {
            #expect(data == encryptedData)
        }
        else {
            Issue.record("Expected encrypt call not found")
        }
        
        guard case .decryptData = cryptoMock.calls.last else {
            Issue.record("Expected decrypt call not found")
            return
        }
    }
    
    @Test("Read returns nil when file doesn't exist", arguments: [true, false])
    func testReadReturnsNilForNonExistentFile(isRemoteSecretEnabled: Bool) throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: isRemoteSecretEnabled)
        let nonExistentURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("non_existent.txt")

        let result = fileUtilityDecorator.read(fileURL: nonExistentURL)

        #expect(result == nil)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test("Does not encrypt or decrypt when URL is whitelisted")
    func testDoesNotEncryptOrDecryptWhenWhitelistedURL() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(
            isRemoteSecretEnabled: true,
            whitelist: ["whitelist"]
        )
        let testURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("whitelist_test.txt")
        let data = Data("test data".utf8)

        defer { cleanupTestFile(at: testURL) }

        #expect(fileUtilityDecorator.write(contents: data, to: testURL) == true)

        let result = fileUtilityDecorator.read(fileURL: testURL)

        #expect(result == data)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test("Encrypt or decrypt when data is empty with remote secret enabled")
    func testEmptyDataWithRemoteSecret() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: true)
        let testURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("empty_file.txt")

        defer { cleanupTestFile(at: testURL) }

        let emptyData = Data()
        #expect(fileUtilityDecorator.write(contents: emptyData, to: testURL) == true)

        let result = fileUtilityDecorator.read(fileURL: testURL)

        #expect(result == emptyData)
        #expect(cryptoMock.calls.count == 2)
            
        if case let .encryptData(data) = cryptoMock.calls.first {
            #expect(data == emptyData)
        }
        else {
            Issue.record("Expected encrypt call not found")
        }
            
        guard case .decryptData = cryptoMock.calls.last else {
            Issue.record("Expected decrypt call not found")
            return
        }
    }
    
    @Test("Does not encrypt or decrypt when data is empty")
    func testEmptyDataWithoutRemoteSecret() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: false)
        let testURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("empty_file.txt")

        defer { cleanupTestFile(at: testURL) }

        let emptyData = Data()
        #expect(fileUtilityDecorator.write(contents: emptyData, to: testURL) == true)

        let result = fileUtilityDecorator.read(fileURL: testURL)

        #expect(result == emptyData)
        #expect(cryptoMock.calls.isEmpty)
    }
    
    @Test("Write handles nil data", arguments: [true, false])
    func testWriteHandlesNilDataCorrectly(isRemoteSecretEnabled: Bool) throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: isRemoteSecretEnabled)
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("nil_write.txt")

        defer { cleanupTestFile(at: testURL) }

        let result = fileUtilityDecorator.write(contents: nil, to: testURL)

        #expect(result == true)
        #expect(cryptoMock.calls.isEmpty)
    }

    @Test("Does not encrypt or decrypt when remote secret is disabled")
    func testDoesNotEncryptOrDecryptWhenRemoteSecretDisabled() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(isRemoteSecretEnabled: false)
        let testURL = fileUtilityDecorator.appTemporaryDirectory.appendingPathComponent("test_no_decrypt.txt")
        let data = Data("plain text".utf8)

        defer { cleanupTestFile(at: testURL) }

        #expect(fileUtilityDecorator.write(contents: data, to: testURL) == true)

        let result = fileUtilityDecorator.read(fileURL: testURL)

        #expect(result == data)
        #expect(cryptoMock.calls.isEmpty)
    }
    
    @Test("Whitelist properly excludes multiple paths")
    func testWhitelistMultiplePaths() throws {
        let (fileUtilityDecorator, _, _, cryptoMock) = try makeSUT(
            isRemoteSecretEnabled: true,
            whitelist: ["public", "shared", "unencrypted"]
        )
        let directoryURL = fileUtilityDecorator.appTemporaryDirectory

        let publicURL = directoryURL.appendingPathComponent("public_file.txt")
        let sharedURL = directoryURL.appendingPathComponent("shared_data.bin")
        let unencryptedURL = directoryURL.appendingPathComponent("unencrypted_file.txt")
        let privateURL = directoryURL.appendingPathComponent("private_secret.txt")

        defer {
            [
                publicURL,
                sharedURL,
                unencryptedURL,
                privateURL,
            ].forEach { url in
                cleanupTestFile(at: url)
            }
        }

        let testData = Data("test".utf8)

        // Whitelisted URLs should not encrypt
        #expect(fileUtilityDecorator.write(contents: testData, to: publicURL) == true)
        #expect(fileUtilityDecorator.write(contents: testData, to: sharedURL) == true)
        #expect(fileUtilityDecorator.write(contents: testData, to: unencryptedURL) == true)
        
        #expect(cryptoMock.encryptCalls == 0)

        // Non-whitelisted URL should encrypt
        #expect(fileUtilityDecorator.write(contents: testData, to: privateURL) == true)

        #expect(cryptoMock.encryptCalls == 1)
    }

    // MARK: - Test Helpers
    
    private func makeSUT(
        isRemoteSecretEnabled: Bool = true,
        whitelist: Set<String> = []
    ) throws -> (
        fileUtilityDecorator: FileUtilityRemoteSecretDecorator,
        fileUtility: FileUtility,
        remoteSecretManagerMock: RemoteSecretManagerMock,
        cryptoMock: RemoteSecretCryptoMock
    ) {
        let fileUtility = FileUtility()
        let remoteSecretCrypto = try RemoteSecretCrypto(
            remoteSecret: RemoteSecret(rawValue: Data(repeating: 1, count: 32))
        )
        let crypto = RemoteSecretCryptoMock(wrapped: remoteSecretCrypto)
        let remoteSecretManager = RemoteSecretManagerMock(
            isRemoteSecretEnabled: isRemoteSecretEnabled,
            crypto: crypto
        )
        let fileUtilityDecorator = FileUtilityRemoteSecretDecorator(
            wrapped: fileUtility,
            remoteSecretManager: remoteSecretManager,
            whitelist: whitelist
        )
        
        return (fileUtilityDecorator, fileUtility, remoteSecretManager, crypto)
    }
    
    private func cleanupTestFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
