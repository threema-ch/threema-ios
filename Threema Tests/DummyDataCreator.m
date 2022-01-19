//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import <UIKit/UIKit.h>
#import "DummyDataCreator.h"

#import "EntityManager.h"
#import "TestObjectFactory.h"

@interface DummyDataCreator ()

@property EntityManager *entityManager;

@end

@implementation DummyDataCreator

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.entityManager = [[EntityManager alloc] init];
        self.doSave = NO;
    }
    return self;
}

- (Conversation *)getConversationForThreemaId:(NSString *)threemaId {
    Contact *contact = [_entityManager.entityFetcher contactForId:threemaId];
    if (contact == nil && [threemaId isEqualToString:@"ECHOECHO"]) {
        TestObjectFactory *factory = [TestObjectFactory testObjectFactory];
        contact = [factory contactWithIdentity:@"ECHOECHO" publicKey:[[NSData alloc] initWithBase64EncodedString:@"4a6a1b34 dcef15d4 3cb74de2 fd36091b e99fbbaf 126d099d 47d83d91 9712c72b" options:NSDataBase64DecodingIgnoreUnknownCharacters]];
    }
    NSAssert(contact != nil, @"contact not found");
    
    Conversation *conversation = [_entityManager conversationForContact:contact createIfNotExisting:YES];
    NSAssert(conversation != nil, @"conversation not found");
    
    return conversation;
}

- (void)createDummyMessages {
    
    Conversation *conversation = [self getConversationForThreemaId:@"ECHOECHO"];
    
    [self createDummyTextMessagesForConversation:conversation count:10000 messageFormat:@"dummy msg: %ld"];
    [self createDummyImageMessagesForConversation:conversation count:100];
    
    sleep(2);
}

- (TextMessage *)createTextMessageForConversation:(Conversation *)conversation text:(NSString *)text {
    TextMessage *msg = [_entityManager.entityCreator textMessageForConversation:conversation];
    
    msg.text = text;
    msg.conversation = conversation;
    conversation.lastMessage = msg;
    
    return msg;
}

- (NSArray *)createDummyTextMessagesForConversation:(Conversation *)conversation count:(NSInteger)count messageFormat:(NSString *)format {
    NSInteger saveCount = 0;
    
    NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i=0; i<count; i++) {
        NSString *text = [NSString stringWithFormat:format, (long)i];
        TextMessage *msg = [self createTextMessageForConversation:conversation text:text];

        [messages addObject:msg];
        
        if (saveCount == 1000) {
            saveCount = 1;
            if (_doSave) {
                [_entityManager performSyncBlockAndSafe:nil];
            }
            NSLog(@"added %ld of %ld", (long)i, (long)count);
        } else {
            saveCount++;
        }
    }
    
    if (_doSave) {
        [_entityManager performSyncBlockAndSafe:nil];
    }
    
    return messages;
}

- (NSArray *)createDummyImageMessagesForConversation:(Conversation *)conversation count:(NSInteger)count {
    NSInteger saveCount = 0;
    
    NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i=0; i<count; i++) {
        ImageMessage *msg = [self dummyImageMessageForConversation:conversation];
        [messages addObject:msg];
        conversation.lastMessage = msg;
        
        if (saveCount > 100) {
            saveCount = 0;
            if (_doSave) {
                [_entityManager performSyncBlockAndSafe:nil];
            }
        } else {
            saveCount++;
        }
    }
    
    if (_doSave) {
        [_entityManager performSyncBlockAndSafe:nil];
    }
    
    return messages;
}

- (ImageMessage *)dummyImageMessageForConversation:(Conversation *)conversation {
    NSArray *messages = [_entityManager.entityFetcher imageMessagesForConversation:conversation];
    if ([messages count] < 1) {
        return nil;
    }
    
    ImageMessage *templateMessage = [messages objectAtIndex:0];
    ImageMessage *imageMessage = [_entityManager.entityCreator imageMessageForConversation:conversation];
    imageMessage.image = [self cloneFrom:templateMessage.image];
    imageMessage.thumbnail = [self cloneFrom:templateMessage.thumbnail];
    imageMessage.imageBlobId = [templateMessage.imageBlobId copy];
    imageMessage.imageNonce = [templateMessage.imageNonce copy];
    imageMessage.imageSize = [templateMessage.imageSize copy];
    imageMessage.progress = [NSNumber numberWithFloat:1.0];
    
    imageMessage.sent = [NSNumber numberWithBool:YES];
    imageMessage.delivered = [NSNumber numberWithBool:YES];
    imageMessage.read = [NSNumber numberWithBool:YES];
    
    return imageMessage;
}

- (ImageData *)cloneFrom:(ImageData *)imageData {
    EntityManager *entityManager = [[EntityManager alloc] init];
    ImageData *newImage = [entityManager.entityCreator imageData];
    newImage.data = imageData.data;
    newImage.width = [NSNumber numberWithInt:imageData.uiImage.size.width];
    newImage.height = [NSNumber numberWithInt:imageData.uiImage.size.height];
    
    return newImage;
}
@end
