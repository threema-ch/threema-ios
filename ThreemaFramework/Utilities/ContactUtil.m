//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "ContactUtil.h"
#import "UserSettings.h"
#import <ContactsUI/ContactsUI.h>
#import "MDMSetup.h"


#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation ContactUtil

// Is this ever used?
+ (ContactUtil *) contactUtil
{
    
    ContactUtil *addressUtil = [[ContactUtil alloc] init];
    
    return addressUtil;
}

+ (NSMutableString *)nameFromFirstname:(NSString *)firstName lastname:(NSString *)lastName {
    NSMutableString *name = [[NSMutableString alloc] init];
    
    if ([UserSettings sharedUserSettings].displayOrderFirstName) {
        if (firstName != nil && firstName.length > 0)
            [name appendString:firstName];
        if (lastName != nil && lastName.length > 0) {
            if (firstName != nil && firstName.length > 0) {
                [name appendString:@" "];
            }
            [name appendString:lastName];
        }
    } else {
        if (lastName != nil && lastName.length > 0)
            [name appendString:lastName];
        if (firstName != nil && firstName.length > 0) {
            if (lastName != nil && lastName.length > 0) {
                [name appendString:@" "];
            }
            [name appendString:firstName];
        }
    }
    
    return name;
}

+ (UIViewController *)getContactViewControllerForVCardData:(NSData *)data
{
    CNContact *contact = [self cnContactForVCardData:data];
    if (contact) {
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
        CNContactViewController *controller = [CNContactViewController viewControllerForUnknownContact:contact];
        controller.allowsActions = ![mdmSetup disableShareMedia];
        controller.allowsEditing = NO;
        controller.contactStore = [[CNContactStore alloc] init];
        controller.edgesForExtendedLayout = UIRectEdgeNone;
        return controller;
    } else {
        DDLogInfo(@"cannot display person details");
        return nil;
    }
}

+ (NSString *)getNameFromVCardData:(NSData *)data {
    CNContact *contact = [self cnContactForVCardData:data];
    if (contact) {
        NSString *firstName = contact.givenName;
        NSString *lastName = contact.familyName;
        
        return [ContactUtil nameFromFirstname:firstName lastname:lastName];
    }
    
    return nil;
}

+ (CNContact *)cnContactForVCardData:(NSData *)data {
    NSError *error;
    CNContact *contact = [CNContactVCardSerialization contactsWithData:data error:&error].firstObject;
    if (!error)
        return contact;
    
    return nil;
}

+ (NSData *)vCardDataForCnContact:(CNContact *)contact {
    NSError *error;
    NSData *data = [CNContactVCardSerialization dataWithContacts:@[contact] error:&error];
    if (!error)
        return data;
    
    return nil;
}

@end
