//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

public final class CompanyDirectoryContact: NSObject, Sendable {
    public let id: String
    public let pk: Data
    @objc public let first: String?
    @objc public let last: String?
    public let csi: String?
    public let jobTitle: String?
    public let department: String?
    public let cat: [String]?
    public let org: String?
    
    public init(dictionary: [AnyHashable: Any?]) {
        self.id = dictionary["id"] as! String
        self.pk = NSData(
            base64Encoded: dictionary["pk"] as! String,
            options: NSData.Base64DecodingOptions.ignoreUnknownCharacters
        )! as Data
        
        if let tmp = dictionary["first"] as? String {
            self.first = tmp
        }
        else {
            self.first = ""
        }
        
        if let tmp = dictionary["last"] as? String {
            self.last = tmp
        }
        else {
            self.last = ""
        }
        
        if let tmp = dictionary["csi"] as? String {
            self.csi = tmp
        }
        else {
            self.csi = ""
        }
        
        self.jobTitle = dictionary["jobTitle"] as? String
        self.department = dictionary["department"] as? String
        
        if let tmp = dictionary["cat"] as? [String] {
            self.cat = tmp
        }
        else {
            self.cat = []
        }
        
        if let orgDict = dictionary["org"] as? [AnyHashable: String], let orgName = orgDict["name"] {
            self.org = orgName
        }
        else {
            self.org = ""
        }
    }
    
    public func fullName() -> String {
        var fullName = ""
        if UserSettings.shared().displayOrderFirstName == true {
            if first != nil {
                fullName.append(first!)
            }
            if last != nil {
                if !fullName.isEmpty {
                    fullName.append(" ")
                }
                fullName.append(last!)
            }
        }
        else {
            if last != nil {
                fullName.append(last!)
            }
            if first != nil {
                if !fullName.isEmpty {
                    fullName.append(" ")
                }
                fullName.append(first!)
            }
        }
        
        return fullName
    }
    
    public func fullNameWithCSI() -> String {
        // swiftformat:disable:next redundantSelf
        var fullName = self.fullName()
        
        if csi != nil {
            if !fullName.isEmpty {
                fullName.append(" ")
            }
            fullName.append("(" + csi! + ")")
        }
        
        return fullName
    }
    
    public func categoryString() -> String {
        if cat != nil {
            let categoryDict: [String: String] = MyIdentityStore.shared().directoryCategories as! [String: String]
            var categoryString = ""
            for category in cat! {
                if !categoryString.isEmpty {
                    categoryString.append(", ")
                }
                if let catName = categoryDict[category] {
                    categoryString.append(catName)
                }
            }
            return categoryString
        }
        return ""
    }
    
    public func categoryWithOrganisationString() -> String {
        let catString = categoryString()
        if let organisationName = org, organisationName != MyIdentityStore.shared().companyName {
            if !catString.isEmpty {
                return organisationName + ", " + catString
            }
            return organisationName
        }
        return categoryString()
    }
}
