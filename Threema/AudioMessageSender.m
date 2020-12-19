//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAsset.h>

#import "AudioMessageSender.h"
#import "AudioMessage.h"
#import "AudioData.h"
#import "Conversation.h"
#import "Contact.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "BoxAudioMessage.h"
#import "GroupAudioMessage.h"
#import "MessageQueue.h"
#import "EntityManager.h"
#import "ContactPhotoSender.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface AudioMessageSender ()

@property NSNumber *duration;
@property uint32_t boxDataLength;
@property NSData *encryptionKey;
@property NSData *audioData;
@property NSString *webRequestId;

@end

@implementation AudioMessageSender

- (void)sendItem:(URLSenderItem *)item inConversation:(Conversation *)conversation {
    [self startWithAudioFile:item.url inConversation:conversation requestId:nil];
}

- (void)startWithAudioFile:(NSURL *)audioUrl inConversation:(Conversation *)_conversation requestId:(NSString *)requestId {
    /* Find duration */
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:audioUrl options:nil];
    float durationF = CMTimeGetSeconds(asset.duration);
    NSNumber *duration = [NSNumber numberWithFloat:durationF];
    
    NSData *audioData = [[NSData alloc] initWithContentsOfURL:audioUrl];
    
    [self startWithAudioData:audioData duration:duration inConversation:_conversation requestId:requestId];
}

- (void)startWithAudioData:(NSData *)audioData duration:(NSNumber *)duration inConversation:(Conversation *)conversation requestId:(NSString *)requestId {
    
    self.conversation = conversation;
    _duration = duration;
    _audioData = audioData;
    _webRequestId = requestId;
    
    [self scheduleUpload];
}

- (void)retryWithAudioMessage:(AudioMessage*)message {
    self.message = message;
    self.conversation = message.conversation;
    _duration = message.duration;
    
    [self scheduleUpload];
}

- (void)createDBMessage {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        Conversation *conversationOwnContext = (Conversation *)[entityManager.entityFetcher getManagedObjectById:self.conversation.objectID];
        AudioMessage *message = [entityManager.entityCreator audioMessageForConversation:conversationOwnContext];
        AudioData *dbAudio = [entityManager.entityCreator audioData];
        dbAudio.data = _audioData;
        
        message.audio = dbAudio;
        message.duration = _duration;
        message.progress = nil;
        message.sendFailed = [NSNumber numberWithBool:NO];
        message.webRequestId = _webRequestId;
        
        self.message = message;
    }];
}

-(NSData *)encryptedData {
    /* Generate random symmetric key and encrypt */
    _encryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kBlobKeyLen];
    
    AudioMessage *message = (AudioMessage *)self.message;
    NSData *boxAudioData = [[NaClCrypto sharedCrypto] symmetricEncryptData:message.audio.data withKey:_encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    if (boxAudioData == nil) {
        DDLogWarn(@"Audio encryption failed");
    }
    
    _boxDataLength = (uint32_t)boxAudioData.length;
    
    return boxAudioData;
}

#pragma mark - BlobMessageSender

- (void)sendMessageTo:(Contact *)contact blobIds:(NSArray *)blobIds {
    BoxAudioMessage *boxMsg = [[BoxAudioMessage alloc] init];
    boxMsg.messageId = self.message.id;
    boxMsg.toIdentity = contact.identity;
    boxMsg.duration = _duration.floatValue;
    boxMsg.audioBlobId = blobIds[0];
    boxMsg.audioSize = _boxDataLength;
    boxMsg.encryptionKey = _encryptionKey;
    [[MessageQueue sharedMessageQueue] enqueue:boxMsg];
    [ContactPhotoSender sendProfilePicture:boxMsg];
}

-(void)sendGroupMessageTo:(Contact *)contact blobIds:(NSArray *)blobIds {
    GroupAudioMessage *msg = [[GroupAudioMessage alloc] init];
    msg.messageId = self.message.id;
    msg.date = self.message.date;
    msg.duration = _duration.floatValue;
    msg.audioBlobId = blobIds[0];
    msg.audioSize = _boxDataLength;
    msg.encryptionKey = _encryptionKey;
    msg.groupId = self.conversation.groupId;
    
    if (self.conversation.contact == nil) {
        msg.groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
    } else {
        msg.groupCreator = self.conversation.contact.identity;
    }
    
    msg.toIdentity = contact.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
    [ContactPhotoSender sendProfilePicture:msg];
}

@end
