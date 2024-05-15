//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import CoreData
import Foundation

@objc(DistributionListEntity)
public class DistributionListEntity: NSManagedObject, Identifiable {
    
    // Properties
    // swiftformat:disable:next acronyms
    @NSManaged @objc(distributionListId) public var distributionListId: NSNumber
    @NSManaged @objc(name) public var name: NSString
    
    // Relationships
    @NSManaged public var conversation: Conversation?
    
    private static let oneRecipientTitleString = "distribution_list_one_recipient_title".localized
    private static let multipleRecipientsTitleString = "distribution_list_multiple_recipients_title".localized
}

extension DistributionListEntity {
    /// Number of recipients including me
    public var numberOfRecipients: Int {
        conversation?.members.count ?? 0
    }
    
    public var recipientCountString: String {
        if numberOfRecipients == 1 {
            return DistributionListEntity.oneRecipientTitleString
        }
        else {
            return String.localizedStringWithFormat(
                DistributionListEntity.multipleRecipientsTitleString,
                numberOfRecipients
            )
        }
    }
    
    public var recipientList: String {
        guard let members = conversation?.members, !members.isEmpty else {
            return "distribution_list_no_recipient_title".localized
        }
        return members.map(\.shortDisplayName)
            .joined(separator: ", ")
    }
}
