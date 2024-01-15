//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest
@testable import GroupCalls
@testable import WebRTC

final class DataChannelCtxTests: XCTestCase {
    
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
