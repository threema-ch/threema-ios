#import "Old_BlobMessageSender.h"
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

- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject {
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
            FileMessageEntity *message = (FileMessageEntity*)_messageObject;
            ConversationEntity *conversation = (ConversationEntity*)_conversationObject;

            EntityManager *entityManager = [[BusinessInjector ui] entityManager];
            if (message == nil) {
                @try {
                    [self createDBMessage];

                    message = (FileMessageEntity*)_messageObject;
                }
                @catch (NSException *exception) {
                    // if the external reference for the image/video/file cannot be fullfilled CoreData will throw a NSInternalInconsistencyException
                    [self uploadFailed];
                    return;
                }
            } else {
                [entityManager performSyncBlockAndSafe:^{
                    message.sendFailed = [NSNumber numberWithBool:NO];
                }];
            }

            if (message == nil) {
                DDLogError(@"BlobMessageSender: no message to send");
                [self didFinishUpload];
                return;
            }
            
            GroupManager *groupManager = [[[BusinessInjector alloc] initWithEntityManager:entityManager] groupManagerObjC];
            Group *group = [groupManager getGroupWithConversation:conversation];
            
            BlobOrigin origin = BlobOriginPublic;
            
            // Check if this is a note group
            if (group != nil && [group isNoteGroup]) {
                if (UserSettings.sharedUserSettings.enableMultiDevice == NO) {
                    DDLogWarn(@"BlobMessageSender: note group, no message to send");
                    [self noUploadNoteGroup];
                    return;
                } else {
                    DDLogInfo(@"BlobMessageSender: note group, upload blob to local endpoint");
                    origin = BlobOriginLocal;
                }
            }
            
            // Set persist param if this is sent to a group that is not a note group
            BOOL setPersistParam = group != nil && origin == BlobOriginPublic;
                        
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
            [_blobUploader uploadWithBlobs:blobs origin:origin setPersistParam:setPersistParam];
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
    FileMessageEntity *message = (FileMessageEntity*)_messageObject;

    if ([message wasDeleted]) {
        return YES;
    }
    
    if ([_uploadProgressDelegate blobMessageSenderUploadShouldCancel:self]) {
        return YES;
    }
    
    return NO;
}

- (void)uploadDidCancel {
    [self didFinishUpload];
    
    FileMessageEntity *message = (FileMessageEntity*)_messageObject;

    EntityManager *entityManager = [[BusinessInjector ui] entityManager];
    [entityManager performAsyncBlockAndSafe:^{
        ConversationEntity *conversation = message.conversation;
        conversation.lastMessage = nil;
        
        [[entityManager entityDestroyer] deleteWithBaseMessage:message];
        MessageFetcher *messageFetcher = [[MessageFetcher alloc] initFor:conversation with:entityManager];
        conversation.lastMessage = [messageFetcher lastDisplayMessage];
    }];
}


- (void)uploadSucceededWithBlobIds:(NSArray *)blobIds {
    [self didFinishUpload];
    
    __block BOOL wasDeleted = NO;
    FileMessageEntity *message = (FileMessageEntity*)_messageObject;

    EntityManager *entityManager = [[BusinessInjector ui] entityManager];
    [entityManager performAsyncBlockAndSafe:^{
        if ([message wasDeleted]) {
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
    [message addObserver:self forKeyPath:@"sent" options:0 context:nil];
    [message addObserver:self forKeyPath:@"sentEncrypted" options:0 context:nil];
}

- (void)uploadFailed {
    [self didFinishUpload];
    
    FileMessageEntity *message = (FileMessageEntity*)_messageObject;
    if ([message wasDeleted] == NO) {
        EntityManager *entityManager = [[BusinessInjector ui] entityManager];
        [entityManager performAsyncBlockAndSafe:^{
            message.sendFailed = [NSNumber numberWithBool:YES];
            message.blobProgress = nil;
        }];
    }
    
    [_uploadProgressDelegate blobMessageSender:self uploadFailedForMessage:message error:UploadErrorSendFailed];
}

- (void)noUploadNoteGroup {
    [self didFinishUpload];

    FileMessageEntity *message = (FileMessageEntity*)_messageObject;
    if ([message wasDeleted] == NO) {
        EntityManager *entityManager = [[BusinessInjector ui] entityManager];
        [entityManager performSyncBlockAndSafe:^{
            message.sent = [NSNumber numberWithBool:YES];
            message.blobProgress = nil;
        }];
    }
    [_uploadProgressDelegate blobMessageSender:self uploadSucceededForMessage:message];
}

- (void)uploadProgress:(NSNumber *)progress {
    FileMessageEntity *message = (FileMessageEntity*)_messageObject;

    if ([message wasDeleted]) {
        return;
    }
    
    EntityManager *entityManager = [[BusinessInjector ui] entityManager];
    [entityManager performSyncBlockAndSafe:^{
        message.blobProgress = progress;
    }];
    [_uploadProgressDelegate blobMessageSender:self uploadProgress:progress forMessage:message];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[BaseMessageEntity class]]) {
        @try {
            FileMessageEntity *message = (FileMessageEntity*)_messageObject;
            BaseMessageEntity *messageObject = (BaseMessageEntity *)object;
            
            if (messageObject.objectID == message.objectID) {
                [message removeObserver:self forKeyPath:@"sent"];
                message.blobProgress = nil;
                [_uploadProgressDelegate blobMessageSender:self uploadSucceededForMessage:message];
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into message");
        }
    }
}

@end
