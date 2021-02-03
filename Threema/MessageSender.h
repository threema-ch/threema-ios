//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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
#import <CoreLocation/CoreLocation.h>

#import "AbstractMessage.h"
#import "BaseMessage.h"

#import "BallotMessage.h"
#import "TextMessage.h"
#import "GroupProxy.h"

@class Conversation;
@class Contact;

@interface MessageSender : NSObject

+ (void)sendDeliveryReceiptForMessage:(BaseMessage*)message fromIdentity:(NSString*)identity;
+ (void)sendDeliveryReceiptForAbstractMessage:(AbstractMessage*)message fromIdentity:(NSString*)identity;

+ (void)sendMessage:(NSString*)message inConversation:(Conversation*)conversation async:(BOOL)async quickReply:(BOOL)quickReply requestId:(NSString *)requestId onCompletion:(void(^)(TextMessage *message, Conversation *conv))onCompletion;
+ (void)sendLocation:(CLLocationCoordinate2D)coordinates accuracy:(CLLocationAccuracy)accuracy poiName:(NSString*)poiName poiAddress:(NSString*)poiAddress inConversation:(Conversation*)conversation onCompletion:(void(^)(NSData *messageId))onCompletion;

+ (void)markMessageAsSent:(NSData*)messageId;

+ (void)sendReadReceiptForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply;
+ (void)sendUserAckForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply;
+ (void)sendUserDeclineForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply;

+ (void)sendTypingIndicatorMessage:(BOOL)typing toIdentity:(NSString*)identity;

+ (void)sendGroupCreateMessageForGroup:(GroupProxy*)group toMember:(Contact*)toMember;

+ (void)sendGroupSharedMessagesForConversation:(Conversation*)groupConversation toMember:(Contact *)newMember;

+ (void)sendGroupRenameMessageForConversation:(Conversation*)groupConversation addSystemMessage:(BOOL)addSystemMessage;
+ (void)sendGroupRenameMessageForConversation:(Conversation *)groupConversation toMember:(Contact*)member addSystemMessage:(BOOL)addSystemMessage;
+ (void)sendGroupLeaveMessageForConversation:(Conversation*)groupConversation;

+ (void)sendGroupLeaveMessageForCreator:(NSString*)creator groupId:(NSData*)groupId toIdentity:(NSString*)toIdentity;
+ (void)sendGroupRequestSyncMessageForCreatorContact:(Contact*)creatorContact groupId:(NSData*)groupId;

+ (void)markBlobAsDone:(NSData *)blobId;

+ (void)sendCreateMessageForBallot:(Ballot *)ballot;

+ (void)sendBallotVoteMessage:(Ballot *)ballot;

@end
