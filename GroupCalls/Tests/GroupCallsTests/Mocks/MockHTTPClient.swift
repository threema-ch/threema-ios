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
import ThreemaProtocols
@testable import GroupCalls

final class MockHTTPClient: GroupCallHTTPClientAdapterProtocol {
    typealias CallID = Data
    typealias PeekResponse = ThreemaProtocols.Groupcall_SfuHttpResponse.Peek
    
    fileprivate let returnData: Data!
    fileprivate let response: URLResponse!
    
    var responses = [CallID: [(PeekResponse?, URLResponse)]]()
    var autoDropResponses = false
    
    var lock = NSLock()
    
    convenience init(returnCode: Int) {
        let url = URL(string: "http://threema.ch")!
        
        let urlResponse = HTTPURLResponse(url: url, statusCode: returnCode, httpVersion: nil, headerFields: nil)!
        
        self.init(returnData: Data(), urlResponse: urlResponse)
    }
    
    convenience init() {
        let url = URL(string: "http://threema.ch")!
        
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        self.init(returnData: Data(), urlResponse: urlResponse)
    }
    
    init(returnData: Data, urlResponse: URLResponse) {
        self.response = urlResponse
        self.returnData = returnData
    }
    
    init(authorization: String?) {
        // Noop
        
        let url = URL(string: "http://threema.ch")!
        let urlResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        self.returnData = Data()
        self.response = urlResponse
        
        fatalError()
    }
    
    func sendPeek(authorization: String, url: URL, body: Data) async throws -> (Data, URLResponse) {
        lock.withLock {
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
