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

#import "EntityCreator.h"
#import "Conversation.h"
#import "ErrorHandler.h"
#import "DatabaseManager.h"

@interface EntityCreator ()

@property NSManagedObjectContext *managedObjectContext;

@end

@implementation EntityCreator

/*
- (instancetype)init
{
    self = [super init];
    if (self) {
        _managedObjectContext = [[DatabaseManager dbManager] getManagedObjectContext:![NSThread isMainThread]];
    }
    return self;
}
*/

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext
{
    self = [super init];
    if (self) {
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (TextMessage *)textMessageFromGroupBox:(GroupTextMessage *)boxMsg {
    TextMessage *message = [self createTextMessageFromBox: boxMsg];
    message.text = boxMsg.text;
    message.quotedMessageId = boxMsg.quotedMessageId;
    
    return message;
}

- (TextMessage *)textMessageFromBox:(BoxTextMessage *)boxMsg {
    TextMessage *message = [self createTextMessageFromBox: boxMsg];
    message.text = boxMsg.text;
    message.quotedMessageId = boxMsg.quotedMessageId;
    
    return message;
}

- (ImageMessage *)imageMessageFromBox:(BoxImageMessage *)boxMsg {
    ImageMessage *message = [self createImageMessageFromBox: boxMsg];
    message.imageSize = [NSNumber numberWithInt:boxMsg.size];
    message.imageBlobId = boxMsg.blobId;
    message.imageNonce = boxMsg.imageNonce;
    
    return message;
}

- (ImageMessage *)imageMessageFromGroupBox:(GroupImageMessage *)boxMsg {
    ImageMessage *message = [self createImageMessageFromBox: boxMsg];
    message.imageSize = [NSNumber numberWithInt:boxMsg.size];
    message.imageBlobId = boxMsg.blobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (VideoMessage *)videoMessageFromBox:(BoxVideoMessage *)boxMsg {
    VideoMessage *message = [self createVideoMessageFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.videoSize = [NSNumber numberWithInt:boxMsg.videoSize];
    message.videoBlobId = boxMsg.videoBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (VideoMessage *)videoMessageFromGroupBox:(GroupVideoMessage *)boxMsg {
    VideoMessage *message = [self createVideoMessageFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.videoSize = [NSNumber numberWithInt:boxMsg.videoSize];
    message.videoBlobId = boxMsg.videoBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (AudioMessage *)audioMessageFromBox:(BoxAudioMessage *)boxMsg {
    AudioMessage *message = [self createAudioMessageFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.audioSize = [NSNumber numberWithInt:boxMsg.audioSize];
    message.audioBlobId = boxMsg.audioBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    return message;
}

- (AudioMessage *)audioMessageFromGroupBox:(GroupAudioMessage *)boxMsg {
    AudioMessage *message = [self createAudioMessageFromBox: boxMsg];
    message.duration = [NSNumber numberWithInt:boxMsg.duration];
    message.audioSize = [NSNumber numberWithInt:boxMsg.audioSize];
    message.audioBlobId = boxMsg.audioBlobId;
    message.encryptionKey = boxMsg.encryptionKey;
    
    return message;
}

- (LocationMessage *)locationMessageFromBox:(BoxLocationMessage *)boxMsg {
    LocationMessage *message = [self createLocationMessageFromBox:boxMsg];
    message.latitude = [NSNumber numberWithDouble:boxMsg.latitude];
    message.longitude = [NSNumber numberWithDouble:boxMsg.longitude];
    message.accuracy = [NSNumber numberWithDouble:boxMsg.accuracy];
    message.poiName = boxMsg.poiName;
    if (boxMsg.poiAddress != nil) {
        message.poiName = [message.poiName stringByAppendingFormat:@"\n%@", boxMsg.poiAddress];
    }
    
    return message;
}

- (LocationMessage *)locationMessageFromGroupBox:(GroupLocationMessage *)boxMsg {
    LocationMessage *message = [self createLocationMessageFromBox:boxMsg];
    message.latitude = [NSNumber numberWithDouble:boxMsg.latitude];
    message.longitude = [NSNumber numberWithDouble:boxMsg.longitude];
    message.accuracy = [NSNumber numberWithDouble:boxMsg.accuracy];
    message.poiName = boxMsg.poiName;
    if (boxMsg.poiAddress != nil) {
        message.poiName = [message.poiName stringByAppendingFormat:@"\n%@", boxMsg.poiAddress];
    }
    
    return message;
}

- (BallotMessage *)ballotMessageFromBox:(AbstractMessage *)boxMsg {
    BallotMessage *message = (BallotMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"BallotMessage"];
    
    return message;
}

- (FileMessage *)fileMessageFromBox:(AbstractMessage *)boxMsg {
    FileMessage *message = (FileMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"FileMessage"];
    
    return message;
}

- (ImageData *)imageData {
    return (ImageData *)[self createEntityOfType: @"ImageData"];
}

- (VideoData *)videoData {
    return (VideoData *)[self createEntityOfType: @"VideoData"];
}

- (FileData *)fileData {
    return (FileData *)[self createEntityOfType: @"FileData"];
}

- (AudioData *)audioData {
    return (AudioData *)[self createEntityOfType: @"AudioData"];
}

- (TextMessage *)textMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"TextMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (TextMessage *)message;
}

- (ImageMessage *)imageMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"ImageMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (ImageMessage *)message;
}

- (VideoMessage *)videoMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"VideoMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (VideoMessage *)message;
}

- (FileMessage *)fileMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"FileMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (FileMessage *)message;
}

- (AudioMessage *)audioMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"AudioMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (AudioMessage *)message;
}

- (LocationMessage *)locationMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"LocationMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (LocationMessage *)message;
}

- (SystemMessage *)systemMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"SystemMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    
    message.sent = [NSNumber numberWithBool:YES];
    
    return (SystemMessage *)message;
}

- (BallotMessage *)ballotMessageForConversation:(Conversation *)conversation {
    BaseMessage *message = [self createEntityOfType: @"BallotMessage"];
    [self setupBasePropertiesForNewMessage: message inConversation: conversation];
    conversation.lastMessage = message;
    
    return (BallotMessage *)message;
}

- (Contact *)contact {
    return (Contact *)[self createEntityOfType: @"Contact"];
}

- (LastGroupSyncRequest *)lastGroupSyncRequest {
    return (LastGroupSyncRequest *)[self createEntityOfType: @"LastGroupSyncRequest"];
}

- (Conversation *)conversation {
    return (Conversation *)[self createEntityOfType: @"Conversation"];
}

- (Group *)group {
    return (Group *)[self createEntityOfType: @"Group"];
}

- (Ballot *)ballot {
    return (Ballot *)[self createEntityOfType: @"Ballot"];
}

- (BallotChoice *)ballotChoice {
    BallotChoice *choice = [self createEntityOfType: @"BallotChoice"];
    choice.id = [NSNumber numberWithInt: arc4random()];
    choice.createDate = [NSDate date];
    
    return choice;
}

- (BallotResult *)ballotResult {
    BallotResult *result = (BallotResult *)[self createEntityOfType: @"BallotResult"];
    result.createDate = [NSDate date];
    
    return result;
}

- (Nonce *)nonceWithData:(NSData *)nonce {
    Nonce *result = (Nonce *)[self createEntityOfType: @"Nonce"];
    result.nonce = nonce;
    
    return result;
}

- (Tag *)tagWithName:(NSString *)name {
    Tag *tag = (Tag *)[self createEntityOfType:@"Tag"];
    tag.name = name;
    
    return tag;
}

- (WebClientSession *)webClientSession {
    return (WebClientSession *)[self createEntityOfType:@"WebClientSession"];
}

- (RequestedConversation *)requestedConversationWithId:(NSString *)conversationId webClientSession:(WebClientSession*)webClientSession {
    RequestedConversation *requestedConversation = (RequestedConversation *)[self createEntityOfType:@"RequestedConversation"];
    requestedConversation.conversationId = conversationId;
    requestedConversation.webClientSession = webClientSession;
    return requestedConversation;
}

- (LastLoadedMessageIndex *)lastLoadedMessageIndexWithBaseMessageId:(NSData *)baseMessageId index:(NSInteger)index webClientSession:(WebClientSession*)webClientSession {
    LastLoadedMessageIndex *lastLoadedMessageIndex = (LastLoadedMessageIndex *)[self createEntityOfType:@"LastLoadedMessageIndex"];
    lastLoadedMessageIndex.baseMessageId = baseMessageId;
    lastLoadedMessageIndex.index = [NSNumber numberWithInteger:index];
    lastLoadedMessageIndex.webClientSession = webClientSession;
    return lastLoadedMessageIndex;
}

- (RequestedThumbnail *)requestedThumbnailWithMessageId:(NSData *)messageId webClientSession:(WebClientSession*)webClientSession {
    RequestedThumbnail *requestedThumbnail = (RequestedThumbnail *)[self createEntityOfType:@"RequestedThumbnail"];
    requestedThumbnail.messageId = messageId;
    requestedThumbnail.webClientSession = webClientSession;
    return requestedThumbnail;
}

#pragma mark - private methods

- (TextMessage *)createTextMessageFromBox:(AbstractMessage *)boxMsg {
    return (TextMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"TextMessage"];
}

- (ImageMessage *)createImageMessageFromBox:(AbstractMessage *)boxMsg {
    return (ImageMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"ImageMessage"];
}

- (VideoMessage *)createVideoMessageFromBox:(AbstractMessage *)boxMsg {
    return (VideoMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"VideoMessage"];
}

- (AudioMessage *)createAudioMessageFromBox:(AbstractMessage *)boxMsg {
    return (AudioMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"AudioMessage"];
}

- (LocationMessage *)createLocationMessageFromBox:(AbstractMessage *)boxMsg {
    return (LocationMessage *)[self createBaseMessageFromBox:boxMsg ofType:@"LocationMessage"];
}

- (BaseMessage *)createBaseMessageFromBox:(AbstractMessage *)boxMsg ofType:(NSString *)typeName {
    BaseMessage *message = [self createEntityOfType: typeName];
    
    [self setupBasePropertiesFor:message withValuesFrom:boxMsg];
    
    return message;
}

- (id)createEntityOfType:(NSString *)typeName {
    id object = [NSEntityDescription
                 insertNewObjectForEntityForName:typeName
                 inManagedObjectContext:_managedObjectContext];
    
    return object;
}

- (void)setupBasePropertiesForNewMessage:(BaseMessage *)message inConversation:(Conversation *)conversation {
    message.id = [AbstractMessage randomMessageId];
    message.date = [NSDate date];
    message.isOwn = [NSNumber numberWithBool:YES];
    message.sent = [NSNumber numberWithBool:NO];
    message.delivered = [NSNumber numberWithBool:NO];
    message.read = [NSNumber numberWithBool:NO];
    message.userack = [NSNumber numberWithBool:NO];
    message.conversation = conversation;
}

- (void)setupBasePropertiesFor:(BaseMessage *)dbMessage withValuesFrom:(AbstractMessage *)incomingMsg {
    dbMessage.id = incomingMsg.messageId;
    dbMessage.date = [NSDate date];
    dbMessage.isOwn = [NSNumber numberWithBool:NO];
    dbMessage.sent = [NSNumber numberWithBool:NO];
    dbMessage.delivered = [NSNumber numberWithBool:NO];
    dbMessage.read = [NSNumber numberWithBool:NO];
    dbMessage.userack = [NSNumber numberWithBool:NO];
    dbMessage.remoteSentDate = incomingMsg.date;
    dbMessage.flags = incomingMsg.flags;
}

@end
