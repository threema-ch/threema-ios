#import "ContactDeletePhotoMessage.h"
#import "ProtocolDefines.h"

@implementation ContactDeletePhotoMessage


- (uint8_t)type {
    return MSGTYPE_CONTACT_DELETE_PHOTO;
}

- (NSData *)body {
    return nil;
}

- (BOOL)flagShouldPush {
    return NO;
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

- (BOOL)needsConversation {
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
