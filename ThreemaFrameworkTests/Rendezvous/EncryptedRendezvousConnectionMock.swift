import Foundation
@testable import ThreemaFramework

final class EncryptedRendezvousConnectionMock: EncryptedRendezvousConnection {
    
    private(set) var dataSent = [Data]()
    private(set) var receiveCallsCount = 0
    
    /// Called whenever `receive()` is called
    private var dataToReturnInReceiveHandler: (EncryptedRendezvousConnectionMock) throws -> Data
    
    init(dataToReturnInReceiveHandler: @escaping (EncryptedRendezvousConnectionMock) throws -> Data) {
        self.dataToReturnInReceiveHandler = dataToReturnInReceiveHandler
    }
    
    func connect() throws {
        // no-op
    }
    
    func receive() async throws -> Data {
        receiveCallsCount += 1
        
        return try dataToReturnInReceiveHandler(self)
    }
    
    func send(_ data: Data) async throws {
        dataSent.append(data)
    }
    
    func close() {
        // no-op
    }
}
