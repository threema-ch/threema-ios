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

#import "BlobMessageLoader.h"
#import "ProtocolDefines.h"
#import "NaClCrypto.h"
#import "MessageSender.h"
#import "EntityManager.h"
#import "ThreemaError.h"
#import "PinnedHTTPSURLLoader.h"
#import "Threema-Swift.h"
#import "UserSettings.h"
#import "MediaConverter.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface BlobMessageLoader () <HTTPSURLLoaderDelegate>

@end

@implementation BlobMessageLoader

- (void)startWithMessage:(BaseMessage<BlobData> *)message onCompletion:(void (^)(BaseMessage<BlobData> *loadedMessage))onCompletion onError:(void (^)(NSError *error))onError {

    _message = message;

    NSData *blobData = [_message blobGetData];
    if (blobData != nil) {
        onCompletion(message);
        return;
    }
    
    NSData *blobId = [_message blobGetId];
    if (blobId == nil) {
        DDLogWarn(@"Missing blob ID or encryption key!");
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"media_file_not_found"]]);
        return;
    }

    NSData *encryptionKey = [_message blobGetEncryptionKey];

    if (encryptionKey == nil) {
        // handle image message backward compatibility
        if ([message isKindOfClass:[ImageMessage class]]) {
            if (((ImageMessage *)message).imageNonce == nil) {
                DDLogWarn(@"Missing image encryption key or nonce!");
                return;
            }
        } else {
            DDLogWarn(@"Missing encryption key!");
            return;
        }
    }

    NSNumber *progress = [_message blobGetProgress];
    if (progress != nil) {
        DDLogWarn(@"Blob download already in progress");
        return;
    }

    _message = message;
    
    [_message blobUpdateProgress:[NSNumber numberWithFloat:0]];
    
    PinnedHTTPSURLLoader *loader = [[PinnedHTTPSURLLoader alloc] init];
    loader.delegate = self;
    
    [loader startWithBlobId:blobId  onCompletion:^(NSData *data) {
        
        if ([_message wasDeleted]) {
            return;
        }
        
        NSData *decryptedData = [self decryptData:data];
        if (decryptedData == nil) {
            onError([ThreemaError threemaError:@"Blob data decryption failed"]);
            return;
        }
        
        [self updateDBObjectWithData:decryptedData onCompletion:^{
            if (_message.conversation.groupId == nil) {
                [MessageSender markBlobAsDone:blobId];
            }
            
            DDLogInfo(@"Blob successfully downloaded (%lu bytes)", (unsigned long)data.length);
            
            onCompletion(_message);
        }];
    } onError:^(NSError *error) {
        [[ValidationLogger sharedValidationLogger] logString:error.description];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_message wasDeleted] == NO) {
                EntityManager *entityManager = [[EntityManager alloc] init];
                [entityManager performSyncBlockAndSafe:^{
                    _message.sendFailed = [NSNumber numberWithBool:YES];
                    [_message blobUpdateProgress:nil];
                }];
            }
        });
        
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"media_file_not_found"]]);
    }];
}


- (NSData *)decryptData:(NSData *)data {
    NSData *decryptedData = nil;
    
    @try {
        NSData *encryptionKey = [_message blobGetEncryptionKey];
        decryptedData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
    } @catch (NSException *exception) {
        DDLogError(@"Blob decryption failed: %@", [exception description]);
    }
    
    return decryptedData;
}

- (void)updateDBObjectWithData:(NSData *)data onCompletion:(void(^)(void))onCompletion {
    dispatch_async(dispatch_get_main_queue(), ^{
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            [_message blobSetData:data];
            
            _message.sendFailed = [NSNumber numberWithBool:NO];
            [_message blobUpdateProgress:nil];
        }];
        
        /* Add to photo library */
        if ([UserSettings sharedUserSettings].autoSaveMedia && [_message isKindOfClass:[FileMessage class]]) {
            FileMessage *fileMessage = (FileMessage *)_message;
            NSString *filename = [FileUtility getTemporaryFileName];
            __block NSURL *tmpFileUrl = [fileMessage tmpURL:filename];
            [fileMessage exportDataToURL:tmpFileUrl];
            
            BOOL isVideo = [UTIConverter isVideoMimeType:fileMessage.mimeType] || [UTIConverter isMovieMimeType:fileMessage.mimeType];
            BOOL isImage = [UTIConverter isImageMimeType:fileMessage.mimeType];
            BOOL isSticker = [fileMessage.type  isEqual: @2];
            if (isVideo == true || (isImage == true && isSticker == false)) {
                [[AlbumManager shared] saveWithUrl:tmpFileUrl isVideo:isVideo completionHandler:^(BOOL success) {
                    if (tmpFileUrl) {
                        [[NSFileManager defaultManager] removeItemAtURL:tmpFileUrl error:nil];
                        tmpFileUrl = nil;
                    }
                }];
            }
        }
        
        onCompletion();
    });
}

#pragma mark HTTPSURLLoaderDelegate

- (BOOL)httpsLoaderShouldCancel {
    if ([_message wasDeleted]) {
        return YES;
    }
    
    return NO;
}

- (void)httpsLoaderReceivedData:(NSData *)totalData {
    if ([_message wasDeleted]) {
        return;
    }

    [_message blobUpdateProgress:[NSNumber numberWithFloat:totalData.length / [_message blobGetSize].floatValue]];
}

@end
