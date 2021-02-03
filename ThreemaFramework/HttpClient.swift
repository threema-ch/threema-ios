//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

public class HttpClient {
    
    public enum ContentType {
        case json
        case octetStream
        func propertyValue() -> String {
            switch self {
            case .json:
                return "application/json"
            case .octetStream:
                return "application/octet-stream"
            }
        }
    }
    
    private static let bgSessionsMutationLock: DispatchQueue = DispatchQueue(label: "bgSessionsMutationLock")
    private static var bgSessions: [Int: URLSession] = [Int: URLSession]()
    
    public init() { }
    
    public func delete(url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let request = getRequest(url: url, httpMethod: "DELETE")
        let task = getSession(delegate: nil).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
    
    public func downloadData(url: URL, contentType: ContentType, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> Void {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue(contentType.propertyValue(), forHTTPHeaderField: "Accept")
        
        let task = getSession(delegate: nil).dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
    
    public func downloadData(url: URL, delegate: URLSessionDelegate) -> Void {
        var request = getRequest(url: url, httpMethod: "GET")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let task = getSession(delegate: delegate).dataTask(with: request)
        task.resume()
    }
    
    public func uploadData(url: URL, data: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> Void {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(delegate: nil).uploadTask(with: request, from: data, completionHandler: completionHandler)
        task.resume()
    }
    
    public func uploadData(url: URL, file: URL, delegate: URLSessionDelegate) -> Void {
        var request = getRequest(url: url, httpMethod: "PUT")
        request.setValue(ContentType.octetStream.propertyValue(), forHTTPHeaderField: "Content-Type")
        
        let task = getSession(delegate: delegate).uploadTask(with: request, fromFile: file)
        task.resume()
    }
    
    private func getRequest(url: URL, httpMethod: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 900)
        request.httpMethod = httpMethod
        return request
    }
    
    private func getSession(identifier: Int, delegate: URLSessionDelegate) -> URLSession {
        var bgSession: URLSession? = nil

        HttpClient.bgSessionsMutationLock.sync {
            
            if let session = HttpClient.bgSessions[identifier] {
                bgSession = session
            } else {
                let configuration = URLSessionConfiguration.background(withIdentifier: String(identifier))
                configuration.allowsCellularAccess = true
                configuration.sessionSendsLaunchEvents = true
                if #available(iOSApplicationExtension 11.0, *) {
                    configuration.waitsForConnectivity = true
                }
                
                let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
                HttpClient.bgSessions[identifier] = session
                
                bgSession = session
            }
            
        }
        
        return bgSession!
    }
        
    private func getSession(delegate: URLSessionDelegate?) -> URLSession {
        if let delegate = delegate {
            let objectHash: Int = delegate.hash
            return getSession(identifier: objectHash, delegate: delegate)
        }

        URLSession.shared.configuration.allowsCellularAccess = true
        if #available(iOSApplicationExtension 11.0, *) {
            URLSession.shared.configuration.waitsForConnectivity = true
        }
        return URLSession.shared
    }
}
