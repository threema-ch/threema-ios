//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "BlobMessageSender.h"
#import "Conversation.h"
#import "Contact.h"
#import "EntityManager.h"
#import "MessageFetcher.h"
#import "BlobUploader.h"

#define MAX_CONCURRENT_UPLOADS 1
#define TIMEOUT_INTERVAL_S 5

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
static dispatch_semaphore_t sema;
static NSMutableArray *scheduledUploads;
static dispatch_queue_t backgroundQueue;

@interface BlobMessageSender ()

@property BlobUploader *blobSender;

@end

@implementation BlobMessageSender

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sema = dispatch_semaphore_create(MAX_CONCURRENT_UPLOADS);
        scheduledUploads = [NSMutableArray array];
        backgroundQueue = dispatch_queue_create("ch.threema.blobSenderQueue", 0);
    });
}

#pragma mark - abstract methods

- (void)sendItem:(URLSenderItem *)item inConversation:(Conversation *)conversation {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
}

- (void)sendMessageTo:(Contact *)contact blobIds:(NSArray *)blobIds {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
}

- (void)sendGroupMessageTo:(Contact *)contact blobIds:(NSArray *)blobIds {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
}

- (void)prepareUpload {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
}

- (NSData *)encryptedData {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
    
    return nil;
}

- (NSData *)encryptedThumbnailData {
    // default implemenation has no thumbnail
    
    return nil;
}

- (void)createDBMessage {
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
}

- (BOOL)supportsCaption {
    return NO;
}

#pragma mark - private

- (void)scheduleUpload {
    
    // use background queue to avoid blocking of main queue
    dispatch_async(backgroundQueue, ^{
        [scheduledUploads addObject:self];

        while (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, TIMEOUT_INTERVAL_S * NSEC_PER_SEC)) != 0) {
            if ([_uploadProgressDelegate blobMessageSenderUploadShouldCancel:self]) {
                [self didFinishUpload];
                return;
            }
        }
        // do DB modifications & upload in main queue
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (self.message == nil) {
                @try {
                    [self createDBMessage];
                }
                @catch (NSException *exception) {
                    // if the external reference for the image/video/file cannot be fullfilled CoreData will throw a NSInternalInconsistencyException
                    [self uploadFailed];
                    return;
                }
            } else {
                EntityManager *entityManager = [[EntityManager alloc] init];
                [entityManager performSyncBlockAndSafe:^{
                    self.message.sendFailed = [NSNumber numberWithBool:NO];
                }];
            }

            if (self.message == nil) {
                DDLogError(@"BlobMessageSender: no message to send");
                [self didFinishUpload];
                return;
            }
            
            _blobSender = [[BlobUploader alloc] init];
            
            NSData *data = [self encryptedData];
            if (data == nil) {
                DDLogError(@"BlobMessageSender: no data to send");
                [self didFinishUpload];
                return;
            }
            
            _blobSender.data = data;
            _blobSender.thumbnailData = [self encryptedThumbnailData];
            
            [_blobSender startUploadFor:self];
        });
    });
}

- (void)didFinishUpload {
    dispatch_semaphore_signal(sema);
    [scheduledUploads removeObject:self];
}

#pragma mark - UploadProgressDelegate

- (BOOL)uploadShouldCancel {
    if ([_message wasDeleted]) {
        return YES;
    }
    
    if ([_uploadProgressDelegate blobMessageSenderUploadShouldCancel:self]) {
        return YES;
    }
    
    return NO;
}

- (void)uploadDidCancel {
    [self didFinishUpload];
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performAsyncBlockAndSafe:^{
        Conversation *conversation = _message.conversation;
        conversation.lastMessage = nil;
        
        [[entityManager entityDestroyer] deleteObjectWithObject:_message];
        
        MessageFetcher *messageFetcher = [MessageFetcher messageFetcherFor:conversation withEntityFetcher:entityManager.entityFetcher];
        conversation.lastMessage = [messageFetcher lastMessage];
    }];
}


- (void)uploadSucceededWithBlobIds:(NSArray *)blobIds {
    [self didFinishUpload];
    
    if ([_message wasDeleted]) {
        DDLogWarn(@"Blob message has been deleted!");
        return;
    }
    
    /* send actual message */
    Conversation *conversation = _message.conversation;
    if (conversation.groupId != nil) {
        /* send to each group member */
        for (Contact *member in conversation.members) {
            DDLogVerbose(@"Sending group blob message to %@", member.identity);
            [self sendGroupMessageTo:member blobIds:blobIds];
        }
    } else {
        DDLogVerbose(@"Sending  blob message to %@", conversation.contact);
        [self sendMessageTo:conversation.contact blobIds:blobIds];
    }
    
    // observer sent state in order to trigger [_uploadProgressDelegate uploadSucceededForMessage]
    [_message addObserver:self forKeyPath:@"sent" options:0 context:nil];
}

- (void)uploadFailed {
    [self didFinishUpload];
    
    if ([_message wasDeleted] == NO) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performAsyncBlockAndSafe:^{
            _message.sendFailed = [NSNumber numberWithBool:YES];
            [_message blobUpdateProgress:nil];
        }];
    }
    
    [_uploadProgressDelegate blobMessageSender:self uploadFailedForMessage:_message error:UploadErrorSendFailed];
}

- (void)uploadProgress:(NSNumber *)progress {
    if ([_message wasDeleted]) {
        return;
    }
    
    [_message blobUpdateProgress:progress];
    [_uploadProgressDelegate blobMessageSender:self uploadProgress:progress forMessage:_message];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _message) {
        [_message removeObserver:self forKeyPath:@"sent"];
        [_message blobUpdateProgress:nil];
        [_uploadProgressDelegate blobMessageSender:self uploadSucceededForMessage:_message];
    }
}

@end
