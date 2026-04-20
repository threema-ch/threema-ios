#import <Foundation/Foundation.h>
#import "AbstractMessage.h"
#import "MessageProcessorDelegate.h"
    
@class BoxedMessage;
@class ConversationEntity;
@class ContactEntity;

@interface MessageProcessor : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 @param messageProcessorDelegate: Progress information of message processing
 @param groupManager: Must be an GroupManager, is NSObject because GroupManager is implemented in Swift (circularity #import not possible)
 @param entityManager: Must be an EntityManager, is NSObject because EntityManager is implemented in Swift (circularity #import not possible)
 @param fsmp: Must be an ForwardSecurityMessageProcessor, is NSObject because ForwardSecurityMessageProcessor is implemented in Swift (circularity #import not possible)
 @param nonceGuard: Must be an id<NonceGuardProtocolObjc>, is NSObject because NonceGuard is implemented in Swift (circularity #import not
*/
- (instancetype)initWith:(id<MessageProcessorDelegate>)messageProcessorDelegate groupManager:(NSObject *)groupManagerObject entityManager:(NSObject *)entityManagerObject fsmp:(NSObject *)fsmp nonceGuard:(NSObject *)nonceGuardObject;

/**
 Process incoming message.

 @param boxedMessage: Incoming Boxed Message
 @param receivedAfterInitialQueueSend: True indicates the message was received before chat server message queue is dry (abstract message will be marked with this flag, to control in app notification)
 @param maxBytesToDecrypt: Max. size in bytes of message to decrypt (will be used is not enough memory available), 0 for no limit
 @param timeoutDownloadThumbnail: Timeout in seconds for downloading thumbnail, set to zero for no timeout
 @param onCompletion: Returns processed message and optional FS message info, if message is null it's NOT processed
 @param onError: Returns a error and FS message info if it was an FS message and processing failed after removing the FS layer
*/
- (void)processIncomingBoxedMessage:(BoxedMessage*)boxedMessage receivedAfterInitialQueueSend:(BOOL)receivedAfterInitialQueueSend maxBytesToDecrypt:(int)maxBytesToDecrypt timeoutDownloadThumbnail:(int)timeoutDownloadThumbnail onCompletion:(nonnull void (^)(AbstractMessage * _Nullable message, id _Nullable fsMessageInfo))onCompletion onError:(nonnull void (^)(NSError * _Nonnull error, id _Nullable fsMessageInfo))onError;

@end
