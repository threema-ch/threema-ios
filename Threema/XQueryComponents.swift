//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import CocoaLumberjackSwift

@objc extension NSString {
    func decodingURLFormat() -> String {
        var result = replacingOccurrences(of: "+", with: " ")
        result = result.removingPercentEncoding ?? ""
        return result
    }
    
    func encodingURLFormat() -> String {
        var result = replacingOccurrences(of: " ", with: "+")
        result = result.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlFragmentAllowed) ?? ""
        return result
    }
    
    @objc func dictionaryFromQueryComponents() -> [AnyHashable : Any]? {
        var queryComponents: [AnyHashable : Any] = [:]
        for keyValuePairString in components(separatedBy: "&") {
            let keyValuePairArray = keyValuePairString.components(separatedBy: "=")
            if keyValuePairArray.count < 2 {
                continue
            }
            let key = keyValuePairArray[0].decodingURLFormat()
            let value = keyValuePairArray[1].decodingURLFormat()
            var results = queryComponents[key] as? [AnyHashable]
            if results == nil {
                results = [AnyHashable]()
                results?.append(value)
                queryComponents[key] = results
            } else {
                results?.append(value)
            }
        }
        return queryComponents
    }
}

extension NSDictionary {
    @objc func stringFromQueryComponents() -> String? {
        var result: String? = nil
        for key in self.allKeys {
            guard var key = key as? String else {
                continue
            }
            key = key.encodingURLFormat()
            if let allValues = self[key] as? [AnyHashable] {
                for value in allValues {
                    guard var value = value as? String else {
                        continue
                    }
                    value = value.description.encodingURLFormat()
                    if result == nil {
                        result = "\(key)=\(value)"
                    } else {
                        result = (result ?? "") + "&\(key)=\(value)"
                    }
                }
            } else if let allValues = self[key] as? AnyHashable {
                let value = allValues.description.encodingURLFormat()
                if result == nil {
                    result = "\(key)=\(value )"
                } else {
                    result = (result ?? "") + "&\(key)=\(value )"
                }
            }
        }
        return result
    }
}
