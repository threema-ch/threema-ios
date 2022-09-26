//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import ContactsUI
import Foundation

/// Complicated constants that cannot easily be imported form Objective-C redefined for Swift
///
/// For example non-trivial macros cannot be imported: <https://developer.apple.com/videos/play/wwdc2020/10680/?time=1801>
///
/// When you add a new constant use the same name but remove the `k`. Add a comment with the name of the corresponding
/// Objective-C constant.
public enum Constants {
    
    /// Contact keys to fetch from `CNContactStore`
    ///
    /// - SeeAlso: kCNContactKeys
    public static let cnContactKeys = [
        CNContactFamilyNameKey,
        CNContactGivenNameKey,
        CNContactMiddleNameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactImageDataKey,
        CNContactImageDataAvailableKey,
        CNContactThumbnailImageDataKey,
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactViewController.descriptorForRequiredKeys(),
    ] as! [CNKeyDescriptor]
    
    /// Beta feedback identity
    public static let betaFeedbackIdentity = kBetaFeedbackIdentity
    
    /// Showed TestFlight feedback info screen key
    public static let showedTestFlightFeedbackViewKey = kShowedTestFlightFeedbackView
}
