//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import "FileMessageDecoder.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "EntityCreator.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ThreemaError.h"
#import "NaClCrypto.h"
#import "ServerConnector.h"
#import "UserSettings.h"
#import "ActivityIndicatorProxy.h"
#import "NonceHasher.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
typedef void (^CompletionBlock)(BaseMessage *message);
typedef void (^ErrorBlock)(NSError * _Nonnull);

@interface FileMessageDecoder ()

@property ConversationEntity *conversation;
@property ContactEntity *sender;
@property AbstractMessage *boxMessage;
@property NSDictionary *json;
@property NSData *jsonData;

@property (copy) CompletionBlock onCompletion;
@property (copy) ErrorBlock onError;

@end

@implementation FileMessageDecoder {
    BOOL isReflectedMessage;
    int timeoutDownloadThumbnail;
    EntityManager *entityManager;
}

+ (void)decodeMessageFromBox:(nonnull BoxFileMessage *)message sender:(nullable ContactEntity *)sender conversation:(nonnull ConversationEntity *)conversation isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError * _Nonnull))onError {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");

    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError sender:sender conversation:conversation timeoutDownloadThumbnail:timeout];

    decoder->isReflectedMessage = isReflected;
    decoder->entityManager = (EntityManager *)entityManagerObject;
    [decoder decodeMessageFromBox:message];
}

+ (void)decodeGroupMessageFromBox:(nonnull GroupFileMessage *)message sender:(nullable ContactEntity *)sender conversation:(nonnull ConversationEntity *)conversation isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError * _Nonnull))onError {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");

    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError sender:sender conversation:conversation timeoutDownloadThumbnail:timeout];
    
    decoder->isReflectedMessage = isReflected;
    decoder->entityManager = (EntityManager *)entityManagerObject;
    [decoder decodeGroupMessageFromBox:message];
}

+ (NSString *)decodeFilenameFromBox:(BoxFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_FILENAME];
}

+ (NSString *)decodeGroupFilenameFromBox:(GroupFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_FILENAME];
}

+ (NSString *)decodeFileCaptionFromBox:(BoxFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_DESCRIPTION];
}

+ (NSString *)decodeGroupFileCaptionFromBox:(GroupFileMessage *)message {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    if ([decoder prepareJson:message.jsonData] == NO) {
        return nil;
    }
    
    return [decoder.json objectForKey: JSON_FILE_KEY_DESCRIPTION];
}

#pragma mark - private

+ (instancetype)fileMessageDecoderOnCompletion:(void(^)(BaseMessage *message))onCompletion onError:(void(^)(NSError * _Nonnull))onError sender:(nullable ContactEntity *)sender conversation:(nonnull ConversationEntity *)conversation timeoutDownloadThumbnail:(int)timeoutDownloadThumbnail {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    decoder.onCompletion = onCompletion;
    decoder.onError = onError;

    decoder.sender = sender;
    decoder.conversation = conversation;
    decoder->timeoutDownloadThumbnail = timeoutDownloadThumbnail;

    return decoder;
}

- (void)decodeMessageFromBox:(BoxFileMessage *)message {
    if ([self prepareJson:message.jsonData] == NO) {
        return;
    }

    [self handleMessage:message];
}

- (void)decodeGroupMessageFromBox:(GroupFileMessage *)message {
    if ([self prepareJson:message.jsonData] == NO) {
        return;
    }
    
    [self handleMessage:message];
}

- (void)handleMessage:(AbstractMessage *)message {
    _boxMessage = message;

    [self createDBMessageWithCompletionInternal:^(FileMessageEntity *message) {
        [self fetchThumbnailForFileMessageEntity:message onCompletionInternal:^(FileMessageEntity * _Nonnull message) {
            _onCompletion(message);
        } onErrorInternal:_onError];
    } onErrorInternal:_onError];
}

- (BOOL)prepareJson:(NSData *)data {
    NSError *error;
    _json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (_json == nil) {
        DDLogError(@"Error parsing json %@, %@", error, [error userInfo]);
        if (_onError != nil) {
            _onError([ThreemaError threemaError:@"Error parsing file message json data"]);
        }
        return NO;
    }
    
    _jsonData = data;
    return YES;
}

- (void)fetchThumbnailForFileMessageEntity:(FileMessageEntity *)fileMessageEntity onCompletionInternal:(void(^ _Nonnull)(FileMessageEntity * _Nonnull)) onCompletionInternal  onErrorInternal:(void(^ _Nonnull)(NSError * _Nonnull))onErrorInternal {

    __block NSManagedObjectID *objectID;
    __block NSData *blobID;
    __block BlobOrigin blobOrigin;
    __block BlobOrigin blobOriginForDone = BlobOriginPublic;
    __block BOOL isNotGroupMessage;

    [entityManager performBlockAndWait:^{
        objectID = fileMessageEntity.objectID;
        blobID = fileMessageEntity.blobThumbnailId;
        blobOrigin = fileMessageEntity.blobOrigin;
        blobOriginForDone = BlobOriginPublic;
        isNotGroupMessage = fileMessageEntity.conversation.groupId == nil;

        if (isNotGroupMessage) {
            blobOriginForDone = fileMessageEntity.blobOrigin;
        }
        else if ([[UserSettings sharedUserSettings] enableMultiDevice]) {
            blobOriginForDone = BlobOriginLocal;
        }
    }];

    if (blobID) {
        [ActivityIndicatorProxy startActivity];

        dispatch_queue_t downloaderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings] queue:downloaderQueue];
        BlobDownloader *downloader = [[BlobDownloader alloc] initWithBlobURL:blobUrl queue:downloaderQueue];
        [downloader downloadWithBlobID:blobID origin:blobOrigin timeout:self->timeoutDownloadThumbnail completion:^(NSData *data, NSError *error) {
            if (data != nil && error == nil) {
                NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
                NSData *encryptionKey = [encryptionKeyHex decodeHex];

                /* Decrypt the box */
                NSData *decodedData = [[NaClCrypto sharedCrypto] safeSymmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
                if (decodedData == nil) {
                    DDLogError(@"Could not decode thumbnail data");
                }

                [self updateDBMessageWithThumbnail:decodedData objectID:objectID onCompletionInternal:^(FileMessageEntity * _Nonnull message) {
                    if (isNotGroupMessage) {
                        [downloader markDownloadDoneFor:blobID origin:blobOriginForDone];
                    }

                    onCompletionInternal(message);
                    [ActivityIndicatorProxy stopActivity];
                } onErrorInternal:onErrorInternal];
            }
            else {
                DDLogError(@"Could not download thumbnail for file message %@", error.localizedDescription);
                [self updateDBMessageWithThumbnail:nil objectID:objectID onCompletionInternal:^(FileMessageEntity * _Nonnull message) {
                    onCompletionInternal(message);
                    [ActivityIndicatorProxy stopActivity];
                } onErrorInternal:onErrorInternal];
            }
        }];
    } else {
        [self updateDBMessageWithThumbnail:nil objectID:objectID onCompletionInternal:^(FileMessageEntity * _Nonnull message) {
            onCompletionInternal(message);
        } onErrorInternal:onErrorInternal];
    }
}

- (void)createDBMessageWithCompletionInternal:(void(^ _Nonnull)(FileMessageEntity * _Nonnull))onCompletionInternal onErrorInternal:(void(^ _Nonnull)(NSError * _Nonnull))onErrorInternal{
    [entityManager getOrCreateMessageFor:_boxMessage sender:_sender conversation:_conversation thumbnail:nil onCompletion:^(BaseMessage *message) {
        __block FileMessageEntity *fileMessageEntity;

        [entityManager performSyncBlockAndSafe:^{
            fileMessageEntity = (FileMessageEntity*)message;

            GroupManager *groupManager = [[[BusinessInjector alloc] initWithEntityManager:entityManager] groupManagerObjC];
            Group *group = [groupManager getGroupWithConversation:_conversation];

            // Blob origin for download
            BOOL isOutgoingMessage = [_boxMessage.fromIdentity isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]];
            BOOL isLocalOrigin = (group && group.isNoteGroup) || (isReflectedMessage && isOutgoingMessage);
            fileMessageEntity.blobOrigin = isLocalOrigin ? BlobOriginLocal : BlobOriginPublic;

            NSString *blobHex = [_json objectForKey: JSON_FILE_KEY_FILE_BLOB];
            fileMessageEntity.blobId = [blobHex decodeHex];

            NSString *thumbnailBlobHex = [_json objectForKey: JSON_FILE_KEY_THUMBNAIL_BLOB];
            if (thumbnailBlobHex) {
                fileMessageEntity.blobThumbnailId = [thumbnailBlobHex decodeHex];
            }

            NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
            fileMessageEntity.encryptionKey = [encryptionKeyHex decodeHex];

            fileMessageEntity.mimeType = [_json objectForKey: JSON_FILE_KEY_MIMETYPE];

            fileMessageEntity.fileSize = [_json objectForKey: JSON_FILE_KEY_FILESIZE];

            NSNumber *type = [_json objectForKey: JSON_FILE_KEY_TYPE];
            if (type == nil) {
                type = [_json objectForKey: JSON_FILE_KEY_TYPE_DEPRECATED];
                if (type == nil) {
                    fileMessageEntity.type = @0;
                }
            } else {
                fileMessageEntity.type = type;
            }

            NSString *filename = [_json objectForKey: JSON_FILE_KEY_FILENAME];
            if (filename) {
                fileMessageEntity.fileName = filename;
            }

            NSString *caption = [_json objectForKey: JSON_FILE_KEY_DESCRIPTION];
            if (caption) {
                fileMessageEntity.caption = caption;
            }

            fileMessageEntity.json = [[NSString alloc] initWithData:_jsonData encoding:NSUTF8StringEncoding];
        }];

        onCompletionInternal(fileMessageEntity);
    } onError:onErrorInternal];
}

- (void)updateDBMessageWithThumbnail:(nullable NSData *)thumbnailData objectID:(nonnull NSManagedObjectID *)objectID onCompletionInternal:(void(^ _Nonnull)(FileMessageEntity * _Nonnull))onCompletionInternal onErrorInternal:(void(^ _Nonnull)(NSError * _Nonnull))onErrorInternal {

    __block FileMessageEntity *fileMessage;

    [entityManager performSyncBlockAndSafe:^{
        fileMessage = [[entityManager entityFetcher] existingObjectWithID:objectID];
        if (fileMessage == nil) {
            onErrorInternal([ThreemaError threemaError:@"Loading file message to update thumbnail failed"]);
            return;
        }

        if (fileMessage.thumbnail == nil && thumbnailData) {
            ImageDataEntity *thumbnail = [entityManager.entityCreator imageDataEntity];
            thumbnail.data = thumbnailData;

            // load image to determine size
            UIImage *thumbnailImage = [UIImage imageWithData:thumbnailData];
            thumbnail.width = thumbnailImage.size.width;
            thumbnail.height = thumbnailImage.size.height;

            fileMessage.thumbnail = thumbnail;
        }
    }];

    onCompletionInternal(fileMessage);
}

@end
