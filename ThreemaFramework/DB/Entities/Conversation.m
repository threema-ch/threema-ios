//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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
#import "ContactEntity.h"
#import "BaseMessage.h"
#import "ImageData.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

static NSString *fieldCategory = @"category";
static NSString *fieldVisibility = @"visibility";

@implementation Conversation

@dynamic groupId;
@dynamic groupImageSetDate;
@dynamic groupMyIdentity;
@dynamic groupName;
@dynamic lastTypingStart;
@dynamic lastUpdate;
@dynamic typing;
@dynamic unreadMessageCount;
@dynamic marked;
@dynamic ballots;
@dynamic contact;
@dynamic groupImage;
@dynamic lastMessage;
@dynamic members;
@dynamic tags;
@dynamic distributionList;

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

- (NSString *)displayName {
    if (self.isGroup) {
        if (self.groupName.length > 0) {
            return self.groupName;
        } else {
            return @""; // The group has no name
        }
    } else if (self.distributionList != nil) {
        return  self.distributionList.name;
    } else {
        if (self.contact != nil) {
            return self.contact.displayName;
        }
        
        return @""; // display name is not available

    }
}

// This calls KVO observers of `displayName` if any of the provided key paths are called
// https://nshipster.com/key-value-observing/#automatic-property-notifications
+ (NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"groupName", @"members", @"contact.displayName", nil];
}

- (void)setGroupImage:(ImageData *)groupImage {
    [self willChangeValueForKey:@"groupImage"];
    [self setPrimitiveValue:groupImage forKey:@"groupImage"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationGroupConversationImageChanged object:self];
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

- (ConversationCategory)conversationCategory {
    if ([self valueForKey:fieldCategory] != nil) {
        switch ([[self valueForKey:fieldCategory] intValue]) {
            case ConversationCategoryPrivate:
                return ConversationCategoryPrivate;
            default:
                return ConversationCategoryDefault;
        }
    }
    return ConversationCategoryDefault;
}

- (void)setConversationCategory:(ConversationCategory)conversationCategory {
    [self willChangeValueForKey:fieldCategory];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)conversationCategory] forKey:fieldCategory];
    [self didChangeValueForKey:fieldCategory];
}

- (ConversationVisibility)conversationVisibility {
    if ([self valueForKey:fieldVisibility] != nil) {
        switch ([[self valueForKey:fieldVisibility] intValue]) {
            case ConversationVisibilityArchived:
                return ConversationVisibilityArchived;
            case ConversationVisibilityPinned:
                return ConversationVisibilityPinned;
            default:
                return ConversationVisibilityDefault;
        }
    }
    return ConversationVisibilityDefault;
}

- (void)setConversationVisibility:(ConversationVisibility)conversationVisibility {
    [self willChangeValueForKey:fieldVisibility];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)conversationVisibility] forKey:fieldVisibility];
    [self didChangeValueForKey:fieldVisibility];
}

- (NSSet<ContactEntity*>*) members {
    NSSet<ContactEntity*>* set = [self primitiveValueForKey:@"members"];
    if(set == nil) {
        return [[NSSet alloc]init];
    }
    return set;
}

@end
