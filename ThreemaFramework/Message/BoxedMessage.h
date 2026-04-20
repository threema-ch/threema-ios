#import <Foundation/Foundation.h>
#import <ThreemaFramework/LoggingDescriptionProtocol.h>

@interface BoxedMessage : NSObject <LoggingDescriptionProtocol>

@property (nonatomic, strong) NSString *fromIdentity;
@property (nonatomic, strong) NSString *toIdentity;
@property (nonatomic, strong) NSData *messageId NS_SWIFT_NAME(messageID);
@property (nonatomic, strong) NSDate* date;
@property (nonatomic) uint8_t flags;
@property (nonatomic, strong) NSString *pushFromName;
@property (nonatomic, strong) NSData *metadataBox;
@property (nonatomic, strong) NSData *nonce;
@property (nonatomic, strong) NSData *box;
@property (nonatomic, strong) NSDate *deliveryDate;
@property (nonatomic, strong) NSNumber *delivered;
@property (nonatomic, strong) NSNumber *userAck;
@property (nonatomic, strong) NSNumber *sendUserAck;

@end
