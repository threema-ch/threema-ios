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

#import "Old_FileMessageSender.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NaClCrypto.h"
#import "BoxFileMessage.h"
#import "GroupFileMessage.h"
#import "FileMessageEncoder.h"
#import "MyIdentityStore.h"
#import "Contact.h"
#import "UTIConverter.h"
#import "BundleUtil.h"
#import "MediaConverter.h"

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
    EntityManager *em = [[EntityManager alloc] init];
    return [self init:[[TaskManager alloc] init] groupManager:[[GroupManager alloc] initWithEntityManager:em] entityManager:em];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(Conversation *)conversation {
    [self sendItem:item inConversation:conversation requestId:nil];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(Conversation *)conversation requestId:(NSString *)requestId {
    _item = item;
    self.conversation = conversation;
    _webRequestId = requestId;
    
    [self scheduleUpload];
}

- (void)sendItem:(URLSenderItem *)item inConversation:(Conversation *)conversation requestId:(NSString *)requestId correlationId:(NSString *)correlationId {
    _item = item;
    self.conversation = conversation;
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
        FileData *fileData = [entityManager.entityCreator fileData];
        fileData.data = data;
        
        Conversation *conversationOwnContext = (Conversation *)[entityManager.entityFetcher getManagedObjectById:self.conversation.objectID];
        
        FileMessageEntity *message = [entityManager.entityCreator fileMessageEntityForConversation:conversationOwnContext];
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
            message.duration = [[NSNumber alloc] initWithFloat:[_item getDuration]];
        }
        
        if ([message renderFileImageMessage]) {
            // add height and width
            message.height = [[NSNumber alloc] initWithFloat:[_item getHeight]];
            message.width = [[NSNumber alloc] initWithFloat:[_item getWidth]];
        }
        
        message.data = fileData;
        message.encryptionKey = encryptionKey;
        message.progress = @0; // Set progress 0 to indicate upload will be started
        message.sendFailed = [NSNumber numberWithBool:NO];
        message.webRequestId = _webRequestId;
        message.correlationId = _correlationId;
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

                ImageData *dbThumbnail = [entityManager.entityCreator imageData];
                dbThumbnail.data = thumbnailData;
                dbThumbnail.height = [NSNumber numberWithInt:thumbnailImage.size.height];
                dbThumbnail.width = [NSNumber numberWithInt:thumbnailImage.size.width];
                message.thumbnail = dbThumbnail;
        }
        
        message.caption = _item.caption;
        
        message.json = [FileMessageEncoder jsonStringForFileMessageEntity:message];

        self.message = message;
    }];
}

- (void)retryMessage:(FileMessageEntity *)message {
    self.message = message;
    self.conversation = message.conversation;
    
    [self scheduleUpload];
}

-(NSData *)encryptedData {
    FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.message;
    NSData *data = fileMessageEntity.data.data;
    NSData *encryptionKey = fileMessageEntity.encryptionKey;
    
    NSData *boxFileData = [[NaClCrypto sharedCrypto] symmetricEncryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    if (boxFileData == nil) {
        DDLogWarn(@"File encryption failed");
    }
    
    return boxFileData;
}

- (NSData *)encryptedThumbnailData {
    FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.message;
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
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)self.message;
        fileMessageEntity.blobId = blobIds[0];
        if ([blobIds count] > 1) {
            fileMessageEntity.blobThumbnailId = blobIds[1];
        }
        
        TaskDefinitionSendBaseMessage *task = [[TaskDefinitionSendBaseMessage alloc] initWithMessage:self.message group:[groupManager getGroupWithConversation:self.message.conversation] sendContactProfilePicture:YES];

        [taskManager addObjcWithTaskDefinition:task];
    }];
}

#pragma mark - Error translation

+ (NSString *)messageForError:(UploadError)error {
    NSString *errorMessage;
    switch (error) {
        case UploadErrorFileTooBig:
            errorMessage = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"error_message_file_too_big"], [FileUtility getFileSizeDescriptionFrom:kMaxFileSize]];
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
