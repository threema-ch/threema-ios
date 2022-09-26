//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "TMAManagedObject.h"

typedef NS_ENUM(NSInteger, ConversationCategory) {
    ConversationCategoryDefault = 0,
    ConversationCategoryPrivate = 1,
};

typedef NS_ENUM(NSInteger, ConversationVisibility) {
    ConversationVisibilityDefault = 0,
    ConversationVisibilityArchived = 1,
};

@class Ballot, BaseMessage, Contact, ImageData, Tag;

NS_ASSUME_NONNULL_BEGIN
@interface Conversation : TMAManagedObject

// Attributes
@property (nonatomic) ConversationCategory conversationCategory;
@property (nonatomic, retain, nullable) NSData * groupId NS_SWIFT_NAME(groupID);
/// used to keep proper order when processing multiple set photo images
@property (nonatomic, retain, nullable) NSDate * groupImageSetDate;
/// this users id when group was created (the user might have created a new one in the mean time)
@property (nonatomic, retain, nullable) NSString * groupMyIdentity;
@property (nonatomic, retain, nullable) NSString * groupName;
@property (nonatomic, retain, nullable) NSDate * lastTypingStart;
@property (nonatomic, retain) NSNumber * typing;
@property (nonatomic, retain) NSNumber * unreadMessageCount;
@property (nonatomic, retain) NSNumber *marked;
@property (nonatomic) ConversationVisibility conversationVisibility;
@property (nonatomic, retain, nullable) NSDate * lastUpdate;

// Relationships
@property (nonatomic, retain, nullable) NSOrderedSet *ballots;
@property (nonatomic, retain, nullable) Contact *contact;
@property (nonatomic, retain, nullable) ImageData *groupImage;
@property (nonatomic, retain, nullable) BaseMessage *lastMessage;
@property (nonatomic, retain) NSSet<Contact *> *members;
@property (nonatomic, retain, nullable) NSSet *tags;

// Computed Properties
@property (readonly, nullable) NSString* displayName;

#pragma mark - Own Methods
- (BOOL)wasDeleted;
- (BOOL)isGroup;
- (NSSet*)participants;

NS_ASSUME_NONNULL_END

@end

@interface Conversation (CoreDataGeneratedAccessors)

- (void)insertObject:(nullable Ballot *)value inBallotsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromBallotsAtIndex:(NSUInteger)idx;
- (void)insertBallots:(nullable NSArray *)value atIndexes:(nullable NSIndexSet *)indexes;
- (void)removeBallotsAtIndexes:(nullable NSIndexSet *)indexes;
- (void)replaceObjectInBallotsAtIndex:(NSUInteger)idx withObject:(nullable Ballot *)value;
- (void)replaceBallotsAtIndexes:(nullable NSIndexSet *)indexes withBallots:(nullable NSArray *)values;
- (void)addBallotsObject:(nullable Ballot *)value;
- (void)removeBallotsObject:(nullable Ballot *)value;
- (void)addBallots:(nullable NSOrderedSet *)values;
- (void)removeBallots:(nullable NSOrderedSet *)values;

- (void)addMembersObject:(nullable Contact *)value;
- (void)removeMembersObject:(nullable Contact *)value;
- (void)addMembers:(nullable NSSet *)values;
- (void)removeMembers:(nullable NSSet *)values;

- (void)addTagsObject:(nullable Tag *)value;
- (void)removeTagsObject:(nullable Tag *)value;
- (void)addTags:(nullable NSSet *)values;
- (void)removeTags:(nullable NSSet *)values;

@end
