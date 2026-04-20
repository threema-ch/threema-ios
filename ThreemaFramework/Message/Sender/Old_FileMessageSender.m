#import "Old_FileMessageSender.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NaClCrypto.h"
#import "BoxFileMessage.h"
#import "GroupFileMessage.h"
#import "FileMessageEncoder.h"
#import "MyIdentityStore.h"
#import "BundleUtil.h"
#import "MediaConverter.h"
@import FileUtility;

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface Old_FileMessageSender ()

@property URLSenderItem *item;
@property NSString *webRequestId;
@property NSString *correlationId;

@end

@implementation Old_FileMessageSender {
    TaskManager *taskManager;
    GroupManager *groupManager;
    EntityManager *entityManager;
}

- (instancetype)init:(TaskManager *)tm groupManager:(GroupManager *)gm entityManager:(EntityManager *)em
{
    self = [super init];
    if (self) {
        self->taskManager = tm;
        self->groupManager = gm;
        self->entityManager = em;
    }
    return self;
}

- (instancetype)init
{
    EntityManager *em = [[BusinessInjector ui] entityManager];
    TaskManager *tm = [TaskManager new];
    return [self init:tm groupManager:[[GroupManager alloc] initWithEntityManager:em taskManagerObjc:tm] entityManager:em];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject {
    NSAssert(conversationObject == nil || [conversationObject isKindOfClass:[ConversationEntity class]], @"Parameter conversationObject must be type of ConversationEntity");

    [self sendItem:item inConversation:conversationObject requestId:nil];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject requestId:(NSString *)requestId {
    NSAssert(conversationObject == nil || [conversationObject isKindOfClass:[ConversationEntity class]], @"Parameter conversationObject must be type of ConversationEntity");

    _item = item;
    self.conversationObject = conversationObject;
    _webRequestId = requestId;
    
    [self scheduleUpload];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject requestId:(NSString *)requestId correlationId:(NSString *)correlationId {
    NSAssert(conversationObject == nil || [conversationObject isKindOfClass:[ConversationEntity class]], @"Parameter conversationObject must be type of ConversationEntity");

    _item = item;
    self.conversationObject = conversationObject;
    _webRequestId = requestId;
    self.correlationId = correlationId;

    [self scheduleUpload];
}

- (NSData *)prepareDataFor:(URLSenderItem *)item {
    NSData *data = [item getData];
    
    if (data == nil) {
        DDLogError(@"Cannot read data from %@", item);
        [self.uploadProgressDelegate blobMessageSender:self uploadFailedForMessage:nil error:UploadErrorInvalidFile];
        
        return nil;
    }
    
    if ([data length] > kMaxFileSize) {
        DDLogError(@"File to big %@, size: %lul", item, (unsigned long)[data length]);
        [self.uploadProgressDelegate blobMessageSender:self uploadFailedForMessage:nil error:UploadErrorFileTooBig];
        
        return nil;
    }
    
    return data;
}

- (BOOL)supportsCaption {
    return YES;
}

- (void)createDBMessage {
    NSData *data = [self prepareDataFor:_item];
    if (data == nil) {
        return;
    }

    UIImage *thumbnailImage = [_item getThumbnail];
    
    NSData *encryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kBlobKeyLen];

    [entityManager performSyncBlockAndSafe:^{
        FileDataEntity *fileData = [entityManager.entityCreator fileDataEntityWithData:data message:nil];

        ConversationEntity *conversation = (ConversationEntity*)self.conversationObject;
        ConversationEntity *conversationOwnContext = (ConversationEntity *)[entityManager.entityFetcher managedObjectWith:conversation.objectID];
        
        FileMessageEntity *message = [entityManager.entityCreator fileMessageEntityIn:conversationOwnContext setLastUpdate:YES];
        message.fileSize = [NSNumber numberWithInteger:data.length];
        if (self.fileNameFromWeb != nil) {
            message.fileName = self.fileNameFromWeb;
        } else {
            message.fileName = [_item getName];
        }
        
        message.mimeType = [_item getMimeType];
        
        if (_item.renderType == nil) {
            message.type = @0;
        } else {
            message.type = _item.renderType;
        }
        
        if (_item.sendAsFile == false && [_item.renderType isEqual:@0]) {
            if ([message sendAsFileImageMessage] == true || [message sendAsFileVideoMessage] == true || [message sendAsFileAudioMessage] == true) {
                message.type = [NSNumber numberWithInt:1];
            }
            else if ([message sendAsFileGifMessage] == true) {
                message.type = [NSNumber numberWithInt:2];
            }
        }
        
        if ([message sendAsFileVideoMessage] || [message sendAsFileAudioMessage]) {
            // add duration
            message.durationObjc = [[NSNumber alloc] initWithFloat:[_item getDuration]];
        }
        
        if ([message renderFileImageMessage]) {
            // add height and width
            message.heightObjc = [[NSNumber alloc] initWithFloat:[_item getHeight]];
            message.widthObjc = [[NSNumber alloc] initWithFloat:[_item getWidth]];
        }
        
        message.data = fileData;
        message.encryptionKey = encryptionKey;
        message.progress = @0; // Set progress 0 to indicate upload will be started
        message.sendFailed = [NSNumber numberWithBool:NO];
        message.webRequestId = _webRequestId;
        message.correlationID = _correlationId;
        if (thumbnailImage) {
            NSData *thumbnailData = nil;
            if ([UTIConverter isPNGImageMimeType:message.mimeType]) {
                thumbnailData = UIImagePNGRepresentation(thumbnailImage);
                message.mimeTypeThumbnail = message.mimeType;
            } else {
                // UIImageJPEGRepresentation caused a memory leak. The exact cause for the leak is unknown.
                // For more information see: IOS-1576
                thumbnailData = [MediaConverter JPEGRepresentationFor:thumbnailImage];
            }

            if (thumbnailData) {
                ImageDataEntity *dbThumbnail = [entityManager.entityCreator imageDataEntityWithData:thumbnailData size:thumbnailImage.size message:nil];
                message.thumbnail = dbThumbnail;
            }
            else {
                DDLogError(@"Unable to create thumbnail data for item");
            }
        }
        
        message.caption = _item.caption;
        
        message.json = [FileMessageEncoder jsonStringForFileMessageEntity:message];

        self.messageObject = message;
    }];
}

- (void)retryMessage:(NSObject *)messageObject {
    NSAssert(messageObject == nil || [messageObject isKindOfClass:[FileMessageEntity class]], @"Parameter messageObject must be type of FileMessageEntity");

    self.messageObject = messageObject;
    self.conversationObject = ((FileMessageEntity*)messageObject).conversation;

    [self scheduleUpload];
}

-(NSData *)encryptedData {
    FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.messageObject;
    NSData *data = fileMessageEntity.data.data;
    NSData *encryptionKey = fileMessageEntity.encryptionKey;
    
    NSData *boxFileData = [[NaClCrypto sharedCrypto] symmetricEncryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    if (boxFileData == nil) {
        DDLogWarn(@"File encryption failed");
    }
    
    return boxFileData;
}

- (NSData *)encryptedThumbnailData {
    FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.messageObject;
    if (fileMessageEntity.thumbnail) {
        NSData *boxThumbnailData = [[NaClCrypto sharedCrypto] symmetricEncryptData:fileMessageEntity.thumbnail.data withKey:fileMessageEntity.encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
        if (boxThumbnailData == nil) {
            DDLogWarn(@"Thumbnail encryption failed");
        }
        
        return boxThumbnailData;
    }
    
    return nil;
}

#pragma mark - BlobMessageSender

- (void)sendMessage:(NSArray *)blobIds {
    [entityManager performSyncBlockAndSafe:^{
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.messageObject;
        fileMessageEntity.blobId = blobIds[0];
        if ([blobIds count] > 1) {
            fileMessageEntity.blobThumbnailId = blobIds[1];
        }

        NSString *receiverIdentity;
        Group *group = [groupManager getGroupWithConversation:fileMessageEntity.conversation];
        if (group == nil) {
            receiverIdentity = fileMessageEntity.conversation.contact.identity;
        }

        TaskDefinitionSendBaseMessage *task = [[TaskDefinitionSendBaseMessage alloc] initWithMessageID:fileMessageEntity.id receiverIdentity:receiverIdentity group:group sendContactProfilePicture:YES];
        [taskManager addObjcWithTaskDefinition:task];
    }];
}

#pragma mark - Error translation

+ (NSString *)messageForError:(UploadError)error {
    NSString *errorMessage;
    switch (error) {
        case UploadErrorFileTooBig:
            errorMessage = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"error_message_file_too_big"], [[FileUtility new] getFileSizeDescriptionFrom:kMaxFileSize]];
            break;
            
        case UploadErrorInvalidFile:
            errorMessage = [BundleUtil localizedStringForKey:@"error_message_invalid_file"];
            break;
            
        default:
            errorMessage = [BundleUtil localizedStringForKey:@"error_message_generic"];
            break;
    }
    
    return errorMessage;
}

@end
