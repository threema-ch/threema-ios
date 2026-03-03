//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

extension HttpsRequest {
    /// Creates an ``URLRequest`` from a ``HttpsRequest``
    public func asURLRequest() throws -> URLRequest {
        guard let url = URL(string: url) else {
            DDLogError("[HttpsRequest] received invalid url")
            throw HttpsError.InvalidRequest("[HttpsRequest] Invalid url")
        }
        
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.string
        
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        request.httpBody = body
        
        return request
    }
}
