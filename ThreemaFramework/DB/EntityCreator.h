//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "BoxTextMessage.h"
#import "GroupTextMessage.h"

#import "BoxImageMessage.h"
#import "GroupImageMessage.h"

#import "BoxVideoMessage.h"
#import "GroupVideoMessage.h"

#import "BoxAudioMessage.h"
#import "GroupAudioMessage.h"

#import "BoxLocationMessage.h"
#import "GroupLocationMessage.h"

#import "BallotMessage.h"
#import "BoxBallotCreateMessage.h"
#import "GroupBallotCreateMessage.h"

#import "BallotChoice.h"


@class AudioDataEntity;
@class AudioMessageEntity;
@class CallEntity;
@class DistributionListEntity;
@class FileMessageEntity;
@class FileDataEntity;
@class GroupCallEntity;
@class GroupEntity;
@class ImageMessageEntity;
@class LastGroupSyncRequestEntity;
@class LocationMessageEntity;
@class MessageHistoryEntryEntity;
@class NonceEntity;
@class MessageMarkersEntity;
@class BallotResultEntity;
@class VideoMessageEntity;
@class VideoDataEntity;
@class SystemMessageEntity;
@class TextMessageEntity;
@class WebClientSessionEntity;

@interface EntityCreator : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext;

- (TextMessageEntity *)textMessageEntityFromBox:(AbstractMessage *)boxMsg;
- (TextMessageEntity *)textMessageEntityFromGroupBox:(GroupTextMessage *)boxMsg;

- (ImageMessageEntity *)imageMessageEntityFromBox:(BoxImageMessage *)boxMsg;
- (ImageMessageEntity *)imageMessageEntityFromGroupBox:(GroupImageMessage *)boxMsg;

- (VideoMessageEntity *)videoMessageEntityFromBox:(BoxVideoMessage *)boxMsg;
- (VideoMessageEntity *)videoMessageEntityFromGroupBox:(GroupVideoMessage *)boxMsg;

- (AudioMessageEntity *)audioMessageEntityFromBox:(BoxAudioMessage *)boxMsg;
- (AudioMessageEntity *)audioMessageEntityFromGroupBox:(GroupAudioMessage *)boxMsg;

- (LocationMessageEntity *)locationMessageEntityFromBox:(BoxLocationMessage *)boxMsg;
- (LocationMessageEntity *)locationMessageEntityFromGroupBox:(GroupLocationMessage *)boxMsg;

- (BallotMessage *)ballotMessageFromBox:(AbstractMessage *)boxMsg;

- (FileMessageEntity *)fileMessageEntityFromBox:(AbstractMessage *)boxMsg;

- (ImageDataEntity *)imageDataEntity;

- (AudioDataEntity *)audioDataEntity;

- (VideoDataEntity *)videoDataEntity;

- (FileDataEntity *)fileDataEntity;

- (TextMessageEntity *)textMessageEntityForConversationEntity:(ConversationEntity *)conversation setLastUpdate:(BOOL)setLastUpdate;

- (ImageMessageEntity *)imageMessageEntityForConversationEntity:(ConversationEntity *)conversation;

- (VideoMessageEntity *)videoMessageEntityForConversationEntity:(ConversationEntity *)conversation;

- (FileMessageEntity *)fileMessageEntityForConversationEntity:(ConversationEntity *)conversation;

- (AudioMessageEntity *)audioMessageEntityForConversationEntity:(ConversationEntity *)conversation;

- (LocationMessageEntity *)locationMessageEntityForConversationEntity:(ConversationEntity *)conversation setLastUpdate:(BOOL)setLastUpdate;

- (SystemMessageEntity *)systemMessageEntityForConversationEntity:(ConversationEntity *)conversation;

- (BallotMessage *)ballotMessageForConversationEntity:(ConversationEntity *)conversation;

- (ContactEntity *)contact;

- (LastGroupSyncRequestEntity *)lastGroupSyncRequestEntity;

- (ConversationEntity *)conversationEntity;

- (ConversationEntity *)conversationEntity:(BOOL)setLastUpdate;

- (GroupEntity *)groupEntity;

- (Ballot *)ballot;

- (BallotChoice *)ballotChoice;

- (BallotResultEntity *)ballotResultEntity;

- (NonceEntity *)nonceEntityWithData:(NSData*)nonce;

- (MessageMarkersEntity *)messageMarkersEntity;

- (MessageHistoryEntryEntity *)messageHistoryEntryFor:(BaseMessage *)message NS_SWIFT_NAME(messageHistoryEntry(for:));;

- (WebClientSessionEntity *)webClientSessionEntity;

- (CallEntity *)callEntity;

- (GroupCallEntity *)groupCallEntity;

- (DistributionListEntity*)distributionListEntity;

@end
