#import "BoxVoIPCallAnswerMessage.h"
#import "ProtocolDefines.h"

@implementation BoxVoIPCallAnswerMessage

- (uint8_t)type {
    return MSGTYPE_VOIP_CALL_ANSWER;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:_jsonData];
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)flagImmediateDeliveryRequired {
    return YES;
}

- (BOOL)flagIsVoIP {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return _isUserInteraction;
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
