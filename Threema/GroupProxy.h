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

#import <Foundation/Foundation.h>
#import "Conversation.h"
#import "Contact.h"
#import "AbstractGroupMessage.h"

@class EntityManager;

@interface GroupProxy : NSObject

@property (readonly) NSData *groupId;
@property (readonly) NSString *name;
@property (readonly) NSSet *members;
@property (readonly) NSSet *activeMembers;
@property (readonly) NSSet *activeMemberIds;
@property (readonly) NSSet *memberIdsIncludingSelf;
@property (readonly) Contact *creator;

+ (instancetype)groupProxyForConversation:(Conversation *)conversation;
+ (instancetype)groupProxyForConversation:(Conversation *)conversation entityManager:(EntityManager*)entityManager;

+ (instancetype)groupProxyForMessage:(AbstractGroupMessage *)message;

+ (instancetype)newGroupWithId:(NSData *)groupId creator:(Contact *)creator;

+ (void)sendSyncRequestWithGroupId:(NSData *)groupId creator:(NSString *)groupCreator;

+ (void)recordSyncRequestWithGroupId:(NSData *)groupId creator:(NSString *)groupCreator;

- (BOOL)isOwnGroup;

- (BOOL)isSelfMember;

- (void)setName:(NSString *)name remoteSentDate:(NSDate*)remoteSentDate;

- (BOOL)didLeaveGroup;

- (BOOL)didRequestSync;

- (BOOL)canSendInGroup;

- (Contact *)contactForMemberIdentity:(NSString *)identity;

- (void)resendSyncRequest;

- (void)resendLeaveMessageTo:(NSString *)identity;

- (Conversation *)conversation;

- (void)adminAddMembersFromBackup:(NSSet *)identities entityManager:(EntityManager*)entityManager;

- (void)adminAddMember:(Contact *)contact;

- (void)adminRemoveMember:(Contact *)contact;

- (void)adminDeleteGroup;

- (BOOL)isGroupMember:(NSString *)contactIdentity;

- (void)remoteAddGroupMember:(NSString*)memberIdentity notify:(BOOL)notify remoteSentDate:remoteSentDate;

- (void)remoteRemoveGroupMember:(NSString*)memberIdentity remoteSentDate:remoteSentDate;

- (void)remoteGroupMemberLeft:(NSString *)memberIdentity remoteSentDate:remoteSentDate;

- (void)updateGroupMyIdentity:(NSString *)groupMyIdentity forConversation:(Conversation *)conversation;

- (void)syncGroupInfoToIdentity:(NSString *)identity;

- (void)syncGroupInfoToContact:(Contact *)contact;

- (void)syncGroupInfoToAll;

- (NSString *)creatorString;

- (NSString *)membersSummaryString;

- (NSArray *)sortedActiveMembers;

- (void)leaveGroup;

@end
