import Foundation

extension ContactEntity {
    @objc public var isEchoEcho: Bool {
        identity == "ECHOECHO"
    }
    
    @objc public var isGatewayID: Bool {
        identity.hasPrefix("*")
    }
    
    @objc public func updateSortInitial(sortOrderFirstName: Bool) {
        if isGatewayID {
            sortInitial = "*"
            sortIndex = NSNumber(value: ThreemaLocalizedIndexedCollation.sectionTitles.count - 1)
        }
        else {
            // find the first keyPath where the length is greater than 0, fallback to identity
            var string = identity
            
            if !(firstName?.isEmpty ?? true) || !(lastName?.isEmpty ?? true) {
                if sortOrderFirstName {
                    if let firstName, !firstName.isEmpty {
                        string = firstName
                    }
                    else if let lastName, !lastName.isEmpty {
                        string = lastName
                    }
                }
                else {
                    if let lastName, !lastName.isEmpty {
                        string = lastName
                    }
                    else if let firstName, !firstName.isEmpty {
                        string = firstName
                    }
                }
            }
            else if let publicNickname, !publicNickname.isEmpty {
                string = publicNickname
            }

            let idx = ThreemaLocalizedIndexedCollation.section(for: string)
            let sortInitial = ThreemaLocalizedIndexedCollation.sectionTitles[idx]
            let sortIndex = NSNumber(value: idx)

            if self.sortInitial != sortInitial {
                self.sortInitial = sortInitial
            }
            if self.sortIndex != sortIndex {
                self.sortIndex = sortIndex
            }
        }
    }
}
