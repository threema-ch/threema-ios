import Foundation
import libthreemaSwift

final class PollProviderMock: libthreemaSwift.PollProvider {
    func getMany(batchIndex: UInt64) throws -> [libthreemaSwift.Poll] {
        throw ProviderError.InvalidState("Not implemented yet")
    }
    
    func add(polls: [libthreemaSwift.Poll]) throws {
        throw ProviderError.InvalidState("Not implemented yet")
    }
}
