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

#import "FileMessageDecoder.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "FileMessage.h"
#import "EntityManager.h"
#import "PinnedHTTPSURLLoader.h"
#import "BlobUtil.h"
#import "ThreemaError.h"
#import "NaClCrypto.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
typedef void (^CompletionBlock)(BaseMessage *message);
typedef void (^ErrorBlock)(NSError *err);

@interface FileMessageDecoder ()

@property Conversation *conversation;
@property EntityManager *entityManager;
@property AbstractMessage *boxMessage;
@property NSDictionary *json;
@property NSData *jsonData;

@property (copy) CompletionBlock onCompletion;
@property (copy) ErrorBlock onError;

@end

@implementation FileMessageDecoder

+ (void)decodeMessageFromBox:(BoxFileMessage *)message forConversation:conversation onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError *))onError {
    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError conversation:conversation];
    
    [decoder decodeMessageFromBox:message];
}

+ (void)decodeGroupMessageFromBox:(GroupFileMessage *)message forConversation:conversation onCompletion:(void (^)(BaseMessage *))onCompletion onError:(void (^)(NSError *))onError {
    FileMessageDecoder *decoder = [FileMessageDecoder fileMessageDecoderOnCompletion:onCompletion onError:onError conversation:conversation];
    
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

+ (instancetype)fileMessageDecoderOnCompletion:(void(^)(BaseMessage *message))onCompletion  onError:(void(^)(NSError *err))onError conversation:(Conversation *)conversation {
    FileMessageDecoder *decoder = [[FileMessageDecoder alloc] init];
    decoder.onCompletion = onCompletion;
    decoder.onError = onError;
    
    decoder.entityManager = [[EntityManager alloc] init];
    
    decoder.conversation = conversation;
    
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
    
    FileMessage *fileMessage = [self createDBMessage];
    [self fetchThumbnail:fileMessage];
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

- (void)fetchThumbnail:(FileMessage *)fileMessage {
    NSString *thumbnailBlobHex = [_json objectForKey: JSON_FILE_KEY_THUMBNAIL_BLOB];
    if (thumbnailBlobHex) {
        NSData *thumbnailId = [thumbnailBlobHex decodeHex];
        
        NSURLRequest *request = [BlobUtil urlRequestForBlobId:thumbnailId];
    
        PinnedHTTPSURLLoader *thumbnailLoader = [[PinnedHTTPSURLLoader alloc] init];
        [thumbnailLoader startWithURLRequest:request onCompletion:^(NSData *data) {
            NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
            NSData *encryptionKey = [encryptionKeyHex decodeHex];
            
            /* Decrypt the box */
            NSData *decodedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
            if (decodedData == nil) {
                DDLogError(@"Could not decode thumbnail data");
            }
            
            [self updateDBMessageWithThumbnail:decodedData fileMessage:fileMessage error:nil];
        } onError:^(NSError *error) {
            [self updateDBMessageWithThumbnail:nil fileMessage:fileMessage error:error];
        }];
    } else {
        [self updateDBMessageWithThumbnail:nil fileMessage:fileMessage error:nil];
    }
}

- (FileMessage *)createDBMessage {
    __block FileMessage *fileMessage;
    
    [_entityManager performSyncBlockAndSafe:^{
        fileMessage = [_entityManager.entityCreator fileMessageFromBox:_boxMessage];
        fileMessage.conversation = _conversation;
        
        NSString *blobHex = [_json objectForKey: JSON_FILE_KEY_FILE_BLOB];
        fileMessage.blobId = [blobHex decodeHex];
        
        NSString *thumbnailBlobHex = [_json objectForKey: JSON_FILE_KEY_THUMBNAIL_BLOB];
        if (thumbnailBlobHex) {
            fileMessage.blobThumbnailId = [thumbnailBlobHex decodeHex];
        }
        
        NSString *encryptionKeyHex = [_json objectForKey: JSON_FILE_KEY_ENCRYPTION_KEY];
        fileMessage.encryptionKey = [encryptionKeyHex decodeHex];
        
        fileMessage.mimeType = [_json objectForKey: JSON_FILE_KEY_MIMETYPE];
        
        fileMessage.fileSize = [_json objectForKey: JSON_FILE_KEY_FILESIZE];
        
        NSNumber *type = [_json objectForKey: JSON_FILE_KEY_TYPE];
        if (type == nil) {
            type = [_json objectForKey: JSON_FILE_KEY_TYPE_DEPRECATED];
            if (type == nil) {
                fileMessage.type = @0;
            }
        } else {
            fileMessage.type = type;
        }
        
        NSString *filename = [_json objectForKey: JSON_FILE_KEY_FILENAME];
        if (filename) {
            fileMessage.fileName = filename;
        }
        
        NSString *caption = [_json objectForKey: JSON_FILE_KEY_DESCRIPTION];
        if (caption) {
            fileMessage.caption = caption;
        }
        
        fileMessage.json = [[NSString alloc] initWithData:_jsonData encoding:NSUTF8StringEncoding];
        
        /* Find contact for message */
        /* A FileMessage with sender != nil will be treated as a file message sent in a group*/
        if ([_boxMessage isKindOfClass:AbstractGroupMessage.class]) {
            fileMessage.sender = [_entityManager.entityFetcher contactForId: _boxMessage.fromIdentity];
        }
    }];
    
    return fileMessage;
}

- (void)updateDBMessageWithThumbnail:(NSData *)thumbnailData fileMessage:(FileMessage *)fileMessage error:(NSError *)error {
    __block FileMessage *tmpfileMessage = fileMessage;
    [_entityManager performSyncBlockAndSafe:^{
        if (thumbnailData) {
            ImageData *thumbnail = [_entityManager.entityCreator imageData];
            thumbnail.data = thumbnailData;
            
            // load image to determine size
            UIImage *thumbnailImage = [UIImage imageWithData:thumbnailData];
            thumbnail.width = [NSNumber numberWithInt:thumbnailImage.size.width];
            thumbnail.height = [NSNumber numberWithInt:thumbnailImage.size.height];
            
            tmpfileMessage.thumbnail = thumbnail;
        }
    }];
    
    if (error) {
        _onError(error);
    } else {
        _onCompletion(tmpfileMessage);
    }
}

@end
