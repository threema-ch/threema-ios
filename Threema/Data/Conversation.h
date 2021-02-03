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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Ballot, BaseMessage, Contact, ImageData, Tag;

@interface Conversation : NSManagedObject

@property (nonatomic, retain) NSData * groupId;
@property (nonatomic, retain) NSDate * groupImageSetDate; // used to keep proper order when processing multiple set photo images
@property (nonatomic, retain) NSString * groupMyIdentity; //this users id when group was created (the user might have created a new one in the mean time)
@property (nonatomic, retain) NSString * groupName;
@property (nonatomic, retain) NSDate * lastTypingStart;
@property (nonatomic, retain) NSNumber * typing;
@property (nonatomic, retain) NSNumber * unreadMessageCount;
@property (nonatomic, retain) NSNumber *marked;
@property (nonatomic, retain) NSOrderedSet *ballots;
@property (nonatomic, retain) Contact *contact;
@property (nonatomic, retain) ImageData *groupImage;
@property (nonatomic, retain) BaseMessage *lastMessage;
@property (nonatomic, retain) NSSet *members;
@property (nonatomic, retain) NSSet *messages;
@property (nonatomic, retain) NSSet *tags;

@property (readonly) NSString* displayName;
@property (readonly) NSArray* sortedMembers;

@end

@interface Conversation (CoreDataGeneratedAccessors)

- (void)insertObject:(Ballot *)value inBallotsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromBallotsAtIndex:(NSUInteger)idx;
- (void)insertBallots:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeBallotsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInBallotsAtIndex:(NSUInteger)idx withObject:(Ballot *)value;
- (void)replaceBallotsAtIndexes:(NSIndexSet *)indexes withBallots:(NSArray *)values;
- (void)addBallotsObject:(Ballot *)value;
- (void)removeBallotsObject:(Ballot *)value;
- (void)addBallots:(NSOrderedSet *)values;
- (void)removeBallots:(NSOrderedSet *)values;
- (void)addMembersObject:(Contact *)value;
- (void)removeMembersObject:(Contact *)value;
- (void)addMembers:(NSSet *)values;
- (void)removeMembers:(NSSet *)values;

- (void)addMessagesObject:(BaseMessage *)value;
- (void)removeMessagesObject:(BaseMessage *)value;
- (void)addMessages:(NSSet *)values;
- (void)removeMessages:(NSSet *)values;

- (void)addTagsObject:(Tag *)value;
- (void)removeTagsObject:(Tag *)value;
- (void)addTags:(NSSet *)values;
- (void)removeTags:(NSSet *)values;

#pragma mark - own methods

- (BOOL)wasDeleted;

- (BOOL)isGroup;

- (NSString *)sortedMemberNames;

- (NSSet *)participants;

@end
