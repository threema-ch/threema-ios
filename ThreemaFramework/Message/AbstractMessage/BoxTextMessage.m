#import "BoxTextMessage.h"
#import "ProtocolDefines.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation BoxTextMessage

@synthesize text;
@synthesize quotedMessageId;

- (uint8_t)type {
    return MSGTYPE_TEXT;
}

- (NSData *)body {
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)isContentValid {
    if (text.length == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (BOOL)supportsForwardSecurity {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV10;
}

- (NSData *)quotedBody {
    NSString *quotedText = self.quotedMessageId != nil ? [QuoteUtil generateText:self.text quotedID:self.quotedMessageId] : self.text;
    return [quotedText dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.text = [decoder decodeObjectOfClass:[NSString class] forKey:@"text"];
        self.quotedMessageId = [decoder decodeObjectOfClass:[NSData class] forKey:@"quotedMessageId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.text forKey:@"text"];
    [encoder encodeObject:self.quotedMessageId forKey:@"quotedMessageId"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
