#import <Foundation/Foundation.h>
#import "Old_BlobUploadDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@protocol GroupPhotoSenderProtocol <NSObject>

- (void)startWithImageData:(nullable NSData *)imageData isNoteGroup:(BOOL)isNoteGrp onCompletion:(void (^)(NSData * _Nullable blobId, NSData * _Nullable encryptionKey))onCompletion onError:(void (^)(NSError *))onError;

@end

@interface GroupPhotoSender : NSObject <GroupPhotoSenderProtocol, Old_BlobUploadDelegate>

@end

NS_ASSUME_NONNULL_END
