import libthreemaSwift

final class DistributionListProvider: libthreemaSwift.DistributionListProvider {
    // swiftformat:disable:next acronyms
    func getIds() throws -> [LibthreemaDistributionListID] {
        [] // TOOD: Implement
    }
    
    func get(id: LibthreemaDistributionListID) throws -> libthreemaSwift.DistributionList? {
        nil // TOOD: Implement
    }
    
    func add(distributionLists: [libthreemaSwift.DistributionList]) throws {
        // TOOD: Implement
    }
}
