import ThreemaFramework

final class FeatureMaskMock: FeatureMaskProtocol {
    static var updateLocalCalls = 0
    
    static func updateLocal() async throws {
        updateLocalCalls += 1
    }
}
