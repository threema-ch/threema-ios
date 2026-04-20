#import <Foundation/Foundation.h>
#import <ThreemaFramework/BlobOrigin.h>
#import <ThreemaFramework/UploadProgressDelegate.h>
#import <ThreemaFramework/Old_BlobUploadDelegate.h>
#import <ThreemaFramework/URLSenderItem.h>

@protocol BlobData;
@interface Old_BlobMessageSender : NSObject <Old_BlobUploadDelegate>

/// Type of `BaseMessageEntity<BlobData>` (or `FileMessageEntity`???)
@property NSObject *messageObject;
/// Type of `ConversationEntity`
@property NSObject *conversationObject;
@property NSString *fileNameFromWeb;

@property id<UploadProgressDelegate> uploadProgressDelegate;

- (void)scheduleUpload;

+ (BOOL)hasScheduledUploads;

#pragma mark - abstract methods

/**
 @param item URLSenderItem
 @param conversationObject Object of type `ConversationEntity`
*/
- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject;

- (void)sendMessage:(NSArray *)bolbIds;

- (NSData *)encryptedData;

- (NSData *)encryptedThumbnailData;

- (void)createDBMessage;

- (BOOL)supportsCaption;

@end
