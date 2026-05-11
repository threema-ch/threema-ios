import ThreemaFramework

final class WorkDataFetcherMock: WorkDataFetcherProtocol {
    var checkUpdateWorkData = [(force: Bool, forceSendMDM: Bool)]()
    var resetLastSyncCount = 0

    func checkUpdateWorkData(force: Bool, forceSendMDM: Bool) async throws {
        checkUpdateWorkData.append((force: force, forceSendMDM: forceSendMDM))
    }

    func resetLastSync() {
        resetLastSyncCount += 1
    }
}
