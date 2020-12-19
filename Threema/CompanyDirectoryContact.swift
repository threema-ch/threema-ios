//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

public class CompanyDirectoryContact: NSObject
{
    var id: String
    var pk: Data
    @objc var first: String?
    @objc var last: String?
    var csi: String?
    var cat: [String]?
    
    public init(dictionary: [AnyHashable: Any?]) {
        id = dictionary["id"] as! String
        pk = NSData(base64Encoded: dictionary["pk"] as! String, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)! as Data
        if let tmp = dictionary["first"] as? String {
            first = tmp
        }
        if let tmp = dictionary["last"] as? String {
            last = tmp
        }
        
        if let tmp = dictionary["csi"] as? String {
            csi = tmp
        }
        
        if let tmp = dictionary["cat"] as? [String] {
            cat = tmp
        }
    }
    
    func fullName() -> String {
        var fullName = ""
        if UserSettings.shared().displayOrderFirstName == true {
            if first != nil {
                fullName.append(first!)
            }
            if last != nil {
                if fullName.count > 0 {
                    fullName.append(" ")
                }
                fullName.append(last!)
            }
        } else {
            if last != nil {
                fullName.append(last!)
            }
            if first != nil {
                if fullName.count > 0 {
                    fullName.append(" ")
                }
                fullName.append(first!)
            }
        }
        
        return fullName
    }
    
    func fullNameWithCSI() -> String {
        var fullName = self.fullName()
        
        if csi != nil {
            if fullName.count > 0 {
                fullName.append(" ")
            }
            fullName.append("("+csi!+")")
        }
        
        return fullName
    }
    
    func categoryString() -> String {
        if cat != nil {
            let categoryDict: [String:String] = MyIdentityStore.shared().directoryCategories as! [String:String]
            var categoryString = ""
            for category in cat! {
                if categoryString.count > 0 {
                    categoryString.append(", ")
                }
                let catName = categoryDict[category]
                categoryString.append(catName!)
            }
            return categoryString
        }
        return ""
    }
}
