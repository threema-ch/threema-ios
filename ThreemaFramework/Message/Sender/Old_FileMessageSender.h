#import <Foundation/Foundation.h>
#import <ThreemaFramework/Old_BlobMessageSender.h>
#import <ThreemaFramework/URLSenderItem.h>

@interface Old_FileMessageSender : Old_BlobMessageSender

/**
 @param item URLSenderItem
 @param conversationObject Object of type `ConversationEntity`
 @param requestId NSString
 */
- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject requestId:(NSString *)requestId
    NS_SWIFT_NAME(send(_:in:requestID:));

/**
 @param item URLSenderItem
 @param conversationObject Object of type `ConversationEntity`
 @param requestId NSString
 @param correlationId NSString
 */
- (void)sendItem:(URLSenderItem *)item inConversation:(NSObject *)conversationObject requestId:(NSString *)requestId correlationId:(NSString *)correlationId
    NS_SWIFT_NAME(send(_:in:requestID:correlationID:));

/**
 @param messageObject Object of type `FileMessageEntity`
 */
- (void)retryMessage:(NSObject *)messageObject;

+ (NSString *)messageForError:(UploadError)error;

@end
