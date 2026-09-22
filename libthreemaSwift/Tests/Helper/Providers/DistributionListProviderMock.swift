import Foundation
import libthreemaSwift

final class DistributionListProviderMock: libthreemaSwift.DistributionListProvider {
    // swiftformat:disable:next acronyms
    func getIds() throws -> [LibthreemaDistributionListID] {
        []
    }
    
    func get(id: LibthreemaDistributionListID) throws -> libthreemaSwift.DistributionList? {
        throw ProviderError.InvalidState("Not implemented yet")
    }
    
    func add(distributionLists: [libthreemaSwift.DistributionList]) throws {
        throw ProviderError.InvalidState("Not implemented yet")
    }
}
