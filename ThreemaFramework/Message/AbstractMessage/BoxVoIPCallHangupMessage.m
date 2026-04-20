#import "BoxVoIPCallHangupMessage.h"
#import "ProtocolDefines.h"

@implementation BoxVoIPCallHangupMessage

- (uint8_t)type {
    return MSGTYPE_VOIP_CALL_HANGUP;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:_jsonData];
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)flagImmediateDeliveryRequired {
    return NO;
}

- (BOOL)flagIsVoIP {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
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
