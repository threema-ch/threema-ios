#import "GroupTextMessage.h"
#import "ProtocolDefines.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation GroupTextMessage

@synthesize text;
@synthesize quotedMessageId;

- (uint8_t)type {
    return MSGTYPE_GROUP_TEXT;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    
    [body appendData:self.groupId];
    [body appendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
    
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

-(BOOL)isContentValid {
    if (text.length == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV12;
}

- (NSData *)quotedBody {
    NSString *quotedText = self.quotedMessageId != nil ? [QuoteUtil generateText:self.text quotedID:self.quotedMessageId] : self.text;

    NSMutableData *body = [NSMutableData dataWithData:[self.groupCreator dataUsingEncoding:NSASCIIStringEncoding]];
    [body appendData:self.groupId];
    [body appendData:[quotedText dataUsingEncoding:NSUTF8StringEncoding]];
    return body;
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
