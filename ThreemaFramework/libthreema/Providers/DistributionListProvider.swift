import libthreemaSwift

final class DistributionListProvider: libthreemaSwift.DistributionListProvider {
    // swiftformat:disable:next acronyms
    func getIds() throws -> Set<LibthreemaDistributionListID> {
        // Distribution list are not supported in iOS
        []
    }
    
    func get(id: LibthreemaDistributionListID) throws -> libthreemaSwift.DistributionList? {
        // Distribution list are not supported in iOS
        nil
    }
    
    func add(distributionLists: [libthreemaSwift.DistributionList]) throws {
        // Distribution list are not supported in iOS
    }
}
