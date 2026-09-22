import Foundation
import ThreemaProtocols
@testable import GroupCalls

final class MockHTTPClient: GroupCallHTTPClientAdapterProtocol {
    typealias CallID = Data
    typealias PeekResponse = ThreemaProtocols.GroupCall_SfuHttpResponse.Peek
    
    fileprivate let returnData: Data!
    fileprivate let response: URLResponse!
    
    var responses = [CallID: [(PeekResponse?, URLResponse)]]()
    var autoDropResponses = false

    /// Errors thrown from `sendPeek` (FIFO, consumed before `responses` is considered)
    var scriptedPeekErrors = [CallID: [Error]]()
    /// Delay applied before `sendPeek` answers, to simulate an unresponsive SFU
    var peekHangSeconds = [CallID: TimeInterval]()
    /// Delay applied before a join request answers, to keep a call in the `Joining` state
    var joinHangSeconds: TimeInterval?

    var lock = NSLock()
    
    convenience init(returnCode: Int) {
        let url = URL(string: "http://threema.com")!
        
        let urlResponse = HTTPURLResponse(url: url, statusCode: returnCode, httpVersion: nil, headerFields: nil)!
        
        self.init(returnData: Data(), urlResponse: urlResponse)
    }
    
    convenience init() {
        let url = URL(string: "http://threema.com")!
        
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        self.init(returnData: Data(), urlResponse: urlResponse)
    }
    
    init(returnData: Data, urlResponse: URLResponse) {
        self.response = urlResponse
        self.returnData = returnData
    }
    
    init(authorization: String?) {
        // Noop
        
        let url = URL(string: "http://threema.com")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        self.returnData = Data()
        self.response = urlResponse
        
        fatalError()
    }
    
    func sendPeek(authorization: String, url: URL, body: Data) async throws -> (Data, URLResponse) {
        if url.pathComponents.contains("join"), let hangSeconds = lock.withLock({ joinHangSeconds }) {
            try await Task.sleep(nanoseconds: UInt64(hangSeconds * 1_000_000_000))
        }

        if let callID = url.lastPathComponent.hexadecimal,
           let hangSeconds = lock.withLock({ peekHangSeconds[callID] }) {
            try await Task.sleep(nanoseconds: UInt64(hangSeconds * 1_000_000_000))
        }

        return try lock.withLock {
            if let callID = url.lastPathComponent.hexadecimal,
               var errors = scriptedPeekErrors[callID], !errors.isEmpty {
                let error = errors.removeFirst()
                scriptedPeekErrors[callID] = errors
                throw error
            }

            if let callID = url.lastPathComponent.hexadecimal,
               let response = autoDropResponses ? responses[callID]?.removeFirst() : responses[callID]?.first! {
                print("Returning http code \((response.1 as! HTTPURLResponse).statusCode)")
                return ((try! response.0?.ownSerializedData()) ?? Data(), response.1)
            }
            else {
                return (returnData, response)
            }
        }
    }
}
