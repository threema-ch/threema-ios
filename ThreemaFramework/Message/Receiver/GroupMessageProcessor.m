//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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
#import "GroupCreateMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupRequestSyncMessage.h"
#import "GroupPhotoSender.h"
#import "MyIdentityStore.h"
#import "ContactStore.h"
#import "ImageData.h"
#import "EntityFetcher.h"
#import "UserSettings.h"
#import "ThreemaError.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NSString+Hex.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface GroupMessageProcessor ()

@property AbstractGroupMessage *message;

@end

@implementation GroupMessageProcessor {
    id<MyIdentityStoreProtocol> myIdentityStore;
    id<UserSettingsProtocol> userSettings;
    id<GroupManagerProtocolObjc> groupManager;
    EntityManager *entityManager;
    id<NonceGuardProtocolObjc> nonceGuard;
}

- (nonnull instancetype)initWithMessage:(nonnull AbstractGroupMessage *)message myIdentityStore:(id<MyIdentityStoreProtocol> _Nonnull)myIdentityStore userSettings:(id<UserSettingsProtocol> _Nonnull)userSettings groupManager:(nonnull NSObject *)groupManagerObject entityManager:(nonnull NSObject *)entityManagerObject nonceGuard:(nonnull NSObject *)nonceGuardObject
{
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");
    NSAssert([nonceGuardObject conformsToProtocol:@protocol(NonceGuardProtocolObjc)], @"Object must implement NonceGuardProtocolObjc");

    self = [super init];
    if (self) {
        self.message = message;
        self->myIdentityStore = myIdentityStore;
        self->userSettings = userSettings;
        self->groupManager = (id<GroupManagerProtocolObjc>)groupManagerObject;
        self->entityManager = (EntityManager *)entityManagerObject;
        self->nonceGuard = (id<NonceGuardProtocolObjc>)nonceGuardObject;
    }

    return self;
}

- (void)handleMessageOnCompletion:(void (^)(BOOL))onCompletion onError:(void(^)(NSError * _Nonnull))onError {
    if ([nonceGuard isProcessedWithMessage:_message] == YES) {
        onError([ThreemaError threemaError:[NSString stringWithFormat:@"Message nonce reuse (ID: %@)", _message.messageId] withCode:ThreemaProtocolErrorMessageNonceReuse]);
        return;
    }

    if ([_message isKindOfClass:[GroupCreateMessage class]]) {
        GroupCreateMessage *grpCreate = (GroupCreateMessage *)_message;
        [groupManager createOrUpdateDBObjcWithGroupID:grpCreate.groupId creator:grpCreate.groupCreator members:[[NSSet alloc] initWithArray:grpCreate.groupMembers] systemMessageDate:_message.date sourceCaller:SourceCallerRemote completionHandler:^(NSError * _Nullable error) {
            if (error == nil) {
                onCompletion(YES);
            }
            else {
                onError(error);
            }
        }];
    }
    else {
        Group *grp = [groupManager getGroup:_message.groupId creator:_message.groupCreator];

        if (grp == nil) {
            /* Group not found. This can happen e.g. if the user reinstalls the app, so the app don't
             know anything about the group. */

            // If group creator it's me the message couldn't processed because of missing group
            if (![_message.groupCreator isEqualToString:myIdentityStore.identity]) {
                // Just store this message in memory and request group sync
                [self sendSyncRequest];
            }
            else {
                // Dissolve senders group
                [groupManager dissolveWithGroupID:_message.groupId to:[[NSSet alloc] initWithArray:@[_message.fromIdentity]]];
            }

            onCompletion(YES);
        }
        else if (grp.isSelfMember == NO) {
            // 3. If the group is marked as _left_:
            //     1. If the user is the creator of the group, send a
            //        [`group-setup`](ref:e2e.group-setup) with an empty members list back
            //        to the sender, discard the message and abort these steps.
            //     2. Send a [`group-leave`](ref:e2e.group-leave) back to the sender,
            //        discard the message and abort these steps.

            if (grp.isSelfCreator == YES) {
                [groupManager dissolveWithGroupID:_message.groupId to:[[NSSet alloc] initWithArray:@[_message.fromIdentity]]];
            }
            else {
                [groupManager leaveWithGroupID:_message.groupId creator:_message.groupCreator toMembers:@[_message.fromIdentity] systemMessageDate:[NSDate now]];
            }

            onCompletion(YES);
        }
        else if ([grp isMemberWithIdentity:_message.fromIdentity] == NO) {
            if (grp.isSelfCreator == YES) {
                DDLogInfo(@"%@ is not member of group %@, resend group info", _message.fromIdentity, _message.groupId);
                [self sync:grp toMember:_message.fromIdentity];
            }
            
            onCompletion(YES);
        }
        else if ([_message isKindOfClass:[GroupLeaveMessage class]]) {
            [groupManager leaveDBWithGroupID:_message.groupId creator:_message.groupCreator member:_message.fromIdentity systemMessageDate:_message.date];
            onCompletion(YES);
        } else if ([_message isKindOfClass:[GroupRequestSyncMessage class]]) {
            if (grp.isSelfCreator == YES) {
                if (grp.state == GroupStateActive) {
                    [self sync:grp toMember:_message.fromIdentity];
                }
                else {
                    [groupManager dissolveWithGroupID:grp.groupID to:[[NSSet alloc] initWithArray:@[_message.fromIdentity]]];
                }
            }
            onCompletion(YES);
        } else {
            if (grp.isSelfMember) {
                // This group message has not be handled here, process this group message
                onCompletion(NO);
            }
            else {
                // I'm left the group, won't process this group message
                onCompletion(YES);
            }
        }
    }
}

/**
 Sync group setup to particular member.
 @param toMember: Receiver of GroupCreateMessage
 */
- (void)sync:(Group *)group toMember:(NSString *)toMember {
    [groupManager syncObjcWithGroup:group to:[[NSSet alloc] initWithArray:@[toMember]] withoutCreateMessage:NO completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            DDLogError(@"Error syncing group: %@", error.localizedDescription);
        }
    }];
}

/**
 Send request sync message, if message itself not a GroupRequestSyncMessage and not a GroupLeaveMessage from the creator.
 */
- (void)sendSyncRequest {
    if ([_message isKindOfClass:[GroupRequestSyncMessage class]] == NO &&
        !([_message isKindOfClass:[GroupLeaveMessage class]] == YES && [_message.groupCreator isEqualToString:_message.fromIdentity])) {

        // do that only if it's not from notification extension file
        DDLogInfo(@"%@ is not member of group %@, add to pending messages and request group sync", _message.fromIdentity, [NSString stringWithHexData:_message.groupId]);
        [groupManager sendSyncRequestWithGroupID:_message.groupId creator:_message.groupCreator force:false];
        _addToPendingMessages = YES;
    }
}

@end
