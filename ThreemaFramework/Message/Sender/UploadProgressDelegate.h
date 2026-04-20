#import <Foundation/Foundation.h>

typedef enum UploadError {
    UploadErrorSendFailed,
    UploadErrorFileTooBig,
    UploadErrorInvalidFile,
    UploadErrorCancelled
} UploadError;

@class Old_BlobMessageSender;

@protocol UploadProgressDelegate <NSObject>

- (BOOL)blobMessageSenderUploadShouldCancel:(nonnull Old_BlobMessageSender *)blobMessageSender;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param progress NSNumber
 @param messageObject Object of type `BaseMessageEntity`
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadProgress:(nonnull NSNumber *)progress forMessage:(nonnull NSObject *)messageObject;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param messageObject Object of type `BaseMessageEntity`
 @param error UploadError
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadFailedForMessage:(nullable NSObject *)messageObject error:(UploadError)error;

/**
 @param blobMessageSender Old_BlobMessageSender
 @param messageObject Object of type `BaseMessageEntity`
 */
- (void)blobMessageSender:(nonnull Old_BlobMessageSender *)blobMessageSender uploadSucceededForMessage:(nonnull NSObject *)messageObject;

@end
