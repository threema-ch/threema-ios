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

#import "TextMessage.h"
#import "BoxTextMessage.h"
#import "GroupTextMessage.h"

#import "ImageMessageEntity.h"
#import "BoxImageMessage.h"
#import "GroupImageMessage.h"

#import "VideoMessageEntity.h"
#import "BoxVideoMessage.h"
#import "GroupVideoMessage.h"

#import "AudioMessageEntity.h"
#import "BoxAudioMessage.h"
#import "GroupAudioMessage.h"

#import "LocationMessage.h"
#import "BoxLocationMessage.h"
#import "GroupLocationMessage.h"

#import "SystemMessage.h"

#import "LastGroupSyncRequest.h"
#import "GroupEntity.h"

#import "BallotMessage.h"
#import "BoxBallotCreateMessage.h"
#import "GroupBallotCreateMessage.h"

#import "BallotChoice.h"
#import "BallotResult.h"

#import "FileMessageEntity.h"
#import "Nonce.h"

#import "Tag.h"
#import "WebClientSession.h"
#import "RequestedConversation.h"
#import "LastLoadedMessageIndex.h"
#import "RequestedThumbnail.h"

#import "CallEntity.h"

@interface EntityCreator : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext;

- (TextMessage *)textMessageFromBox:(AbstractMessage *)boxMsg;
- (TextMessage *)textMessageFromGroupBox:(GroupTextMessage *)boxMsg;

- (ImageMessageEntity *)imageMessageEntityFromBox:(BoxImageMessage *)boxMsg;
- (ImageMessageEntity *)imageMessageEntityFromGroupBox:(GroupImageMessage *)boxMsg;

- (VideoMessageEntity *)videoMessageEntityFromBox:(BoxVideoMessage *)boxMsg;
- (VideoMessageEntity *)videoMessageEntityFromGroupBox:(GroupVideoMessage *)boxMsg;

- (AudioMessageEntity *)audioMessageEntityFromBox:(BoxAudioMessage *)boxMsg;
- (AudioMessageEntity *)audioMessageEntityFromGroupBox:(GroupAudioMessage *)boxMsg;

- (LocationMessage *)locationMessageFromBox:(BoxLocationMessage *)boxMsg;
- (LocationMessage *)locationMessageFromGroupBox:(GroupLocationMessage *)boxMsg;

- (BallotMessage *)ballotMessageFromBox:(AbstractMessage *)boxMsg;

- (FileMessageEntity *)fileMessageEntityFromBox:(AbstractMessage *)boxMsg;

- (ImageData *)imageData;

- (AudioData *)audioData;

- (VideoData *)videoData;

- (FileData *)fileData;

- (TextMessage *)textMessageForConversation:(Conversation *)conversation;

- (ImageMessageEntity *)imageMessageEntityForConversation:(Conversation *)conversation;

- (VideoMessageEntity *)videoMessageEntityForConversation:(Conversation *)conversation;

- (FileMessageEntity *)fileMessageEntityForConversation:(Conversation *)conversation;

- (AudioMessageEntity *)audioMessageEntityForConversation:(Conversation *)conversation;

- (LocationMessage *)locationMessageForConversation:(Conversation *)conversation;

- (SystemMessage *)systemMessageForConversation:(Conversation *)conversation;

- (BallotMessage *)ballotMessageForConversation:(Conversation *)conversation;

- (Contact *)contact;

- (LastGroupSyncRequest *)lastGroupSyncRequest;

- (Conversation *)conversation;

- (GroupEntity *)groupEntity;

- (Ballot *)ballot;

- (BallotChoice *)ballotChoice;

- (BallotResult *)ballotResult;

- (Nonce *)nonceWithData:(NSData*)nonce;

- (Tag *)tagWithName:(NSString *)name;

- (WebClientSession *)webClientSession;

- (RequestedConversation *)requestedConversationWithId:(NSString *)conversationId webClientSession:(WebClientSession*)webClientSession;

- (LastLoadedMessageIndex *)lastLoadedMessageIndexWithBaseMessageId:(NSData *)baseMessageId index:(NSInteger)index webClientSession:(WebClientSession*)webClientSession;

- (RequestedThumbnail *)requestedThumbnailWithMessageId:(NSData *)messageId webClientSession:(WebClientSession*)webClientSession;

- (CallEntity *)callEntity;

@end
