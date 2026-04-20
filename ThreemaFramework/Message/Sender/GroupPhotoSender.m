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
