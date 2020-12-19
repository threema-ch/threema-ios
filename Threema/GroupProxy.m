//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "GroupProxy.h"
#import "MessageSender.h"
#import "EntityManager.h"
#import "Group.h"
#import "ContactStore.h"
#import "MyIdentityStore.h"
#import "GroupPhotoSender.h"
#import "BundleUtil.h"
#import "UserSettings.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface GroupProxy ()

@property (nonatomic) Conversation *conversation;
@property (nonatomic) Group *group;
@property LastGroupSyncRequest *lastSyncRequest;

@end

@implementation GroupProxy

+ (instancetype)groupProxyForMessage:(AbstractGroupMessage *)message {
    EntityManager *entityManager = [[EntityManager alloc] init];
    Conversation *conversation = [entityManager.entityFetcher conversationForGroupMessage:message];
    if (conversation) {
        // valid existing group
        return [GroupProxy groupProxyForConversation:conversation entityManager:entityManager];
    }
    
    Group *group = [entityManager.entityFetcher groupForGroupId:message.groupId groupCreator:message.groupCreator];
    if (group ) {
        return [GroupProxy groupProxyForGroup:group];
    }

    /* Check if we have already requested a sync for this group in the last 7 days */
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-kGroupSyncRequestInterval];
    LastGroupSyncRequest *lastSyncRequest = [entityManager.entityFetcher lastGroupSyncRequestFor:message.groupId groupCreator:message.groupCreator sinceDate:date];
    if (lastSyncRequest) {
        // group info not available yet
        return [GroupProxy groupForLastGroupSyncRequest:lastSyncRequest];
    }

    return nil;
}

+ (instancetype)groupProxyForGroup:(Group *)group {
    if (group == nil) {
        return nil;
    }
    
    return [[GroupProxy alloc] initWithGroup: group];
}

+ (instancetype)groupForLastGroupSyncRequest:(LastGroupSyncRequest *)lastSyncRequest {
    if (lastSyncRequest == nil) {
        return nil;
    }
    
    return [[GroupProxy alloc] initWithLastGroupSyncRequest: lastSyncRequest];
}

+ (instancetype)groupProxyForConversation:(Conversation *)conversation {
    return [GroupProxy groupProxyForConversation:conversation entityManager:[[EntityManager alloc] init]];
}

+ (instancetype)groupProxyForConversation:(Conversation *)conversation entityManager:(EntityManager*)entityManager {
    if (conversation == nil || conversation.isGroup == NO) {
        DDLogError(@"Conversation is not a group");
        return nil;
    }
    
    return [[GroupProxy alloc] initWithConversation: conversation entityManager:entityManager];
}

+ (instancetype)newGroupWithId:(NSData *)groupId creator:(Contact *)creator {
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    Contact *creatorInOwnContext = (Contact *)[entityManager.entityFetcher getManagedObjectById:creator.objectID];

    Conversation *conversation = [entityManager.entityCreator conversation];
    conversation.contact = creatorInOwnContext;
    conversation.groupId = groupId;
    conversation.groupMyIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
    
    return [[GroupProxy alloc] initWithConversation: conversation entityManager:entityManager];
}

- (instancetype)initWithConversation:(Conversation *)conversation entityManager:(EntityManager*)entityManager {
    self = [super init];
    if (self) {
        _conversation = conversation;
        _group = [entityManager.entityFetcher groupForConversation:_conversation];
    }
    
    return self;
}

- (instancetype)initWithGroup:(Group *)group {
    self = [super init];
    if (self) {
        _group = group;
    }
    return self;
}

- (instancetype)initWithLastGroupSyncRequest:(LastGroupSyncRequest *)lastSyncRequest {
    self = [super init];
    if (self) {
        _lastSyncRequest = lastSyncRequest;
        EntityManager *entityManager = [[EntityManager alloc] init];
        _group = [entityManager.entityFetcher groupForGroupId:lastSyncRequest.groupId groupCreator:lastSyncRequest.groupCreator];
    }
    return self;
}

- (NSData *)groupId {
    return _conversation.groupId;
}

- (NSString *)name {
    return [_conversation displayName];
}

- (NSSet *)members {
    return _conversation.members;
}

- (NSSet *)memberIdsIncludingSelf {
    NSMutableSet *currentGroupMemberIds = [NSMutableSet set];
    for (Contact *contact in self.members) {
        [currentGroupMemberIds addObject:contact.identity];
    }
    
    if (self.group.state != nil) {
        if (self.group.state.intValue == kGroupStateActive) {
            [currentGroupMemberIds addObject: [MyIdentityStore sharedMyIdentityStore].identity];
        }
    }
    return currentGroupMemberIds;
}

- (NSSet *)activeMembers {
    if (self.members == nil) {
        return [NSMutableSet set];
    }
    if (self.members.count == 0) {
        return [NSMutableSet set];
    }
    
    NSMutableSet *activeMembers = [NSMutableSet setWithCapacity:self.members.count];
    
    for (Contact *member in self.members) {
        if (member.state.intValue != kStateInvalid) {
            [activeMembers addObject:member];
        }
    }
    
    return activeMembers;
}

- (NSArray *)sortedActiveMembers {
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


- (NSSet *)activeMemberIds {
    NSMutableSet *activeMemberIds = [NSMutableSet setWithCapacity:self.activeMembers.count];
    for (Contact *member in self.activeMembers) {
        [activeMemberIds addObject:member.identity];
    }
    
    return activeMemberIds;
}

- (void)setName:(NSString *)name remoteSentDate:(NSDate*)remoteSentDate {
    if ([_conversation.groupName isEqualToString:name]) {
        /* no change */
        return;
    }
    
    _conversation.groupName = name;
    
    NSData *arg = [name dataUsingEncoding:NSUTF8StringEncoding];
    [self postSystemMessageType:kSystemMessageRenameGroup withArg:arg remoteSentDate:remoteSentDate];
}

- (BOOL)didLeaveGroup {
    if (_group && _group.didLeave) {
        return YES;
    }
    
    return NO;
}

- (BOOL)didRequestSync {
    if (_lastSyncRequest) {
        return YES;
    }
    
    return NO;
}

- (BOOL)canSendInGroup {
    return _group.didLeave == NO && _group.didForcedLeave == NO;
}

- (Contact *)contactForMemberIdentity:(NSString *)identity {
    if ([self.creator.identity isEqualToString:identity]) {
        return self.creator;
    }
    
    for (Contact *member in self.members) {
        if ([member.identity isEqualToString:identity]) {
            return member;
        }
    }
    
    return nil;
}

- (BOOL)isOwnGroup {
    if (_conversation.groupMyIdentity != nil && ![_conversation.groupMyIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        return NO;
    }
    
    if (self.group.state.intValue != kGroupStateActive) {
        return NO;
    }
    
    return _conversation.contact == nil;
}

- (BOOL)isSelfMember {
    if ([self isOwnGroup] && self.group.state.intValue == kGroupStateActive) {
        return YES;
    }
    
    if ([_conversation.groupMyIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        if (self.group != nil) {
            if (self.group.state != nil) {
                if (self.group.state.intValue == kGroupStateActive) {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (Conversation *)conversation {
    return _conversation;
}

- (Contact *)creator {
    return _conversation.contact;
}

- (NSString *)creatorString {
    NSString *creator;
    if ([self isOwnGroup]) {
        creator = [BundleUtil localizedStringForKey:@"me"];
    } else if (self.creator) {
        creator = self.creator.displayName;
    } else {
        creator = [BundleUtil localizedStringForKey:@"(unknown)"];
    }

    return [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"creator"], creator];
}

- (NSString *)membersSummaryString {
    NSInteger count = [self memberIdsIncludingSelf].count;
    NSString *summary = [BundleUtil localizedStringForKey:@"%d members"];
    return [NSString stringWithFormat:summary, count];
}

- (BOOL)isGroupMember:(NSString *)contactIdentity {
    NSSet *allMembers = [self memberIdsIncludingSelf];
    return [allMembers containsObject:contactIdentity];
}

//Has to be called with entity manager which loaded _conversation -> refactoring: use one entity manager in whole class
- (void)adminAddMembersFromBackup:(NSSet *)identities entityManager:(EntityManager*)entityManager {
    //adding all members to group, restore from safe backup
    if ([identities count] > 0) {
        NSMutableArray *identitiesUppercase = [[NSMutableArray alloc] initWithCapacity:[identities count]];
        for (NSString *identity in identities) {
            NSString *identityUppercase = identity.uppercaseString;
            [identitiesUppercase addObject:identityUppercase];
            
            // do not add it's me
            Contact *member = [entityManager.entityFetcher contactForId:identityUppercase];
            if (member != nil && member.identity != [[MyIdentityStore sharedMyIdentityStore] identity]) {
                [_conversation addMembersObject:member];
            }
        }
        
        if ([identitiesUppercase containsObject:[[MyIdentityStore sharedMyIdentityStore] identity]]) {
            [self setGroupState:kGroupStateActive];
        } else {
            [self setGroupState:kGroupStateForcedLeft];
        }
    } else {
        [self setGroupState:kGroupStateLeft];
    }
}

- (void)adminAddMember:(Contact *)contact {
    // do not add it's me
    if ([contact.identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        return;
    }

    [_conversation addMembersObject:contact];

    [self postSystemMessageForMember:contact type:kSystemMessageGroupMemberAdd remoteSentDate:nil];
    
    [self syncGroupInfoToContact:contact];
    [self sendGroupCreateToAllMembers];
}

- (void)adminRemoveMember:(Contact *)contact {
    if ([contact.identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        // it's me in member remove me, otherwise delete group
        if ([[_conversation members] containsObject:contact]) {
            [_conversation removeMembersObject:contact];
        } else {
            [self adminDeleteGroup];
        }
        return;
    }
    
    [_conversation removeMembersObject:contact];
    
    [self postSystemMessageForMember:contact type:kSystemMessageGroupMemberForcedLeave remoteSentDate:nil];

    // send to removed member
    [MessageSender sendGroupCreateMessageForGroup:self toMember:contact];
    
    [self sendGroupCreateToAllMembers];
}

- (void)groupLeavePostprocess:(Contact *)member {
    // delete member vote in all open ballots
    for (Ballot *ballot in _conversation.ballots) {
        if ([ballot isClosed] == NO) {
            for (BallotChoice *choice in ballot.choices) {
                [choice removeResultForContact: member.identity];
            }
        }
    }
}

- (void)resendLeaveMessageTo:(NSString *)identity {
    if (_group) {
        NSData *groupId = _group.groupId;
        NSString *groupCreator = _group.groupCreator;
        
        DDLogWarn(@"Group ID %@ (creator %@) has been deleted before. Sending leave message.", groupId, groupCreator);
        [MessageSender sendGroupLeaveMessageForCreator:groupCreator groupId:groupId toIdentity:identity];
        if (![identity isEqualToString:groupCreator]) {
            // also resend message to group creator to make sure
            [MessageSender sendGroupLeaveMessageForCreator:groupCreator groupId:groupId toIdentity:groupCreator];
        }
    }
}

- (void)leaveGroup {
    [MessageSender sendGroupLeaveMessageForConversation:_conversation];
    [self setGroupState:kGroupStateLeft];
    [self postSystemMessageType:kSystemMessageGroupSelfLeft withArg:nil remoteSentDate:[NSDate date]];
    [self updateGroupMyIdentity:[MyIdentityStore sharedMyIdentityStore].identity forConversation:_conversation];
}

+ (void)sendSyncRequestWithGroupId:(NSData *)groupId creator:(NSString *)groupCreator {
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-kGroupSyncRequestInterval];
    LastGroupSyncRequest *lastSyncRequest = [entityManager.entityFetcher lastGroupSyncRequestFor:groupId groupCreator:groupCreator sinceDate:date];
    if (lastSyncRequest) {
        DDLogInfo(@"Sync for Group ID %@ (creator %@) already requested.", groupId, groupCreator);
    } else {
        DDLogWarn(@"Group ID %@ (creator %@) not found. Requesting sync from creator.", groupId, groupCreator);
        [self sendGroupRequestSyncMessageForCreator:groupCreator groupId:groupId];
        
        [GroupProxy recordSyncRequestWithGroupId:groupId creator:groupCreator];
    }
}

+ (void)recordSyncRequestWithGroupId:(NSData *)groupId creator:(NSString *)groupCreator {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        /* Record this sync request */
        LastGroupSyncRequest *lastSyncRequest = [entityManager.entityCreator lastGroupSyncRequest];
        lastSyncRequest.groupCreator = groupCreator;
        lastSyncRequest.groupId = groupId;
        lastSyncRequest.lastSyncRequest = [NSDate date];
    }];
}

+ (void)sendGroupRequestSyncMessageForCreator:(NSString*)creator groupId:(NSData*)groupId {
    /* Fetch creator public key first if necessary */
    EntityManager *entityManager = [[EntityManager alloc] init];
    __block Contact *creatorContact = [entityManager.entityFetcher contactForId:creator];
    if (creatorContact == nil) {
        /* must fetch key */
        [[ContactStore sharedContactStore] fetchPublicKeyForIdentity:creator onCompletion:^(NSData *publicKey) {
            dispatch_async(dispatch_get_main_queue(), ^{
                creatorContact = [entityManager.entityFetcher contactForId:creator];
                if (creatorContact != nil) {
                    [MessageSender sendGroupRequestSyncMessageForCreatorContact:creatorContact groupId:groupId];
                }
            });
        } onError:^(NSError *error) {
            DDLogWarn(@"Could not fetch public key for %@: %@", creator, error);
        }];
    } else {
        [MessageSender sendGroupRequestSyncMessageForCreatorContact:creatorContact groupId:groupId];
    }
}

- (void)resendSyncRequest {
    if (_lastSyncRequest) {
        [GroupProxy sendSyncRequestWithGroupId:_lastSyncRequest.groupId creator:_lastSyncRequest.groupCreator];
    }
}

- (void)sendGroupCreateToAllMembers {
    for (Contact *contact in self.members) {
        [MessageSender sendGroupCreateMessageForGroup:self toMember:contact];
    }
}

- (void)syncGroupInfoToIdentity:(NSString *)identity {
    Contact *member = [self contactForMemberIdentity:identity];
    if (member) {
        [self syncGroupInfoToContact:member];
    } else {
        // Send empty group create to non-member (but no rename/image/ballots)
        Contact *nonMember = [[ContactStore sharedContactStore] contactForIdentity:identity];
        [MessageSender sendGroupCreateMessageForGroup:self toMember:nonMember];
    }
}

- (void)syncGroupInfoToContact:(Contact *)contact {
    
    [MessageSender sendGroupCreateMessageForGroup:self toMember:contact];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [MessageSender sendGroupRenameMessageForConversation:_conversation toMember:contact addSystemMessage:NO];
        [MessageSender sendGroupSharedMessagesForConversation:_conversation toMember:contact];
        
        if (_conversation.groupImage != nil) {
            GroupPhotoSender *sender = [[GroupPhotoSender alloc] init];
            [sender startWithImageData:_conversation.groupImage.data inConversation:_conversation toMember:contact onCompletion:^{} onError:^(NSError *error) {
                DDLogError(@"Sending group photo failed: %@", error);
            }];
        }
    });
}

- (void)syncGroupInfoToAll {
    [self sendGroupCreateToAllMembers];
    [MessageSender sendGroupRenameMessageForConversation:_conversation addSystemMessage:NO];
    
    if (_conversation.groupImage != nil) {
        GroupPhotoSender *sender = [[GroupPhotoSender alloc] init];
        [sender startWithImageData:_conversation.groupImage.data inConversation:_conversation toMember:nil onCompletion:^{} onError:^(NSError *error) {
            DDLogError(@"Sending group photo failed: %@", error);
        }];
    }
}

- (void)adminDeleteGroup {
    [MessageSender sendGroupLeaveMessageForConversation:_conversation];
    
    /* record deleted group if necessary */
    if (_conversation.contact != nil) {
        [self setGroupState:kGroupStateLeft];
        
        _conversation = nil;
    }
}

- (Group *)group {
    if (_group == nil) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        _group = [entityManager.entityCreator group];
        _group.groupCreator = _conversation.contact.identity;
        _group.groupId = _conversation.groupId;
        _group.state = [NSNumber numberWithInt:kGroupStateActive];
    }

    return _group;
}

- (void)setGroupState:(GroupState)state {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        self.group.state = [NSNumber numberWithInt:state];
    }];
}

- (void)remoteAddGroupMember:(NSString*)memberIdentity notify:(BOOL)notify remoteSentDate:remoteSentDate {
    if ([memberIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        [self setGroupState:kGroupStateActive];

        [self postSystemMessageType:kSystemMessageGroupSelfAdded withArg:nil remoteSentDate:remoteSentDate];
        return;
    }

    EntityManager *entityManager = [[EntityManager alloc] init];
    Contact *member = [entityManager.entityFetcher contactForId:memberIdentity];
    if (member == nil) {
        /* must fetch key */
        [self fetchPublicKeyForMember:memberIdentity onCompletion:^(Contact *contact) {
            [self newGroupMemberPostProcess:contact notify:notify remoteSentDate:remoteSentDate];
        }];
    } else {
        [_conversation addMembersObject:member];
        
        [self newGroupMemberPostProcess:member notify:notify remoteSentDate:remoteSentDate];
    }
}

- (void)updateGroupMyIdentity:(NSString *)groupMyIdentity forConversation:(Conversation *)conversation {
    if ([groupMyIdentity isEqualToString:conversation.groupMyIdentity]) {        
        return;
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        conversation.groupMyIdentity = groupMyIdentity;
    }];
}

- (void)remoteGroupMemberLeft:(NSString *)memberIdentity remoteSentDate:remoteSentDate {
    Contact *member = [self removeGroupMember:memberIdentity];
    if (member) {
        [self postSystemMessageForMember:member type:kSystemMessageGroupMemberLeave remoteSentDate:remoteSentDate];
    }
}


- (void)remoteRemoveGroupMember:(NSString *)memberIdentity remoteSentDate:remoteSentDate {
    if ([memberIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        [self setGroupState:kGroupStateForcedLeft];
        
        [self postSystemMessageType:kSystemMessageGroupSelfRemoved withArg:nil remoteSentDate:remoteSentDate];
        return;
    }

    Contact *member = [self removeGroupMember:memberIdentity];
    if (member) {
        [self postSystemMessageForMember:member type:kSystemMessageGroupMemberForcedLeave remoteSentDate:remoteSentDate];
    }
}

- (Contact *)removeGroupMember:(NSString *)memberIdentity {
    Contact *member = [self contactForMemberIdentity:memberIdentity];
    if (member) {
        [_conversation removeMembersObject:member];
    }
    
    return member;
}

- (void)newGroupMemberPostProcess:(Contact *)newMember notify:(BOOL)notify remoteSentDate:remoteSentDate {
    // send own open ballots
    for (Ballot *ballot in _conversation.ballots) {
        if (ballot.isOwn && [ballot isClosed] == NO) {
            [MessageSender sendGroupSharedMessagesForConversation:_conversation toMember:newMember];
        }
    }
    
    if (notify) {
        [self postSystemMessageForMember:newMember type:kSystemMessageGroupMemberAdd remoteSentDate:remoteSentDate];
    }
}

- (void)fetchPublicKeyForMember:(NSString *)identity onCompletion:(void(^)(Contact *contact))onCompletion {
    [[ContactStore sharedContactStore] fetchPublicKeyForIdentity:identity onCompletion:^(NSData *publicKey) {
        __block Contact *newMember;
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            /* add member to group */
            newMember = [entityManager.entityFetcher contactForId:identity];
            if (newMember != nil) {
                /* Check if this member has already been added, as it's possible that it happens twice
                 due to overlapping asynchronous ID fetches (i.e. multiple group create/update messages
                 coming in at once) */
                if (![[_conversation members] containsObject:newMember]) {
                    [_conversation addMembersObject:newMember];
                }
            }
        }];
        
        onCompletion(newMember);
    } onError:^(NSError *error) {
        DDLogWarn(@"Could not fetch public key for %@: %@", identity, error);
    }];
}

- (void)postSystemMessageForMember:(Contact*)contact type:(NSInteger)type remoteSentDate:remoteSentDate {
    NSData *arg = [contact.displayName dataUsingEncoding:NSUTF8StringEncoding];
    [self postSystemMessageType:type withArg:arg remoteSentDate:remoteSentDate];
}

- (void)postSystemMessageType:(NSInteger)type withArg:(NSData *)arg remoteSentDate:(NSDate*)remoteSentDate {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        /* Insert system message to document this change */
        SystemMessage *systemMessage = [entityManager.entityCreator systemMessageForConversation:_conversation];
        systemMessage.type = [NSNumber numberWithInteger:type];
        systemMessage.arg = arg;
        systemMessage.remoteSentDate = remoteSentDate;
    }];
}

- (NSString *)description {
    NSString *result = @"Group ";
    result = [result stringByAppendingFormat: @"name: %@\n", self.name];
    result = [result stringByAppendingFormat: @"members: %@\n", self.members];
    result = [result stringByAppendingFormat: @"conversation: %@\n", _conversation];
    result = [result stringByAppendingFormat: @"group: %@\n", _group];
    result = [result stringByAppendingFormat: @"lastSyncRequest: %@\n", _lastSyncRequest];

    return result;
}

@end
