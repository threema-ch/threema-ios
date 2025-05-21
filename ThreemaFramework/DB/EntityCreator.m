//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "EntityCreator.h"
#import "ErrorHandler.h"
#import "DatabaseManager.h"
#import <ThreemaFramework/ThreemaFramework-Swift.h>

@interface EntityCreator ()

@property NSManagedObjectContext *managedObjectContext;

@end

@class ConversationEntity;
@class MessageMarkers;
@class MessageHistoryEntryEntity;

@implementation EntityCreator

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext
{
    self = [super init];
    if (self) {
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (TextMessageEntity *)textMessageEntityFromGroupBox:(GroupTextMessage *)boxMsg {
    TextMessageEntity *message = [self createTextMessageEntityFromBox: boxMsg];
    message.text = boxMsg.text;
    message.quotedMessageId = boxMsg.quotedMessageId;
    
    return message;
}

- (TextMessageEntity *)textMessageEntityFromBox:(BoxTextMessage *)boxMsg {
    TextMessageEntity *message = [self createTextMessageEntityFromBox: boxMsg];
    message.text = boxMsg.text;
    message.quotedMessageId = boxMsg.quotedMessageId;
    
    return message;
}

- (ImageMessageEntity *)imageMessageEntityFromBox:(BoxImageMessage *)boxMsg {
    ImageMessageEntity *message = [self createImageMessageEntityFromBox: boxMsg];
    message.imageSize = [NSNumber numberWithInt:boxMsg.size];
    message.imageBlobId = boxMsg.blobId;
    message.imageNonce = boxMsg.imageNonce;
    
    return message;
}

- (ImageMessageEntity *)imageMessageEntityFromGroupBox:(GroupImageMessage *)boxMsg {
    ImageMessageEntity *message = [self createImageMessageEntityFromBox: boxMsg];
    message.imageSize = [NSNumber numberWithInt:boxMsg.size];
    message.imageBlobId = boxMsg.blobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (VideoMessageEntity *)videoMessageEntityFromBox:(BoxVideoMessage *)boxMsg {
    VideoMessageEntity *message = [self createVideoMessageEntityFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.videoSize = [NSNumber numberWithInt:boxMsg.videoSize];
    message.videoBlobId = boxMsg.videoBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (VideoMessageEntity *)videoMessageEntityFromGroupBox:(GroupVideoMessage *)boxMsg {
    VideoMessageEntity *message = [self createVideoMessageEntityFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.videoSize = [NSNumber numberWithInt:boxMsg.videoSize];
    message.videoBlobId = boxMsg.videoBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (AudioMessageEntity *)audioMessageEntityFromBox:(BoxAudioMessage *)boxMsg {
    AudioMessageEntity *message = [self createAudioMessageEntityFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.audioSize = [NSNumber numberWithInt:boxMsg.audioSize];
    message.audioBlobId = boxMsg.audioBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    return message;
}

- (AudioMessageEntity *)audioMessageEntityFromGroupBox:(GroupAudioMessage *)boxMsg {
    AudioMessageEntity *message = [self createAudioMessageEntityFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.audioSize = [NSNumber numberWithInt:boxMsg.audioSize];
    message.audioBlobId = boxMsg.audioBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (LocationMessageEntity *)locationMessageEntityFromBox:(BoxLocationMessage *)boxMsg {
    LocationMessageEntity *message = [self createLocationMessageEntityFromBox:boxMsg];
    message.latitude = [NSNumber numberWithDouble:boxMsg.latitude];
    message.longitude = [NSNumber numberWithDouble:boxMsg.longitude];
    message.accuracy = [NSNumber numberWithDouble:boxMsg.accuracy];
    message.poiName = boxMsg.poiName;
    message.poiAddress = boxMsg.poiAddress;
    
    return message;
}

- (LocationMessageEntity *)locationMessageEntityFromGroupBox:(GroupLocationMessage *)boxMsg {
    LocationMessageEntity *message = [self createLocationMessageEntityFromBox:boxMsg];
    message.latitude = [NSNumber numberWithDouble:boxMsg.latitude];
    message.longitude = [NSNumber numberWithDouble:boxMsg.longitude];
    message.accuracy = [NSNumber numberWithDouble:boxMsg.accuracy];
    message.poiName = boxMsg.poiName;
    message.poiAddress = boxMsg.poiAddress;
    
    return message;
}

- (BallotMessageEntity *)ballotMessageFromBox:(AbstractMessage *)boxMsg {
    BallotMessageEntity *message = (BallotMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"BallotMessage"];
    
    return message;
}

- (FileMessageEntity *)fileMessageEntityFromBox:(AbstractMessage *)boxMsg {
    FileMessageEntity *message = (FileMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"FileMessage"];
    
    return message;
}

- (ImageDataEntity *)imageDataEntity {
    return (ImageDataEntity *)[self createEntityOfType: @"ImageData"];
}

- (VideoDataEntity *)videoDataEntity {
    return (VideoDataEntity *)[self createEntityOfType: @"VideoData"];
}

- (FileDataEntity *)fileDataEntity {
    return (FileDataEntity *)[self createEntityOfType: @"FileData"];
}

- (AudioDataEntity *)audioDataEntity{
    return (AudioDataEntity *)[self createEntityOfType: @"AudioData"];
}

- (TextMessageEntity *)textMessageEntityForConversationEntity:(ConversationEntity *)conversation setLastUpdate:(BOOL)setLastUpdate {
    BaseMessageEntity *message = [self createEntityOfType: @"TextMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    if (setLastUpdate) {
        conversation.lastUpdate = [NSDate date];
    }
    
    return (TextMessageEntity *)message;
}

- (ImageMessageEntity *)imageMessageEntityForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"ImageMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    conversation.lastUpdate = [NSDate date];
    
    return (ImageMessageEntity *)message;
}

- (VideoMessageEntity *)videoMessageEntityForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"VideoMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    conversation.lastUpdate = [NSDate date];
    
    return (VideoMessageEntity *)message;
}

- (FileMessageEntity *)fileMessageEntityForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"FileMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    conversation.lastUpdate = [NSDate date];
    
    return (FileMessageEntity *)message;
}

- (AudioMessageEntity *)audioMessageEntityForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"AudioMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    conversation.lastUpdate = [NSDate date];
    
    return (AudioMessageEntity *)message;
}

- (LocationMessageEntity *)locationMessageEntityForConversationEntity:(ConversationEntity *)conversation setLastUpdate:(BOOL)setLastUpdate {
    BaseMessageEntity *message = [self createEntityOfType: @"LocationMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    if (setLastUpdate) {
        conversation.lastUpdate = [NSDate date];
    }
    return (LocationMessageEntity *)message;
}

- (SystemMessageEntity *)systemMessageEntityForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"SystemMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    
    message.sent = [NSNumber numberWithBool:YES];
      
    return (SystemMessageEntity *)message;
}

- (BallotMessageEntity *)ballotMessageForConversationEntity:(ConversationEntity *)conversation {
    BaseMessageEntity *message = [self createEntityOfType: @"BallotMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    conversation.lastUpdate = [NSDate date];
    
    return (BallotMessageEntity *)message;
}

- (ContactEntity *)contact {    
    ContactEntity *contactEntity = [self createEntityOfType:@"Contact"];
    [self setupBasePropertiesForContact:contactEntity];
    return contactEntity;
}

- (LastGroupSyncRequestEntity *)lastGroupSyncRequestEntity {
    return (LastGroupSyncRequestEntity *)[self createEntityOfType: @"LastGroupSyncRequest"];
}

- (ConversationEntity *)conversationEntity {
    ConversationEntity *conversation = [self createEntityOfType: @"Conversation"];
    conversation.lastUpdate = [NSDate date];
    return conversation;
}

- (ConversationEntity *)conversationEntity:(BOOL)setLastUpdate {
    ConversationEntity *conversation = [self createEntityOfType: @"Conversation"];
    if (setLastUpdate) {
        conversation.lastUpdate = [NSDate date];
    }
    return conversation;
}

- (GroupEntity *)groupEntity {
    return (GroupEntity *)[self createEntityOfType: @"Group"];
}

- (BallotEntity *)ballot {
    return (BallotEntity *)[self createEntityOfType: @"Ballot"];
}

- (BallotChoiceEntity *)ballotChoice {
    BallotChoiceEntity *choice = [self createEntityOfType: @"BallotChoice"];
    choice.id = [NSNumber numberWithInt: arc4random()];
    choice.createDate = [NSDate date];
    
    return choice;
}

- (BallotResultEntity *)ballotResultEntity {
    BallotResultEntity *result = (BallotResultEntity *)[self createEntityOfType: @"BallotResult"];
    result.createDate = [NSDate date];
    
    return result;
}

- (NonceEntity *)nonceEntityWithData:(NSData *)nonce {
    NonceEntity *result = (NonceEntity *)[self createEntityOfType: @"Nonce"];
    result.nonce = nonce;
    
    return result;
}

- (MessageMarkersEntity *)messageMarkersEntity {
    MessageMarkersEntity *markers = (MessageMarkersEntity *)[self createEntityOfType:@"MessageMarkers"];
    return markers;
}

- (MessageHistoryEntryEntity *)messageHistoryEntryFor:(BaseMessageEntity *)message {
    MessageHistoryEntryEntity *historyEntry = (MessageHistoryEntryEntity *)[self createEntityOfType:@"MessageHistoryEntry"];
    historyEntry.message = message;
    
    if (message.isOwn) {
        if (message.lastEditedAt != nil) {
            historyEntry.editDate = message.lastEditedAt;
        }
        else {
            historyEntry.editDate = message.date;
        }
    }
    else {
        if (message.lastEditedAt != nil) {
            historyEntry.editDate = message.lastEditedAt;
        }
        else if (message.remoteSentDate != nil) {
            historyEntry.editDate = message.remoteSentDate;
        }
        else {
            historyEntry.editDate = message.date;
        }
    }
    
    return historyEntry;
}

- (WebClientSessionEntity *)webClientSessionEntity {
    return (WebClientSessionEntity *)[self createEntityOfType:@"WebClientSession"];
}

#pragma mark - private methods

- (TextMessageEntity *)createTextMessageEntityFromBox:(AbstractMessage *)boxMsg {
    return (TextMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"TextMessage"];
}

- (ImageMessageEntity *)createImageMessageEntityFromBox:(AbstractMessage *)boxMsg {
    return (ImageMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"ImageMessage"];
}

- (VideoMessageEntity *)createVideoMessageEntityFromBox:(AbstractMessage *)boxMsg {
    return (VideoMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"VideoMessage"];
}

- (AudioMessageEntity *)createAudioMessageEntityFromBox:(AbstractMessage *)boxMsg {
    return (AudioMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"AudioMessage"];
}

- (LocationMessageEntity *)createLocationMessageEntityFromBox:(AbstractMessage *)boxMsg {
    return (LocationMessageEntity *)[self createBaseMessageFromBox:boxMsg ofType:@"LocationMessage"];
}

- (BaseMessageEntity *)createBaseMessageFromBox:(AbstractMessage *)boxMsg ofType:(NSString *)typeName {
    BaseMessageEntity *message = [self createEntityOfType: typeName];
    
    [self setupBasePropertiesFor:message withValuesFrom:boxMsg];
    
    return message;
}

- (id)createEntityOfType:(NSString *)typeName {
    id object = [NSEntityDescription
                 insertNewObjectForEntityForName:typeName
                 inManagedObjectContext:_managedObjectContext];
    
    return object;
}

- (void)setupBasePropertiesForContact:(ContactEntity *)contactEntity {
    contactEntity.createdAt = [NSDate date];
}

- (void)setupBasePropertiesForNewMessage:(BaseMessageEntity *)message inConversation:(ConversationEntity *)conversation {
    message.id = [AbstractMessage randomMessageId];
    message.date = [NSDate date];
    message.isOwn = [NSNumber numberWithBool:YES];
    message.sent = [NSNumber numberWithBool:NO];
    message.delivered = [NSNumber numberWithBool:NO];
    message.read = [NSNumber numberWithBool:NO];
    message.userack = [NSNumber numberWithBool:NO];
    message.conversation = conversation;
}

- (void)setupBasePropertiesFor:(BaseMessageEntity *)dbMessage withValuesFrom:(AbstractMessage *)incomingMsg {
    dbMessage.id = incomingMsg.messageId;
    dbMessage.date = [NSDate date];
    dbMessage.isOwn = [NSNumber numberWithBool:NO];
    dbMessage.sent = [NSNumber numberWithBool:NO];
    dbMessage.delivered = [NSNumber numberWithBool:NO];
    dbMessage.read = [NSNumber numberWithBool:NO];
    dbMessage.userack = [NSNumber numberWithBool:NO];
    dbMessage.remoteSentDate = incomingMsg.date;
    dbMessage.flags = incomingMsg.flags;
    dbMessage.forwardSecurityMode = [NSNumber numberWithInt:(int)incomingMsg.forwardSecurityMode];
}

- (CallEntity *)callEntity {
    return (CallEntity *)[self createEntityOfType: @"Call"];
}

- (GroupCallEntity *)groupCallEntity {
    return (GroupCallEntity *)[self createEntityOfType: @"GroupCallEntity"];
}

- (DistributionListEntity*)distributionListEntity {
    return (DistributionListEntity *)[self createEntityOfType: @"DistributionList"];
}

- (MessageReactionEntity*)messageReactionEntity {
    return (MessageReactionEntity *)[self createEntityOfType: @"MessageReaction"];
}

@end
