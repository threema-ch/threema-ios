//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "GroupPhotoSender.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "GroupSetPhotoMessage.h"
#import "NSString+Hex.h"
#import "ActivityIndicatorProxy.h"
#import "GroupSetPhotoMessage.h"
#import "ThreemaError.h"
#import "ServerConnector.h"
#import "UserSettings.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation GroupPhotoSender {
    BOOL isNoteGroup;
    NSData *boxImageData;
    NSData *nonce;
    NSData *encryptionKey;
    NSMutableData *receivedData;
    NSURLConnection *uploadConnection;
    void(^onCompletion)(NSData *blobId, NSData *encryptionKey);
    void(^onError)(NSError *error);
}

- (void)startWithImageData:(NSData *)imageData isNoteGroup:(BOOL)isNoteGrp onCompletion:(void (^)(NSData *blobId, NSData *encryptionKey))_onCompletion onError:(void (^)(NSError *))_onError {
    
    self->isNoteGroup = isNoteGrp;
    onCompletion = _onCompletion;
    onError = _onError;
    
    if (imageData != nil) { // New image
        /* Generate random symmetric key and encrypt */
        encryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kBlobKeyLen];
        boxImageData = [[NaClCrypto sharedCrypto] symmetricEncryptData:imageData withKey:encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_1 length:sizeof(kNonce_1) freeWhenDone:NO]];
        
        [self startUpload];
    } else { // Image was removed
        onCompletion(nil, nil);
    }
}

- (void)startUpload {
    [ActivityIndicatorProxy startActivity];
    
    BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings]];
    Old_BlobUploader *uploader = [[Old_BlobUploader alloc] initWithBlobURL:blobUrl delegate:self];
    
    [uploader uploadWithBlobs:@[boxImageData] origin:isNoteGroup ? BlobOriginLocal : BlobOriginPublic setPersistParam: !isNoteGroup];
}

- (void)uploadCompletedWithBlobId:(NSData*)blobId {
    onCompletion(blobId, self->encryptionKey);
}

#pragma mark - BlobUploadDelegate

- (void)uploadSucceededWithBlobIds:(NSArray*)blobId {
    [ActivityIndicatorProxy stopActivity];
    
    DDLogVerbose(@"Blob ID: %@", blobId[0]);
    [self uploadCompletedWithBlobId:blobId[0]];
}

- (void)uploadFailed {
    DDLogError(@"Blob upload failed");

    [ActivityIndicatorProxy stopActivity];
    
    onError([ThreemaError threemaError:@"Blob upload failed"]);
}

- (void)uploadDidCancel { }

- (void)uploadProgress:(NSNumber *)progress { }

- (BOOL)uploadShouldCancel { 
    return NO;
}

@end
