#import "TypingIndicatorMessage.h"
#import "ProtocolDefines.h"

@implementation TypingIndicatorMessage

@synthesize typing;

- (uint8_t)type {
    return MSGTYPE_TYPING_INDICATOR;
}

- (NSData *)body {
    NSMutableData *typingIndicatorBody = [NSMutableData dataWithCapacity:1];
    
    uint8_t typingVal = typing ? 1 : 0;
    [typingIndicatorBody appendBytes:&typingVal length:sizeof(uint8_t)];
    
    return typingIndicatorBody;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)flagDontQueue {
    return YES;
}

- (BOOL)flagDontAck {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return NO;
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
    return [super initWithCoder:decoder];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
