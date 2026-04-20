#import "GroupCreateMessage.h"
#import "ProtocolDefines.h"

@implementation GroupCreateMessage

@synthesize groupMembers;

- (uint8_t)type {
    return MSGTYPE_GROUP_CREATE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:self.groupId];
    
    for (NSString *identity in groupMembers) {
        [body appendData:[identity dataUsingEncoding:NSASCIIStringEncoding]];
    }
    
    return body;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)isContentValid {
    return YES;
}

- (NSString *)description {
    NSString *result = [super description];
    return [result stringByAppendingFormat:@" group create - members: %@", groupMembers];
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
        self.groupMembers = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSString class]]] forKey:@"groupMembers"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.groupMembers forKey:@"groupMembers"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
