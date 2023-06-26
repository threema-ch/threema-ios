//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "Old_BlobMessageSender.h"
#import "Conversation.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ServerConnector.h"
#import "UserSettings.h"

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

@interface Old_BlobMessageSender ()

@property Old_BlobUploader *blobUploader;

@end

@implementation Old_BlobMessageSender

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

- (void)sendMessage:(NSArray *)blobIds {
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
    // default implementation has no thumbnail
    
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
            EntityManager *entityManager = [[EntityManager alloc] init];
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
                [entityManager performSyncBlockAndSafe:^{
                    self.message.sendFailed = [NSNumber numberWithBool:NO];
                }];
            }

            if (self.message == nil) {
                DDLogError(@"BlobMessageSender: no message to send");
                [self didFinishUpload];
                return;
            }
            
            GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
            Group *group = [groupManager getGroupWithConversation:self.conversation];
            
            BlobOrigin origin = BlobOriginPublic;
            
            // Check if this is a note group
            if (group != nil && [group isNoteGroup]) {
                if (ServerConnector.sharedServerConnector.isMultiDeviceActivated == NO) {
                    DDLogWarn(@"BlobMessageSender: note group, no message to send");
                    [self noUploadNoteGroup];
                    return;
                } else {
                    DDLogInfo(@"BlobMessageSender: note group, upload blob to local endpoint");
                    origin = BlobOriginLocal;
                }
            }
                        
            NSData *data = [self encryptedData];
            if (data == nil) {
                DDLogError(@"BlobMessageSender: no data to send");
                [self didFinishUpload];
                return;
            }
            
            NSMutableArray *blobs = [[NSMutableArray alloc] initWithObjects:data, nil];

            NSData *thumbnailData = [self encryptedThumbnailData];
            if (thumbnailData != nil) {
                [blobs addObject:thumbnailData];
            }

            BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings]];
            _blobUploader = [[Old_BlobUploader alloc] initWithBlobURL:blobUrl delegate:self];
            [_blobUploader uploadWithBlobs:blobs origin:origin];
        });
    });
}

+ (BOOL)hasScheduledUploads {
    return [scheduledUploads count] > 0;
}

- (void)didFinishUpload {
    dispatch_semaphore_signal(sema);
    [scheduledUploads removeObject:self];
}

#pragma mark - BlobUploadDelegate

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
        
        MessageFetcher *messageFetcher = [[MessageFetcher alloc] initFor:conversation with:entityManager];
        conversation.lastMessage = [messageFetcher lastMessage];        
    }];
}


- (void)uploadSucceededWithBlobIds:(NSArray *)blobIds {
    [self didFinishUpload];
    
    __block BOOL wasDeleted = NO;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performAsyncBlockAndSafe:^{
        if ([_message wasDeleted]) {
            DDLogWarn(@"Blob message has been deleted!");
            wasDeleted = YES;
        }
    }];
    
    if (wasDeleted) {
        return;
    }
    
    /* send actual message */
    [self sendMessage:blobIds];
    
    // observer sent state in order to trigger [_uploadProgressDelegate uploadSucceededForMessage]
    [_message addObserver:self forKeyPath:@"sent" options:0 context:nil];
}

- (void)uploadFailed {
    [self didFinishUpload];
    
    if ([_message wasDeleted] == NO) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performAsyncBlockAndSafe:^{
            _message.sendFailed = [NSNumber numberWithBool:YES];
            _message.blobProgress = nil;
        }];
    }
    
    [_uploadProgressDelegate blobMessageSender:self uploadFailedForMessage:_message error:UploadErrorSendFailed];
}

- (void)noUploadNoteGroup {
    [self didFinishUpload];
    
    if ([_message wasDeleted] == NO) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            _message.sent = [NSNumber numberWithBool:YES];
            _message.blobProgress = nil;
        }];
    }
    [_uploadProgressDelegate blobMessageSender:self uploadSucceededForMessage:_message];
}

- (void)uploadProgress:(NSNumber *)progress {
    if ([_message wasDeleted]) {
        return;
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        _message.blobProgress = progress;
    }];
    [_uploadProgressDelegate blobMessageSender:self uploadProgress:progress forMessage:_message];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[BaseMessage class]]) {
        @try {
            BaseMessage *messageObject = (BaseMessage *)object;
            
            if (messageObject.objectID == self.message.objectID) {
                [_message removeObserver:self forKeyPath:@"sent"];
                _message.blobProgress = nil;
                [_uploadProgressDelegate blobMessageSender:self uploadSucceededForMessage:_message];
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into message");
        }
    }
}

@end
