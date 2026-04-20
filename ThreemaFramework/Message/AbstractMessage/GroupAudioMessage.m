#import "GroupAudioMessage.h"
#import "ProtocolDefines.h"

@implementation GroupAudioMessage

@synthesize duration;
@synthesize audioBlobId;
@synthesize audioSize;
@synthesize encryptionKey;

- (uint8_t)type {
    return MSGTYPE_GROUP_AUDIO;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:self.groupId];
    [body appendBytes:&duration length:sizeof(uint16_t)];
    [body appendData:audioBlobId];
    [body appendBytes:&audioSize length:sizeof(uint32_t)];
    [body appendData:encryptionKey];
    
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

-(BOOL)isContentValid {
    if (audioSize == 0) {
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
        self.duration = (uint16_t)[decoder decodeIntegerForKey:@"duration"];
        self.audioBlobId = [decoder decodeObjectOfClass:[NSData class] forKey:@"audioBlobId"];
        self.audioSize = (uint32_t)[decoder decodeIntegerForKey:@"audioSize"];
        self.encryptionKey = [decoder decodeObjectOfClass:[NSData class] forKey:@"encryptionKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeInt:self.duration forKey:@"duration"];
    [encoder encodeObject:self.audioBlobId forKey:@"audioBlobId"];
    [encoder encodeInt:self.audioSize forKey:@"audioSize"];
    [encoder encodeObject:self.encryptionKey forKey:@"encryptionKey"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
