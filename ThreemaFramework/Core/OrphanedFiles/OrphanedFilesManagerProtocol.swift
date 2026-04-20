public protocol OrphanedFilesManagerProtocol {
    func getOrphanedFilesData() -> (orphaned: [String], totalCount: Int)
}
