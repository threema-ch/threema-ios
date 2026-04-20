#import "BoxedMessage.h"
#import "NSString+Hex.h"

@implementation BoxedMessage

@synthesize fromIdentity;
@synthesize toIdentity;
@synthesize messageId;
@synthesize date;
@synthesize flags;
@synthesize pushFromName;
@synthesize metadataBox;
@synthesize nonce;
@synthesize box;
@synthesize deliveryDate;
@synthesize delivered;
@synthesize userAck;
@synthesize sendUserAck;

#pragma mark - LoggingDescriptionProtocol

- (NSString * _Nonnull)loggingDescription {
    return [NSString stringWithFormat:@"(type: %@; id: %@)", self.class, [NSString stringWithHexData:self.messageId]];
}

@end
