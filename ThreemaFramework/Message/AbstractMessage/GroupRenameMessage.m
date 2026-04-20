#import "GroupRenameMessage.h"
#import "ProtocolDefines.h"

@implementation GroupRenameMessage

@synthesize name;

- (uint8_t)type {
    return MSGTYPE_GROUP_RENAME;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:self.groupId];
    [body appendData:[name dataUsingEncoding:NSUTF8StringEncoding]];
    
    return body;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
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
    if (self = [super initWithCoder:decoder]) {
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.name forKey:@"name"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
