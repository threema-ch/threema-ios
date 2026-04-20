import Foundation
import XCTest
@testable import GroupCalls
@testable import WebRTC

final class DataChannelContextTests: XCTestCase {
    
    func testBasicInit() async throws {
        let mockDataChannel = MockRTCDataChannel()
        let dataChannelCtx = DataChannelContext(dataChannel: mockDataChannel)
        
        let expectation = XCTestExpectation(description: "CorrectNumberOfMessages")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 120
        
        Task.detached {
            for await message in dataChannelCtx.messageStream {
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
        
        print("Start wait for expectation")
        wait(for: [expectation], timeout: 120)
    }
    
    func testOutsideClose() async throws {
        let mockDataChannel = MockRTCDataChannel()
        let dataChannelCtx = DataChannelContext(dataChannel: mockDataChannel)
        
        let expectation = XCTestExpectation(description: "CorrectNumberOfMessages")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 120
        
        Task.detached {
            for await message in dataChannelCtx.messageStream {
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
        
        print("Start wait for expectation")
        wait(for: [expectation], timeout: 120)
    }
}
