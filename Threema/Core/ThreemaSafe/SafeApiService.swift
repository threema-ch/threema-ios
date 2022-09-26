//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

@objc class SafeApiService: NSObject {
    
    enum SafeApiError: Error {
        case invalidServerURL
        case requestFailed(message: String)
        case uploadTempFileCouldNotBeSaved(error: NSError)
    }
    
    func testServer(server: URL, user: String?, password: String?) -> (serverConfig: Data?, errorMessage: String?) {
        var serverConfig: Data?
        var errorMessage: String?
        
        // validate and test safe server
        let queue = DispatchQueue.global()
        let semaphore = DispatchSemaphore(value: 0)
        
        queue.async {
            self.getHttpClient(user: user, password: password) { client in
                client
                    .downloadData(
                        url: server.appendingPathComponent("config"),
                        contentType: .json
                    ) { data, response, error in
                    
                        let result = self.processResponse(data: data, response: response, error: error)
                        if let responseData = result.data {
                            serverConfig = responseData
                        }
                        if let responseErrorMessage = result.errorMessage {
                            errorMessage = responseErrorMessage
                        }
                    
                        semaphore.signal()
                    }
            }
        }
        
        semaphore.wait()
        
        return (serverConfig, errorMessage)
    }
    
    func delete(server: URL, user: String?, password: String?) -> String? {
        var errorMessage: String?
        
        let dispatch = DispatchGroup()
        dispatch.enter()
        
        DispatchQueue.global(qos: .background).async {
            self.getHttpClient(user: user, password: password) { client in
                client.delete(url: server) { data, response, error in
                    
                    let result = self.processResponse(data: data, response: response, error: error)
                    if let responseErrorMessage = result.errorMessage {
                        errorMessage = responseErrorMessage
                    }
                    dispatch.leave()
                }
            }
        }
        
        dispatch.wait()

        return errorMessage
    }
    
    func upload(
        backup: URL,
        user: String?,
        password: String?,
        encryptedData: [UInt8],
        completionHandler: @escaping (Data?, String?) -> Void
    ) {
        getHttpClient(user: user, password: password) { client in
            client.uploadData(url: backup, data: Data(encryptedData)) { data, response, error in
                let result = self.processResponse(data: data, response: response, error: error)
                completionHandler(result.data, result.errorMessage)
            }
        }
    }
    
    func download(backup: URL, user: String?, password: String?) throws -> Data? {
        var errorMessage: String?
        var encryptedData: Data?
        
        let dispatch = DispatchGroup()
        dispatch.enter()
            
        DispatchQueue.global(qos: .background).async {
            self.getHttpClient(user: user, password: password) { client in
                client.downloadData(url: backup, contentType: .octetStream) { data, response, error in
                    let result = self.processResponse(data: data, response: response, error: error)
                    if let responseData = result.data {
                        encryptedData = responseData
                    }
                    if let responseErrorMessage = result.errorMessage {
                        errorMessage = responseErrorMessage
                    }
                    dispatch.leave()
                }
            }
        }
        
        dispatch.wait()
        
        if let message = errorMessage {
            throw SafeApiError.requestFailed(message: message)
        }
        
        return encryptedData
    }
    
    private func processResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) -> (data: Data?, errorMessage: String?) {
        var errorMessage: String?
        
        if let error = error {
            errorMessage = error.localizedDescription
            return (nil, errorMessage)
        }
        guard let response = response as? HTTPURLResponse else {
            errorMessage = "response is missing"
            if let data = data {
                print("\(String(describing: String(data: data, encoding: .utf8)))")
            }
            return (nil, errorMessage)
        }
        
        if !(200...299).contains(response.statusCode) {
            errorMessage = "response code \(response.statusCode)"
            if let data = data {
                print("\(String(describing: String(data: data, encoding: .utf8)))")
            }
            return (nil, errorMessage)
        }
        
        guard let data = data else {
            errorMessage = "response data/config is missing"
            return (nil, errorMessage)
        }

        return (data, nil)
    }
    
    private func getHttpClient(user: String?, password: String?, completion: @escaping (HttpClient) -> Void) {
        if user != nil, password != nil {
            completion(HttpClient(user: user, password: password))
        }
        else {
            AuthTokenManager.shared().obtainToken { authToken, _ in
                if authToken != nil {
                    let authorization = "Token " + authToken!
                    completion(HttpClient(authorization: authorization))
                }
                else {
                    completion(HttpClient(user: user, password: password))
                }
            }
        }
    }
}
