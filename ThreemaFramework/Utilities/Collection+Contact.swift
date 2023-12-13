//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

extension Collection<Contact> {
    
    /// Sort a collection of `Contact`s
    ///
    /// All contacts that have a first name, last name or nickname come before all IDs. The first and second part are
    /// both sorted locale aware based on the passed `userSettings`. For sorting details see the implementation.
    ///
    /// - Parameter userSettings: Optional user settings injection
    /// - Returns: An array of sorted `Contact`s
    func sorted(
        with userSettings: UserSettingsProtocol = UserSettings.shared()
    ) -> [Element] {
        var namedContacts = [Contact]()
        var idOnlyContacts = [Contact]()
        
        // Sort contacts in bins
        forEach { contact in
            if contact.hasFirstName || contact.hasLastName || contact.hasPublicNickname {
                namedContacts.append(contact)
            }
            else {
                idOnlyContacts.append(contact)
            }
        }
        
        // Sort named contacts
        var sortedNamedContacts = namedContacts.map { contact in
            // Pre-calculation of all sort properties
            (sortProperties: contact.sortProperties(for: userSettings), contact: contact)
        }
        .sorted(by: customNamedContactComparison) // Sort
        .map(\.contact) // Remove sort properties
        
        // Sort id only contacts just by id
        let sortedIDOnlyContacts = idOnlyContacts.sorted {
            $0.identity.string.localizedStandardCompare($1.identity.string) == .orderedAscending
        }
        
        // Merge sorted contacts
        sortedNamedContacts.append(contentsOf: sortedIDOnlyContacts)
        
        return sortedNamedContacts
    }
    
    // This sorting takes into account the non-existence of some name properties. (But expects an
    // existence of at least one.)
    //
    // The following table shows an example when some properties are missing. For all the details
    // see the implementation below or the `CollectionContactTests.testSortedContacts()` which
    // should test all possible edge cases:
    //
    // | Order First | Order Last | First | Last  | Nick  |
    // |-------------|------------|-------|-------|-------|
    // | 3           | 4          | Yeung |       |       |
    // | 4           | 3          |       | Yeung |       |
    // | 5           | 5          |       |       | Yeung |
    // | 2           | 2          | Ye    | ung   |       |
    // | 1           | 1          | Ye    | un    |       |
    //
    // The comparison is locale aware.
    private func customNamedContactComparison(
        lhs: (sortProperties: Contact.SortProperties, contact: Contact),
        rhs: (sortProperties: Contact.SortProperties, contact: Contact)
    ) -> Bool {
        let (leftSortNameFirst, leftSortNameSecond, leftHasFirstName, leftHasSecondName) = lhs.sortProperties
        let (rightSortNameFirst, rightSortNameSecond, rightHasFirstName, rightHasSecondName) = rhs.sortProperties
        
        // MARK: Default cases that should normally do the sorting
        
        // Easy case if they have not identical first sort names we just order them
        let firstComparisonResult = leftSortNameFirst.localizedStandardCompare(rightSortNameFirst)
        guard firstComparisonResult == .orderedSame else {
            return firstComparisonResult == .orderedAscending
        }
                
        // If the second sort names are not identical we can sort by them
        let secondComparisonResult = leftSortNameSecond.localizedStandardCompare(rightSortNameSecond)
        guard secondComparisonResult == .orderedSame else {
            return secondComparisonResult == .orderedAscending
        }
        
        // MARK: Edge cases
        
        // Starting here `*sortNameFirst` & `*sortNameSecond` are identical...
        
        // Order identical entries by ID. This is a simple helper as this is needed multiple times
        let compareIDs = {
            lhs.contact.identity.string.localizedStandardCompare(rhs.contact.identity.string) == .orderedAscending
        }
        
        // First name checks
        
        // If we have a left first name we use this for sorting
        if leftHasFirstName {
            if rightHasFirstName {
                // We know that they have to be identical if they both have the a first name (from
                // the sortNameFirst comparison) and there doesn't exist a second name for either
                // (from the sortNameSecond comparison)
                return compareIDs()
            }
            else {
                // Left has a first name, right doesn't. So the order is correct.
                return true
            }
        }
        
        // The order is wrong if right has a first name, but the left doesn't.
        if rightHasFirstName {
            return false
        }
        
        // Second name checks: We don't have a first name in either one
        
        // Left contact has a second name
        if leftHasSecondName {
            if rightHasSecondName {
                // We know that they have to be identical if they both have the a second name (from
                // the sortNameSecond comparison) and there doesn't exist a first name for either
                // (from the hastFirstName checks)
                return compareIDs()
            }
            else {
                // Left has a second name, right doesn't. So the order is correct
                return true
            }
        }
        
        // The order is wrong if right has a second name, but the left doesn't.
        if rightHasSecondName {
            return false
        }
        
        // We have identical nick names thus we just compare the ids
        return compareIDs()
    }
}

// MARK: Helper for sorting

extension Contact {
    fileprivate typealias SortProperties = (
        sortNameFirst: String,
        sortNameSecond: String,
        hasFirstName: Bool,
        hasSecondName: Bool
    )
    
    /// Is there a non-empty first name
    fileprivate var hasFirstName: Bool {
        guard let firstName else {
            return false
        }
        
        return !firstName.isEmpty
    }
    
    /// Is there a non-empty last name
    fileprivate var hasLastName: Bool {
        guard let lastName else {
            return false
        }
        
        return !lastName.isEmpty
    }
    
    /// Is there a non-empty nickname
    fileprivate var hasPublicNickname: Bool {
        guard let publicNickname else {
            return false
        }
        
        return !publicNickname.isEmpty
    }
    
    /// All properties need to sort named `Contact`s
    ///
    /// - Parameter userSettings: User settings used to define the sorting order
    /// - Returns: Two sorting names and two bools if first and second name exist
    fileprivate func sortProperties(for userSettings: UserSettingsProtocol) -> SortProperties {
        var first = firstName
        var second = lastName
        var hasFirstNameLocal = hasFirstName
        var hasSecondNameLocal = hasLastName
        
        if !userSettings.sortOrderFirstName {
            first = lastName
            second = firstName
            hasFirstNameLocal = hasLastName
            hasSecondNameLocal = hasFirstName
        }
                
        if let firstName = first, !firstName.isEmpty {
            return (firstName, second ?? "", hasFirstNameLocal, hasSecondNameLocal)
        }
        
        if let secondName = second, !secondName.isEmpty {
            return (secondName, "", hasFirstNameLocal, hasSecondNameLocal)
        }
        
        assert(
            publicNickname != nil,
            "It is assumed that this is only called on contacts that have a first name, last name or nickname"
        )
                
        return (publicNickname ?? "", "", hasFirstNameLocal, hasSecondNameLocal)
    }
}
