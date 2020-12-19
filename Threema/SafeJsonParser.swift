//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class SafeJsonParser {
    struct SafeBackupData : Codable {
        let info: Info
        struct Info : Codable {
            let version: Int
            let device: String?
        }
        var user: User?
        var contacts: [Contact]?
        var groups: [Group]?
        var settings: Settings?
        
        class User : Codable {
            var privatekey: String
            var nickname: String?
            var profilePic: String?
            var profilePicRelease: [String?]?
            var links: [Link]?
            
            init(privatekey: String) {
                self.privatekey = privatekey
            }
            
            struct Link : Codable {
                let type: String?
                let name: String? = ""
                let value: String?
            }
        }
        
        class Contact : Codable {
            var identity: String?
            var publickey: String?
            var createdAt: UInt64? = 0
            var verification: Int? = 0
            var workVerified: Bool? = false
            var hidden: Bool? = false
            var firstname: String? = ""
            var lastname: String? = ""
            var nickname: String? = ""
            
            init(identity: String, verification: Int) {
                self.identity = identity
                self.verification = verification
            }
        }
        
        struct Group : Codable {
            let id: String?
            let creator: String?
            let groupname: String?
            let createdAt: UInt64? = 0
            let members: [String]?
            let deleted: Bool?
        }
        
        class Settings : Codable {
            var syncContacts: Bool = false
            var blockUnknown: Bool? = false
            var readReceipts: Bool? = true
            var sendTyping: Bool? = true
            var threemaCalls: Bool? = true
            var relayThreemaCalls: Bool? = false
            var blockedContacts: [String]?
            var syncExcludedIds: [String]?
        }
    }
    
    struct SafeServerConfig : Codable {
        let maxBackupBytes: Int
        let retentionDays: Int
    }

    func getSafeBackupData() -> SafeBackupData {
        return SafeBackupData(info: SafeBackupData.Info(version: 1, device: "ios"), user: nil, contacts: nil, groups: nil, settings: nil)
    }

    func getSafeBackupData(from: Data) throws -> SafeBackupData {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .deferredToData
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(SafeBackupData.self, from: from)
    }
    
    func getJsonAsBytes(from: SafeBackupData) -> [UInt8]? {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(from) {
            return data.withUnsafeBytes {
                return Array($0)
            }
        }
        return nil
    }
    
    func getJsonAsString(from: SafeBackupData) -> String? {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(from) {
            return String(data: data, encoding: .utf8)!
        }
        return nil
    }
    
    func getSafeServerConfig(from: Data) -> SafeServerConfig? {
        let decoder = JSONDecoder()
        return try? decoder.decode(SafeServerConfig.self, from: from)
    }
}
