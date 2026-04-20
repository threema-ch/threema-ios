public protocol TrashBinManagerProtocol {
    func getTrashBinFilesData() -> (files: [String], size: Int64)

    func moveToTrashBin(_ files: [String])

    func restoreTrashBin()

    func emptyTrashBin()
}
