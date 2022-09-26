//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "MessageForwarder.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "MessageSender.h"
#import "TextMessage.h"
#import "ImageMessageEntity.h"
#import "VideoMessageEntity.h"
#import "AudioMessageEntity.h"
#import "LocationMessage.h"
#import "FileMessageSender.h"
#import "UTIConverter.h"
#import <ThreemaFramework/ThreemaFramework-Swift.h>

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation MessageForwarder

+ (void)forwardMessage:(BaseMessage *)message toContact:(Contact *)contact
{
    EntityManager *entityManager = [[EntityManager alloc] init];
    Conversation *conversation = [entityManager conversationForContact:contact createIfNotExisting:YES];
    
    [self forwardMessage:message toConversation:conversation];
}

+ (void)forwardMessage:(BaseMessage *)message toGroup:(Group *)group
{

    EntityManager *entityManager = [[EntityManager alloc] init];
    Conversation *conversation = [[entityManager entityFetcher] conversationForGroupId:group.groupID creator:group.groupCreatorIdentity];

    [self forwardMessage:message toConversation:conversation];
}

+ (void)forwardMessage:(BaseMessage *)message toConversation:(Conversation *)conversation
{
    if (conversation == nil) {
        DDLogError(@"MessageForwarder: Cannot send message to nil conversation.");
        return;
    }
    
    if ([message isKindOfClass: [TextMessage class]]) {
        TextMessage *textMessage = (TextMessage *)message;
        [MessageSender sendMessage:textMessage.text inConversation:conversation quickReply:NO requestId:nil onCompletion:^(BaseMessage *message) {
            ;//nop
        }];
    } else if ([message isKindOfClass: [AudioMessageEntity class]]) {
        AudioMessageEntity *audioMessageEntity = (AudioMessageEntity *)message;
        NSData *data = [audioMessageEntity.audio.data copy];

        URLSenderItem *item = [URLSenderItem itemWithData:data
                                                 fileName:@"AudioMessage"
                                                     type:UTTYPE_AUDIO
                                               renderType:@1
                                               sendAsFile:true];

        FileMessageSender *sender = [[FileMessageSender alloc] init];
        [sender sendItem:item inConversation:conversation requestId:nil];
        
    } else if ([message isKindOfClass: [ImageMessageEntity class]]) {
        ImageMessageEntity *imageMessageEntity = (ImageMessageEntity *)message;
        ImageURLSenderItemCreator *imageSender = [[ImageURLSenderItemCreator alloc] init];
        URLSenderItem *item = [imageSender senderItemFromImage:imageMessageEntity.image.uiImage];

        FileMessageSender *sender = [[FileMessageSender alloc] init];
        [sender sendItem:item inConversation:conversation];
    } else if ([message isKindOfClass: [VideoMessageEntity class]]) {
        VideoMessageEntity *videoMessageEntity = (VideoMessageEntity *)message;
        
        VideoURLSenderItemCreator *senderCreator = [[VideoURLSenderItemCreator alloc] init];
        NSURL *videoURL = [VideoURLSenderItemCreator writeToTemporaryDirectoryWithData:videoMessageEntity.video.data];
        if (videoURL == nil) {
            DDLogError(@"VideoURL was nil.");
            return;
        }
        
        URLSenderItem *senderItem = [senderCreator senderItemFrom:videoURL];
        
        FileMessageSender *sender = [[FileMessageSender alloc] init];
        [sender sendItem:senderItem inConversation:conversation requestId:nil];
        (void)[VideoURLSenderItemCreator cleanTemporaryDirectory];
        
    } else if ([message isKindOfClass: [LocationMessage class]]) {
        LocationMessage *locationMessage = (LocationMessage *)message;
        
        CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake(locationMessage.latitude.doubleValue, locationMessage.longitude.doubleValue);
        double acurracy = locationMessage.accuracy.doubleValue;
        [MessageSender sendLocation:coordinates accuracy:acurracy poiName:locationMessage.poiName poiAddress:locationMessage.poiAddress inConversation:conversation onCompletion:^(NSData *messageId) {
            ;//nop
        }];
    }
}

@end
