import Foundation
import libthreemaSwift

/// Core Data backed implementation of `libthreemaSwift.NonceProvider`.
///
/// This provider manages storage, lookup, and deterministic batching of hashed nonces.
/// It ensures deduplication on insertion and provides stable, paginated access to stored
/// values for protocol operations that require read-only batch processing.
///
/// The provider is optimized for large datasets and uses chunked database access patterns
/// to avoid memory and query limitations. All operations are designed to work with
/// Core Data as the persistence layer, relying on indexed attributes for performance.
///
/// - Important: Batching is deterministic and depends on stable ordering in the underlying store.
/// - Important: The provider assumes exclusive or read-only access during batching operations.
final class NonceProvider: libthreemaSwift.NonceProvider {
    typealias HashedNonce = libthreemaSwift.HashedNonce

    private nonisolated(unsafe) let entityManager: EntityManager
    private let batchSize: Int

    /// Creates a new `NonceProvider` instance.
    ///
    /// - Parameters:
    ///   - entityManager: Core Data manager responsible for persistence operations.
    ///   - batchSize: Number of nonces per batch. Default is 32768 (2^15).
    ///                This value is aligned with protocol requirements for efficient processing
    ///                of large nonce datasets.
    init(entityManager: EntityManager, batchSize: Int = 1 << 15) {
        self.entityManager = entityManager
        self.batchSize = batchSize
    }

    /// Checks whether the given hashed nonce already exists in the storage.
    ///
    /// This method performs a lookup in the associated context and returns
    /// a Boolean value indicating presence. It is considered infallible
    /// and is not expected to fail.
    ///
    /// - Parameter hashedNonce: The `HashedNonce` to look up.
    /// - Returns: `true` if the nonce exists in storage, otherwise `false`.
    /// - Throws: This method is not expected to throw. Any thrown error indicates an unexpected failure.
    func has(hashedNonce: HashedNonce) throws -> Bool {
        entityManager.entityFetcher.isNonceEntityAlreadyInDB(hashedNonce)
    }

    /// Stores the given hashed nonces in the underlying storage.
    ///
    /// Existing nonces are ignored, meaning duplicates are skipped if already present.
    /// This method is considered infallible and is not expected to fail.
    ///
    /// - Parameter hashedNonces: An array of `HashedNonce` values to be stored.
    /// - Throws: This method is not expected to throw. Any thrown error indicates an unexpected failure.
    func addMany(hashedNonces: [HashedNonce]) throws {
        let uniqueHashes = Array(Set(hashedNonces))

        let alreadyExisting = try entityManager.entityFetcher.existingNonces(in: uniqueHashes)

        let newOnes = uniqueHashes.filter { !alreadyExisting.contains($0) }

        guard !newOnes.isEmpty else {
            return
        }

        entityManager.performAndWaitSave {
            for hashedNonce in newOnes {
                _ = self.entityManager.entityCreator.nonceEntity(for: hashedNonce)
            }
        }
    }

    /// Deterministically partitions the stored hashed nonces into non-empty,
    /// incrementally zero-based batches and returns the batch at the given index.
    ///
    /// Batches must not overlap between calls. The surrounding protocol guarantees
    /// that this method is used only in an uninterruptible, read-only state.
    /// Each batch should contain approximately 2^15 hashed nonces.
    /// Returning an empty array signals that no further nonces are available.
    ///
    /// - Parameter batchIndex: The zero-based index of the batch to retrieve.
    /// - Returns: An array of `HashedNonce` for the requested batch, or an empty array if no more nonces are available.
    /// - Throws: `ProviderError` if `libthreema` provides invalid parameters.
    func getMany(batchIndex: UInt64) throws -> [HashedNonce] {
        guard batchIndex <= UInt64(Int.max / batchSize) else {
            throw ProviderError.ConversionError("Invalid Parameter batchIndex too large")
        }

        let start = Int(batchIndex) * batchSize

        return try entityManager.performAndWait {
            let entities: [NonceEntity] = try self.entityManager.entityFetcher.nonceEntities(
                offset: start,
                limit: self.batchSize
            ) ?? []

            // Defensive check (should never happen)
            guard entities.count <= self.batchSize else {
                throw ProviderError.ContractViolation("Fetcher returned more than batchSize")
            }

            return entities.map { HashedNonce($0.nonce) }
        }
    }
}
