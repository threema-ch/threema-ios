#import "ContactSetPhotoMessage.h"
#import "ProtocolDefines.h"

@implementation ContactSetPhotoMessage

@synthesize blobId;
@synthesize size;
@synthesize encryptionKey;

- (uint8_t)type {
    return MSGTYPE_CONTACT_SET_PHOTO;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:blobId];
    [body appendBytes:&size length:sizeof(uint32_t)];
    [body appendData:encryptionKey];
    
    return body;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)isContentValid {
    if (size == 0) {
        return NO;
    }
    
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
