#import <Foundation/Foundation.h>

@protocol Old_BlobUploadDelegate <NSObject>

- (BOOL) uploadShouldCancel;

- (void) uploadDidCancel;

- (void) uploadProgress:(NSNumber *)progress;

- (void) uploadFailed;

- (void) uploadSucceededWithBlobIds:(NSArray*)blobId NS_SWIFT_NAME(uploadSucceeded(with:));

@end
