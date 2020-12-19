//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

#import "ImageMessage.h"
#import "BoxImageMessage.h"
#import "GroupImageMessage.h"

#import "VideoMessage.h"
#import "BoxVideoMessage.h"
#import "GroupVideoMessage.h"

#import "AudioMessage.h"
#import "BoxAudioMessage.h"
#import "GroupAudioMessage.h"

#import "LocationMessage.h"
#import "BoxLocationMessage.h"
#import "GroupLocationMessage.h"

#import "SystemMessage.h"

#import "LastGroupSyncRequest.h"
#import "Group.h"

#import "BallotMessage.h"
#import "BoxBallotCreateMessage.h"
#import "GroupBallotCreateMessage.h"

#import "BallotChoice.h"
#import "BallotResult.h"

#import "FileMessage.h"
#import "Nonce.h"

#import "Tag.h"
#import "WebClientSession.h"
#import "RequestedConversation.h"
#import "LastLoadedMessageIndex.h"
#import "RequestedThumbnail.h"

@interface EntityCreator : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext;

- (TextMessage *)textMessageFromBox:(AbstractMessage *)boxMsg;
- (TextMessage *)textMessageFromGroupBox:(GroupTextMessage *)boxMsg;

- (ImageMessage *)imageMessageFromBox:(BoxImageMessage *)boxMsg;
- (ImageMessage *)imageMessageFromGroupBox:(GroupImageMessage *)boxMsg;

- (VideoMessage *)videoMessageFromBox:(BoxVideoMessage *)boxMsg;
- (VideoMessage *)videoMessageFromGroupBox:(GroupVideoMessage *)boxMsg;

- (AudioMessage *)audioMessageFromBox:(BoxAudioMessage *)boxMsg;
- (AudioMessage *)audioMessageFromGroupBox:(GroupAudioMessage *)boxMsg;

- (LocationMessage *)locationMessageFromBox:(BoxLocationMessage *)boxMsg;
- (LocationMessage *)locationMessageFromGroupBox:(GroupLocationMessage *)boxMsg;

- (BallotMessage *)ballotMessageFromBox:(AbstractMessage *)boxMsg;

- (FileMessage *)fileMessageFromBox:(AbstractMessage *)boxMsg;

- (ImageData *)imageData;

- (AudioData *)audioData;

- (VideoData *)videoData;

- (FileData *)fileData;

- (TextMessage *)textMessageForConversation:(Conversation *)conversation;

- (ImageMessage *)imageMessageForConversation:(Conversation *)conversation;

- (VideoMessage *)videoMessageForConversation:(Conversation *)conversation;

- (FileMessage *)fileMessageForConversation:(Conversation *)conversation;

- (AudioMessage *)audioMessageForConversation:(Conversation *)conversation;

- (LocationMessage *)locationMessageForConversation:(Conversation *)conversation;

- (SystemMessage *)systemMessageForConversation:(Conversation *)conversation;

- (BallotMessage *)ballotMessageForConversation:(Conversation *)conversation;

- (Contact *)contact;

- (LastGroupSyncRequest *)lastGroupSyncRequest;

- (Conversation *)conversation;

- (Group *)group;

- (Ballot *)ballot;

- (BallotChoice *)ballotChoice;

- (BallotResult *)ballotResult;

- (Nonce *)nonceWithData:(NSData*)nonce;

- (Tag *)tagWithName:(NSString *)name;

- (WebClientSession *)webClientSession;

- (RequestedConversation *)requestedConversationWithId:(NSString *)conversationId webClientSession:(WebClientSession*)webClientSession;

- (LastLoadedMessageIndex *)lastLoadedMessageIndexWithBaseMessageId:(NSData *)baseMessageId index:(NSInteger)index webClientSession:(WebClientSession*)webClientSession;

- (RequestedThumbnail *)requestedThumbnailWithMessageId:(NSData *)messageId webClientSession:(WebClientSession*)webClientSession;

@end
