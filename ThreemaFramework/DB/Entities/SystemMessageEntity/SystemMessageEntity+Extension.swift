//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

extension SystemMessageEntity {
    @objc override public func additionalExportInfo() -> String? {
        switch systemMessageType {
        case let .systemMessage(type: type):
            type.localizedMessage
        case let .callMessage(type: type):
            type.localizedMessage
        case let .workConsumerInfo(type: type):
            type.localizedMessage
        }
    }
    
    @objc public func argumentAsUTF8String() -> String {
        guard let arg, let decodedArgs = String(data: arg, encoding: .utf8) else {
            return ""
        }
        return decodedArgs
    }
    
    public func callDuration() -> String? {
        guard let dict = argumentDictionary(), let duration = dict["CallTime"] as? String, !duration.isEmpty else {
            return nil
        }
        
        return duration
    }
    
    @objc private func argumentDictionary() -> [String: Any]? {
        guard let arg, !arg.isEmpty else {
            return nil
        }
        
        do {
            guard let jsonObject = try JSONSerialization
                .jsonObject(with: arg, options: .fragmentsAllowed) as? [String: Any] else {
                return nil
            }
            return jsonObject
        }
        catch {
            return nil
        }
    }
}
