#import "GroupRequestSyncMessage.h"
#import "ProtocolDefines.h"

@implementation GroupRequestSyncMessage

- (uint8_t)type {
    return MSGTYPE_GROUP_REQUEST_SYNC;
}

- (NSData *)body {
    return self.groupId;
}

- (BOOL)flagShouldPush {
    return NO;
}

-(BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return NO;
}

- (BOOL)canShowUserNotification {
    return NO;
}

- (BOOL)isGroupControlMessage {
    return true;
}

- (BOOL)canUnarchiveConversation {
    return NO;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV12;
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
