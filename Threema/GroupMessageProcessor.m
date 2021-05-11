//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "GroupMessageProcessor.h"
#import "EntityManager.h"
#import "MessageSender.h"
#import "GroupProxy.h"
#import "GroupCreateMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupRequestSyncMessage.h"
#import "GroupPhotoSender.h"
#import "MyIdentityStore.h"
#import "ContactStore.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface GroupMessageProcessor ()

@property AbstractGroupMessage *message;
@property GroupProxy *group;
@property EntityManager *entityManager;

@end


@implementation GroupMessageProcessor

+ (instancetype)groupMessageProcessorForMessage:(AbstractGroupMessage *)message {
    return [[GroupMessageProcessor alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(AbstractGroupMessage *)message
{
    self = [super init];
    if (self) {
        self.entityManager = [[EntityManager alloc] init];
        self.message = message;
        self.group = [self groupProxyForMessage:message];
        self.isNewGroup = NO;
        self.rejectMessage = false;
    }
    
    return self;
}

- (void)handleMessageOnCompletion:(void (^)(BOOL))onCompletion onError:(void(^)(NSError *error))onError {
    if ([_message isKindOfClass:[GroupCreateMessage class]]) {
        [self processIncomingGroupCreateMessage:(GroupCreateMessage *)_message onCompletion:^{
            onCompletion(YES);
        } onError:^(NSError *error) {
            onError(error);
        }];
        return;
    }
    
    if (_group == nil) {
        /* Group not found. This can happen e.g. if the user reinstalls the app, so the app won't
         know anything about the group. */
        
        if ([_message.groupCreator isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
            /* Sending a sync request to ourselves won't do any good. We don't know the member list of this
             group, so all we can do is send a leave message to the sender of this message */
            DDLogWarn(@"Group creator is ourselves, but group is unknown. Sending leave message to %@.", _message.fromIdentity);
            [MessageSender sendGroupLeaveMessageForCreator:_message.groupCreator groupId:_message.groupId toIdentity:_message.fromIdentity];
            
        } else if ([_message isKindOfClass:[GroupRequestSyncMessage class]] == NO) {
            // do that only if it's not from notification extension file
            DDLogInfo(@"Unknown group %@. Aadd to pending messages and request group sync", _message.groupId);
            [GroupProxy sendSyncRequestWithGroupId:_message.groupId creator:_message.groupCreator];
            _addToPendingMessages = YES;
        }
        
        onCompletion(YES);
        return;
    } else if (_group.didLeaveGroup) {
        [_group resendLeaveMessageTo: _message.fromIdentity];
        onCompletion(YES);
        return;
    } else if (_group.didRequestSync) {
        [_group resendSyncRequest];
        _addToPendingMessages = YES;
        onCompletion(YES);
        return;
    }

    if ([_group isGroupMember:_message.fromIdentity] == NO) {
        if (_group.isOwnGroup) {
            DDLogInfo(@"%@ is not member of group %@, resend group info", _message.fromIdentity, _message.groupId);
            [_group syncGroupInfoToIdentity:_message.fromIdentity];
            _rejectMessage = true;
        } else {
            if ([_message isKindOfClass:[GroupLeaveMessage class]]) {
                // member is already removed, reject the message
                DDLogInfo(@"%@ is already removed from the group %@", _message.fromIdentity, _message.groupId);
                _rejectMessage = true;
            }
            else if ([_message isKindOfClass:[GroupRequestSyncMessage class]] == NO) {
                // do that only if it's not from notification extension file
                DDLogInfo(@"%@ is not member of group %@, add to pending messages and request group sync", _message.fromIdentity, _message.groupId);
                [GroupProxy sendSyncRequestWithGroupId:_message.groupId creator:_message.groupCreator];
                _addToPendingMessages = YES;
            }
        }
        
        onCompletion(YES);
        return;
    }

    if ([_message isKindOfClass:[GroupLeaveMessage class]]) {
        [_group remoteGroupMemberLeft:_message.fromIdentity remoteSentDate:_message.date];
        onCompletion(YES);
    } else if ([_message isKindOfClass:[GroupRequestSyncMessage class]]) {
        [_group syncGroupInfoToIdentity:_message.fromIdentity];
        onCompletion(YES);
    } else {
        onCompletion(NO);
    }
}

- (Conversation *)conversation {
    return [_entityManager.entityFetcher conversationForGroupMessage:_message];
}

- (void)processIncomingGroupCreateMessage:(GroupCreateMessage *)msg onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    // Record a pseudo sync request so we won't trigger another one if we process
    // messages in this new group while we are still processing the group create
    [GroupProxy recordSyncRequestWithGroupId:msg.groupId creator:msg.groupCreator];
    
    // Ensure we have the public keys etc. of all new group members available before we start.
    // This avoids lots of individual identity fetch requests to the server.
    [[ContactStore sharedContactStore] prefetchIdentityInfo:[NSMutableSet setWithArray:msg.groupMembers] onCompletion:^{
        Conversation *conversation = [_entityManager.entityFetcher conversationForGroupMessage:msg];
        if (conversation) {
            DDLogVerbose(@"Group create: group already in DB - ID %@ from %@ already in database", msg.groupId, msg.fromIdentity);
            _group = [GroupProxy groupProxyForConversation:conversation];
            _isNewGroup = NO;

            NSMutableSet *members = [NSMutableSet setWithArray:msg.groupMembers];
            [members addObject:msg.fromIdentity];
            
            [self updateMembers:members remoteSentDate:msg.date];
        
            /* update GroupMyIdentity in conversation to send messages if we were (re-)added to existing group */
            [_group updateGroupMyIdentity:[MyIdentityStore sharedMyIdentityStore].identity forConversation:conversation];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationUpdatedGroup object:self userInfo:@{@"groupId": _group.groupId, @"creatorString": _group.creatorString}];
            if ([_delegate respondsToSelector:@selector(startProcessPendingGroupMessages)]) {
                [_delegate startProcessPendingGroupMessages];
            }
            
        } else {
            DDLogVerbose(@"Group create: new group - creator %@, group ID %@, members %@", msg.fromIdentity, msg.groupId, msg.groupMembers);
            
            if (msg.groupMembers.count == 1) {
                NSString *memberIdentity = msg.groupMembers.firstObject;
                if ([memberIdentity isEqualToString:msg.groupCreator]) {
                    onCompletion();
                    return;
                }
            }
            _group = [self createNewGroupFromMessage:msg];
            _isNewGroup = YES;
        }
        onCompletion();
    } onError:^(NSError *error) {
        DDLogError(@"Cannot prefetch group members: %@", error);
        onError(error);
    }];
}

- (void)updateMembers:(NSSet *)memberIdentities remoteSentDate:(NSDate*)remoteSentDate {
    
    for (NSString *groupMemberId in _group.memberIdsIncludingSelf) {
        if ([memberIdentities containsObject:groupMemberId] == NO) {
            [_group remoteRemoveGroupMember:groupMemberId remoteSentDate:remoteSentDate];
        }
    }
    
    for (NSString *memberIdentity in memberIdentities) {
        if ([_group isGroupMember:memberIdentity] == NO) {
            [_group remoteAddGroupMember:memberIdentity notify:YES remoteSentDate:remoteSentDate];
        } else {
            if ([memberIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity] && [_group didLeaveGroup] == true) {
                [_group remoteAddGroupMember:memberIdentity notify:YES remoteSentDate:remoteSentDate];
            }
        }
    }
}

- (GroupProxy *)groupProxyForMessage:(AbstractGroupMessage *)message {
    Conversation *conversation = [_entityManager.entityFetcher conversationForGroupMessage:message];
    
    return [GroupProxy groupProxyForConversation:conversation];
}

- (GroupProxy *)createNewGroupFromMessage:(GroupCreateMessage *)message {
    /* Find contact for group creator */
    Contact *creator = [_entityManager.entityFetcher contactForId:message.fromIdentity];
    if (creator == nil) {
        /* This should never happen, as without an entry in the contacts database, we wouldn't have
         been able to decrypt this message in the first place (no sender public key) */
        DDLogWarn(@"Identity %@ not in local contacts database - cannot process message", message.fromIdentity);
        return nil;
    }
    
    /* create new group */
    GroupProxy *group = [GroupProxy newGroupWithId:message.groupId creator:creator];
    [group remoteAddGroupMember:creator.identity notify:NO remoteSentDate:message.date];
    
    /* fetch all group members */
    for (NSString *memberIdentity in message.groupMembers) {
        [group remoteAddGroupMember:memberIdentity notify:NO remoteSentDate:message.date];
    }
    
    [_entityManager performSyncBlockAndSafe:nil];
    
    return group;
}

@end
