#import "UnknownTypeMessage.h"

@implementation UnknownTypeMessage

- (BOOL)flagShouldPush {
    return NO;
}

-(BOOL)isContentValid {
    return NO;
}

- (BOOL)allowSendingProfile {
    return NO;
}

- (BOOL)noDeliveryReceiptFlagSet {
    return YES;
}

- (BOOL)canShowUserNotification {
    return NO;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kUnspecified;
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
