#import "GroupImageMessage.h"
#import "ProtocolDefines.h"

@implementation GroupImageMessage

@synthesize blobId;
@synthesize size;
@synthesize encryptionKey;

- (uint8_t)type {
    return MSGTYPE_GROUP_IMAGE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:self.groupId];
    [body appendData:blobId];
    [body appendBytes:&size length:sizeof(uint32_t)];
    [body appendData:encryptionKey];
    
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

-(BOOL)isContentValid {
    if (size == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    // Legacy messages are not supported in FS
    return kUnspecified;
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.blobId = [decoder decodeObjectOfClass:[NSData class] forKey:@"blobId"];
        self.size = (uint32_t)[decoder decodeIntegerForKey:@"size"];
        self.encryptionKey = [decoder decodeObjectOfClass:[NSData class] forKey:@"encryptionKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.blobId forKey:@"blobId"];
    [encoder encodeInt:self.size forKey:@"size"];
    [encoder encodeObject:self.encryptionKey forKey:@"encryptionKey"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
