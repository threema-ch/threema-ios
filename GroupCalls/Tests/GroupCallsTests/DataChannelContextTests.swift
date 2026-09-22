import Foundation
import XCTest
@testable import GroupCalls
@testable import WebRTC

final class DataChannelContextTests: XCTestCase {
    
    /// Messages that are received after the data channel changed to `closed` are dropped, i.e. the message stream
    /// delivers exactly the messages that were received before.
    func testMessagesAfterCloseByStateChangeAreDropped() async throws {
        let mockDataChannel = MockRTCDataChannel()
        let dataChannelCtx = DataChannelContext(dataChannel: mockDataChannel)
        
        let expectation = XCTestExpectation(description: "CorrectNumberOfMessages")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 120

        Task.detached {
            for await _ in dataChannelCtx.messageStream {
                expectation.fulfill()
            }
        }
        
        for i in 0..<120 {
            let buffer = RTCDataBuffer(data: Data(count: i), isBinary: true)
            dataChannelCtx.dataChannel(didReceiveMessageWith: buffer)
        }
        
        dataChannelCtx.dataChannelDidChangeState(.closed)
        
        for i in 0..<120 {
            let buffer = RTCDataBuffer(data: Data(count: i), isBinary: true)
            dataChannelCtx.dataChannel(didReceiveMessageWith: buffer)
        }
        
        await Task.yield()

        await fulfillment(of: [expectation], timeout: 10)
    }

    /// Messages that are received after the data channel was closed by us are dropped as well.
    func testMessagesAfterOutsideCloseAreDropped() async throws {
        let mockDataChannel = MockRTCDataChannel()
        let dataChannelCtx = DataChannelContext(dataChannel: mockDataChannel)
        
        let expectation = XCTestExpectation(description: "CorrectNumberOfMessages")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 120
        
        Task.detached {
            for await _ in dataChannelCtx.messageStream {
                expectation.fulfill()
            }
        }
        
        for i in 0..<120 {
            let buffer = RTCDataBuffer(data: Data(count: i), isBinary: true)
            dataChannelCtx.dataChannel(didReceiveMessageWith: buffer)
        }
        
        dataChannelCtx.close()
        
        for i in 0..<120 {
            let buffer = RTCDataBuffer(data: Data(count: i), isBinary: true)
            dataChannelCtx.dataChannel(didReceiveMessageWith: buffer)
        }
        
        await Task.yield()

        await fulfillment(of: [expectation], timeout: 10)
    }
}
