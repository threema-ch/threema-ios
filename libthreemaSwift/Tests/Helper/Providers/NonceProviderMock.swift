import Foundation
import libthreemaSwift
import ThreemaEssentials

/// NonceProviderMock implementation.
/// Stub simple result:
/// ```
/// mock.hasResult = .success(true)
/// ```
/// Or dynamic behavior
/// ```
/// mock.getManyHandler = { index in
///     if index == 0 { return [nonce1, nonce2] }
///     return []
/// }
/// ```
final class NonceProviderMock: libthreemaSwift.NonceProvider, @unchecked Sendable {

    typealias HashedNonce = libthreemaSwift.HashedNonce

    // MARK: - Call tracking

    @Atomic private(set) var hasCalls: [HashedNonce] = []
    @Atomic private(set) var addManyCalls: [[HashedNonce]] = []
    @Atomic private(set) var getManyCalls: [UInt64] = []

    // MARK: - Stubbing

    @Atomic var hasResult: Result<Bool, Error> = .success(false)
    @Atomic var getManyResult: Result<[HashedNonce], Error> = .success([])
    @Atomic var addManyError: Error?
    @Atomic var hasHandler: ((HashedNonce) throws -> Bool)?
    @Atomic var getManyHandler: ((UInt64) throws -> [HashedNonce])?
    @Atomic var addManyHandler: (([HashedNonce]) throws -> Void)?

    // MARK: - API

    func has(hashedNonce: HashedNonce) throws -> Bool {
        $hasCalls.append(hashedNonce)

        if let handler = hasHandler {
            return try handler(hashedNonce)
        }

        return try hasResult.get()
    }

    func addMany(hashedNonces: [HashedNonce]) throws {
        $addManyCalls.append(hashedNonces)

        if let handler = addManyHandler {
            try handler(hashedNonces)
            return
        }

        if let error = addManyError {
            throw error
        }
    }

    func getMany(batchIndex: UInt64) throws -> [HashedNonce] {
        $getManyCalls.append(batchIndex)

        if let handler = getManyHandler {
            return try handler(batchIndex)
        }

        return try getManyResult.get()
    }
}
