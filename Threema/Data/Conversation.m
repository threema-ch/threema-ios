//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "Conversation.h"
#import "Contact.h"
#import "BaseMessage.h"
#import "ImageData.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "EntityFetcher.h"

@implementation Conversation

@dynamic groupId;
@dynamic groupImageSetDate;
@dynamic groupMyIdentity;
@dynamic groupName;
@dynamic lastTypingStart;
@dynamic typing;
@dynamic unreadMessageCount;
@dynamic marked;
@dynamic ballots;
@dynamic contact;
@dynamic groupImage;
@dynamic lastMessage;
@dynamic members;
@dynamic messages;
@dynamic tags;

- (void)setTyping:(NSNumber *)typing {
    [self willChangeValueForKey:@"typing"];
    [self setPrimitiveValue:typing forKey:@"typing"];
    
    if (typing.boolValue) {
        [self willChangeValueForKey:@"lastTypingStart"];
        [self setPrimitiveValue:[NSDate date] forKey:@"lastTypingStart"];
        [self didChangeValueForKey:@"lastTypingStart"];
    }
    
    [self didChangeValueForKey:@"typing"];
}

- (NSString*)displayName {
    if (self.groupId != nil) {
        if (self.groupName.length > 0) {
            return self.groupName;
        } else {
            return [self sortedMemberNames];
        }
    } else {
        return self.contact.displayName;
    }
}

- (NSString *)sortedMemberNames {
    NSMutableString *namesString = [NSMutableString string];
    
    if (self.contact == nil) {
        [namesString appendString:[BundleUtil localizedStringForKey:@"me"]];
    } else {
        [namesString appendString:[self memberNameForContact:self.contact]];
    }
    
    [namesString appendString:@": "];

    NSMutableArray *memberNames = [NSMutableArray array];
    for (Contact *member in self.sortedMembers) {
        if (member.state.intValue == kStateInvalid) {
            continue;
        }
        
        [memberNames addObject:[self memberNameForContact:member]];
    }
    
    // add self to end of list if not creator
    if (self.contact) {
        [memberNames addObject:[BundleUtil localizedStringForKey:@"me"]];
    }

    if (memberNames.count == 0) {
        [namesString appendString:[BundleUtil localizedStringForKey:@"nobody"]];
    } else {
        BOOL addComma = NO;
        for (NSString *name in memberNames) {
            if (addComma) {
                [namesString appendString:@", "];
            }
            
            [namesString appendString:name];
            addComma = YES;
        }
    }

    return namesString;
}

- (NSString *)memberNameForContact:(Contact *)member {
    if (member.firstName.length > 0) {
        return member.firstName;
    }
    
    return member.displayName;
}

+ (NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"groupName", @"members", @"contact.displayName", nil];
}

- (NSArray *)sortedMembers {
    /* Extract members without first or last name, and put them at the end of the list
       (otherwise they would appear on top) */
    NSMutableArray *namedMembers = [NSMutableArray array];
    NSMutableArray *unnamedMembers = [NSMutableArray array];
    for (Contact *contact in self.members) {
        if (contact.firstName.length == 0 && contact.lastName.length == 0)
            [unnamedMembers addObject:contact];
        else
            [namedMembers addObject:contact];
    }
    
    NSArray *sortedNamedMembers;
    if ([UserSettings sharedUserSettings].sortOrderFirstName) {
        sortedNamedMembers = [namedMembers sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES],
                                                           [NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES],
                                                           [NSSortDescriptor sortDescriptorWithKey:@"identity" ascending:YES]]];
    } else {
        sortedNamedMembers = [namedMembers sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES],
                                                           [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES],
                                                           [NSSortDescriptor sortDescriptorWithKey:@"identity" ascending:YES]]];
    }
    
    NSArray *sortedUnnamedMembers = [unnamedMembers sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identity" ascending:YES]]];
    
    return [sortedNamedMembers arrayByAddingObjectsFromArray:sortedUnnamedMembers];
}

+ (NSSet *)keyPathsForValuesAffectingSortedMembers {
    return [NSSet setWithObjects:@"members", nil];
}

- (void)setGroupImage:(ImageData *)groupImage {
    [self willChangeValueForKey:@"groupImage"];
    [self setPrimitiveValue:groupImage forKey:@"groupImage"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaGroupConversationImageChanged" object:self];
    [self didChangeValueForKey:@"groupImage"];
}

- (BOOL)wasDeleted {
    return self.managedObjectContext == nil;
}

- (BOOL)isGroup {
    return self.groupId != nil;
}

- (NSSet *)participants {
    if ([self isGroup]) {
        return [NSSet setWithSet:self.members];
    } else {
        return [NSSet setWithObject:self.contact];
    }
}

@end
