import Foundation
import libthreemaSwift
import Testing

@testable import ThreemaFramework

@MainActor
@Suite("Nonce Provider Integration Tests")
struct NonceProviderTests {

    // MARK: - Has tests

    @Test func testHasReturnsTrueWhenNonceExists() throws {
        let sut = makeSUT()

        let nonce = hashedNonceSample1

        let before = try sut.has(hashedNonce: nonce)

        updateDatabaseByAddingNonces([nonce])

        let after = try sut.has(hashedNonce: nonce)

        #expect(before == false)
        #expect(after == true)
    }

    @Test func testHasReturnsFalseWhenNonceDoesNotExist() throws {
        let sut = makeSUT()

        updateDatabaseByAddingNonces([hashedNonceSample2])

        let result = try sut.has(hashedNonce: hashedNonceSample1)

        #expect(result == false)
    }

    @Test func testHasWithEmptyNonceData() throws {
        let sut = makeSUT()

        let empty = HashedNonce()

        let result = try sut.has(hashedNonce: empty)

        #expect(result == false)
    }

    @Test func testHasWithMaxSizeNonceData() throws {
        let sut = makeSUT()

        let maxData = Data(repeating: 0xAB, count: 32)
        let nonce = HashedNonce(maxData)

        let before = try sut.has(hashedNonce: nonce)

        updateDatabaseByAddingNonces([nonce])

        let after = try sut.has(hashedNonce: nonce)

        #expect(before == false)
        #expect(after == true)
    }

    @Test func testHasIsIdempotentForRepeatedCalls() throws {
        let sut = makeSUT()

        updateDatabaseByAddingNonces([hashedNonceSample1])

        let r1 = try sut.has(hashedNonce: hashedNonceSample1)
        let r2 = try sut.has(hashedNonce: hashedNonceSample1)
        let r3 = try sut.has(hashedNonce: hashedNonceSample1)

        #expect(r1 == true)
        #expect(r2 == true)
        #expect(r3 == true)
    }

    // MARK: - AddMany tests

    @Test func testAddManyInsertsSingleNonce() throws {
        let sut = makeSUT()

        try sut.addMany(hashedNonces: [hashedNonceSample1])

        #expect(try sut.has(hashedNonce: hashedNonceSample1) == true)
    }

    @Test func testAddManyInsertsMultipleNonces() throws {
        let sut = makeSUT()

        let batch = [hashedNonceSample1, hashedNonceSample2]

        try sut.addMany(hashedNonces: batch)

        #expect(try sut.has(hashedNonce: hashedNonceSample1))
        #expect(try sut.has(hashedNonce: hashedNonceSample2))
    }

    @Test func testAddManyWithEmptyArrayIsNoOp() throws {
        let sut = makeSUT()

        try sut.addMany(hashedNonces: [])

        let count = entityManager.entityFetcher.nonceEntities()?.count ?? 0

        #expect(count == 0)
    }

    @Test func testAddManySkipsDuplicateNoncesInInput() throws {
        let sut = makeSUT()

        let batch = [
            hashedNonceSample1,
            hashedNonceSample2,
            hashedNonceSample1,
        ]

        try sut.addMany(hashedNonces: batch)

        let count = entityManager.entityFetcher.nonceEntities()?.count ?? 0

        #expect(count == 2)
    }

    @Test func testAddManyWithExistingAndNewNonces() throws {
        let sut = makeSUT()

        updateDatabaseByAddingNonces([hashedNonceSample1])

        try sut.addMany(hashedNonces: [hashedNonceSample1, hashedNonceSample2])

        let count = entityManager.entityFetcher.nonceEntities()?.count ?? 0

        #expect(count == 2)
    }

    @Test func testAddManyIsIdempotentForSameInputTwice() throws {
        let sut = makeSUT()

        let batch = [hashedNonceSample1, hashedNonceSample2]

        try sut.addMany(hashedNonces: batch)
        try sut.addMany(hashedNonces: batch)

        let count = entityManager.entityFetcher.nonceEntities()?.count ?? 0

        #expect(count == 2)
    }

    @Test func testAddManyHandlesLargeBatchWithPerformanceCheck() throws {
        let sut = makeSUT()

        let batch = makeBatch(defaultBatchSize)

        let start = CFAbsoluteTimeGetCurrent()

        try sut.addMany(hashedNonces: batch)

        let duration = CFAbsoluteTimeGetCurrent() - start

        let stored = entityManager.entityFetcher.nonceEntities()?.count ?? 0

        #expect(stored == defaultBatchSize)
        #expect(duration < 1.0)
    }

    // MARK: - GetMany tests

    @Test func testGetManyReturnsFirstBatch() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(5)

        try sut.addMany(hashedNonces: all)

        let result = try sut.getMany(batchIndex: 0)

        #expect(result == all)
    }

    @Test func testGetManyReturnsMiddleBatch() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(15)

        try sut.addMany(hashedNonces: all)

        let result = try sut.getMany(batchIndex: 1)
        let expected = Array(all[5..<10])

        #expect(result == expected)
    }

    @Test func testGetManyReturnsLastPartialBatch() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(13)

        try sut.addMany(hashedNonces: all)

        let result = try sut.getMany(batchIndex: 2)
        let expected = Array(all[10..<13])

        #expect(result == expected)
    }

    @Test func testGetManyReturnsEmptyWhenStorageIsEmpty() throws {
        let sut = makeSUT()

        let result = try sut.getMany(batchIndex: 0)

        #expect(result.isEmpty)
    }

    @Test func testGetManyWithBatchIndexOutOfRangeReturnsEmpty() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(15)

        try sut.addMany(hashedNonces: all)

        let result = try sut.getMany(batchIndex: 10)

        #expect(result.isEmpty)
    }

    @Test func testGetManyRespectsBatchSizeLimit() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(5)

        try sut.addMany(hashedNonces: all)

        let result = try sut.getMany(batchIndex: 0)

        #expect(result.count <= 5)
    }

    @Test func testGetManyBatchesDoNotOverlap() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(10)

        try sut.addMany(hashedNonces: all)

        let b1 = try sut.getMany(batchIndex: 0)
        let b2 = try sut.getMany(batchIndex: 1)

        let overlap = Set(b1).intersection(Set(b2))

        #expect(overlap.isEmpty)
    }

    @Test func testGetManyIsDeterministicAcrossCalls() throws {
        let sut = makeSUT(batchSize: 5)

        let all = makeBatch(5)

        try sut.addMany(hashedNonces: all)

        let a = try sut.getMany(batchIndex: 0)
        let b = try sut.getMany(batchIndex: 0)

        #expect(a == b)
    }

    @Test func testGetManyWithSingleNonce() throws {
        let sut = makeSUT(batchSize: 5)

        let nonce = HashedNonce(repeating: 0x11, count: 32)

        try sut.addMany(hashedNonces: [nonce])

        let result = try sut.getMany(batchIndex: 0)

        #expect(result.count == 1)
    }

    @Test func testGetManyWithBatchIndexOverflowThrows() throws {
        let sut = makeSUT()

        let batchSize = defaultBatchSize
        let max = UInt64(Int.max / batchSize)

        #expect(throws: ProviderError.self) {
            _ = try sut.getMany(batchIndex: max + 1)
        }
    }

    // MARK: - Concurrency tests

    @Test func testConcurrentAddManyAndHas() async throws {
        let sut = makeSUT()

        let b1 = makeBatch(1000)
        let b2 = makeBatch(1000, offset: 1000)
        let b3 = makeBatch(1000, offset: 2000)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try sut.addMany(hashedNonces: b1) }
            group.addTask { try sut.addMany(hashedNonces: b2) }
            group.addTask { try sut.addMany(hashedNonces: b3) }

            for try await _ in group { }
        }

        let sample = (b1 + b2 + b3).randomElement()!

        #expect(try sut.has(hashedNonce: sample))
    }

    @Test func testConcurrentGetManyCallsDifferentBatches() async throws {
        let sut = makeSUT(batchSize: 80)

        let total = makeBatch(240)

        try sut.addMany(hashedNonces: total)

        var results: [Int: [HashedNonce]] = [:]

        try await withThrowingTaskGroup(of: (Int, [HashedNonce]).self) { group in
            for i in 0..<3 {
                group.addTask {
                    try (i, sut.getMany(batchIndex: UInt64(i)))
                }
            }

            for try await (index, batch) in group {
                results[index] = batch
            }
        }

        let flat = results.values.flatMap(\.self)

        #expect(flat.count == 240)
    }

    // MARK: - Helpers

    private let defaultBatchSize = 1 << 15

    private let testDatabase = TestDatabase()

    private var entityManager: EntityManager {
        testDatabase.entityManager
    }

    private var hashedNonceSample1: HashedNonce {
        HashedNonce(repeating: 0x35, count: 32)
    }

    private var hashedNonceSample2: HashedNonce {
        HashedNonce(repeating: 0x42, count: 32)
    }

    private func makeSUT(batchSize: Int = 1 << 15) -> ThreemaFramework.NonceProvider {
        NonceProvider(entityManager: entityManager, batchSize: batchSize)
    }

    private func makeBatch(_ count: Int, offset: Int = 0) -> [HashedNonce] {
        (0..<count).map { i in
            HashedNonce(makeNonceData(i + offset))
        }
    }

    // Creates a deterministic 32-byte nonce used for unit and integration tests.
    ///
    /// The value is fully deterministic and derived from the input integer `i`.
    /// Only the first 4 bytes are used to encode the integer in big-endian format.
    /// The remaining 28 bytes are zeroed.
    ///
    /// This ensures:
    /// - Uniqueness for typical test ranges (up to Int32 space)
    /// - Stable ordering across runs
    /// - No dependency on randomness or external state
    ///
    /// - Parameter i: Integer seed used to generate the nonce.
    /// - Returns: A 32-byte `Data` value representing a deterministic nonce.
    private func makeNonceData(_ i: Int) -> Data {
        var data = Data(repeating: 0, count: 32)

        data[0] = UInt8((i >> 24) & 0xFF)
        data[1] = UInt8((i >> 16) & 0xFF)
        data[2] = UInt8((i >> 8) & 0xFF)
        data[3] = UInt8(i & 0xFF)

        return data
    }

    private func updateDatabaseByAddingNonces(_ nonces: [HashedNonce]) {
        entityManager.performAndWaitSave {
            for n in nonces {
                _ = entityManager.entityCreator.nonceEntity(for: n)
            }
        }
    }
}
