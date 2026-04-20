#import "DeliveryReceiptMessage.h"
#import "ProtocolDefines.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation DeliveryReceiptMessage

@synthesize receiptType;
@synthesize receiptMessageIds;

- (uint8_t)type {
    return MSGTYPE_DELIVERY_RECEIPT;
}

- (NSData *)body {
    NSMutableData *receiptBody = [NSMutableData dataWithCapacity:kMessageIdLen*receiptMessageIds.count + 1];
    
    [receiptBody appendBytes:&receiptType length:sizeof(uint8_t)];
    
    for (NSData *receiptMessageId in receiptMessageIds) {
        [receiptBody appendData:receiptMessageId];
    }
    
    return receiptBody;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    switch (receiptType) {
        case DeliveryReceiptTypeDeclined:
        case DeliveryReceiptTypeAcknowledged:
            return YES;
        default:
            return NO;
    }
}

- (BOOL)canCreateConversation {
    return NO;
}

- (BOOL)canUnarchiveConversation {
    return NO;
}

- (BOOL)canShowUserNotification {
    return NO;
}

- (BOOL)noDeliveryReceiptFlagSet {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV11;
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.receiptType = (uint8_t)[decoder decodeIntegerForKey:@"receiptType"];
        self.receiptMessageIds = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSData class]]] forKey:@"receiptMessageIds"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeInt:self.receiptType forKey:@"receiptType"];
    [encoder encodeObject:self.receiptMessageIds forKey:@"receiptMessageIds"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
