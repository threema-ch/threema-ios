import Foundation
import libthreemaSwift

final class DistributionListProviderMock: libthreemaSwift.DistributionListProvider {
    // swiftformat:disable:next acronyms
    func getIds() throws -> Set<libthreemaSwift.DistributionListId> {
        []
    }
    
    func get(id: LibthreemaDistributionListID) throws -> libthreemaSwift.DistributionList? {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func add(distributionLists: [libthreemaSwift.DistributionList]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
}
