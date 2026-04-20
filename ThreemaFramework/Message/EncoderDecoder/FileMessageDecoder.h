#import <Foundation/Foundation.h>
#import <ThreemaFramework/BoxFileMessage.h>
#import <ThreemaFramework/GroupFileMessage.h>

@interface FileMessageDecoder : NSObject

/**
 Decode abstract file message.

 @param message Abstract file message
 @param senderObject Sender object of type `ContactEntity`
 @param conversationObject Conversation object of type `ConversationEntity`
 @param isReflected Bool
 @param timeout Timeout in seconds for thumbnail download
 @param entityManagerObject Object of type `EntityManager`
 @param onCompletion With parameter of type `BaseMessageEntity` as result
 @param onError With parameter of type `NSError`
 */
+ (void)decodeMessageFromBox:(nonnull BoxFileMessage *)message sender:(nullable NSObject *)senderObject conversation:(nonnull NSObject *)conversationObject isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void(^)(NSObject *))onCompletion onError:(void(^)(NSError *))onError;

/**
 Decode abstract group file message.

 @param message Abstract file message
 @param senderObject Sender object of type `ContactEntity`
 @param conversationObject Conversation object of type `ConversationEntity`
 @param isReflected Bool
 @param timeout Timeout in seconds for thumbnail download
 @param entityManagerObject Object of type `EntityManager`
 @param onCompletion With parameter of type `BaseMessageEntity` as result
 @param onError With parameter of type `NSError`
 */
+ (void)decodeGroupMessageFromBox:(nonnull GroupFileMessage *)message sender:(nullable NSObject *)senderObject conversation:(nonnull NSObject *)conversationObject isReflectedMessage:(BOOL)isReflected timeoutDownloadThumbnail:(int)timeout entityManager:(nonnull NSObject *)entityManagerObject onCompletion:(void(^)(NSObject *))onCompletion onError:(void(^)(NSError *))onError;

+ (nullable NSString *)decodeFilenameFromBox:(nonnull BoxFileMessage *)message;

+ (nullable NSString *)decodeGroupFilenameFromBox:(nonnull GroupFileMessage *)message;

+ (nullable NSString *)decodeFileCaptionFromBox:(nonnull BoxFileMessage *)message;

+ (nullable NSString *)decodeGroupFileCaptionFromBox:(nonnull GroupFileMessage *)message;

@end
