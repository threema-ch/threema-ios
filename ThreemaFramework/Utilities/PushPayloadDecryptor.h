#import <Foundation/Foundation.h>

@interface PushPayloadDecryptor : NSObject

+ (NSDictionary*)decryptPushPayload:(NSDictionary*)encryptedPayload;
+ (NSData*)pushEncryptionKey;

@end
