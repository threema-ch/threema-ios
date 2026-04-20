#import "GroupFileMessage.h"

@implementation GroupFileMessage

- (uint8_t)type {
    return MSGTYPE_GROUP_FILE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:self.groupId];

    [body appendData:_jsonData];
    
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV12;
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.jsonData = [decoder decodeObjectOfClass:[NSData class] forKey:@"jsonData"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.jsonData forKey:@"jsonData"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
