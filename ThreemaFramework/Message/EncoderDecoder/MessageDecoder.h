#import <Foundation/Foundation.h>

#import "AbstractMessage.h"

@interface MessageDecoder : NSObject

/**
 Decrypt and decode Boxed Message.
 
 @param boxmsg: Incoming Boxed Message
 @param publicKey: Public key of sender contact

 @return Decoded message
 */
+ (AbstractMessage*)decodeFromBoxed:(BoxedMessage*)boxmsg withPublicKey:(NSData*)publicKey;

/**
 Decode message depending on type
 
 @param type: Message Type (MSGTYPE_...), see in `ProtocolDefines.h`
 @param body: Decrypted message data
 
 @return Decoded message
 */
+ (AbstractMessage *)decode:(int)type body:(NSData *)body;

+ (AbstractMessage*)decodeRawBody:(NSData*)data realDataLength:(int)realDataLength; __deprecated_msg("Only to be used in MessageDecoder+Swift.swift.");

@end
