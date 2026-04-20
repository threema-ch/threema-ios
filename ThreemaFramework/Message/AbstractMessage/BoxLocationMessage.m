#import "BoxLocationMessage.h"
#import "ProtocolDefines.h"

@implementation BoxLocationMessage

@synthesize latitude;
@synthesize longitude;
@synthesize accuracy;
@synthesize poiName;
@synthesize poiAddress;

- (uint8_t)type {
    return MSGTYPE_LOCATION;
}

- (NSData *)body {
    NSMutableString *bodyString = [NSMutableString stringWithFormat:@"%f,%f,%f", latitude, longitude, accuracy];
    if (poiName != nil) {
        [bodyString appendString:[NSString stringWithFormat:@"\n%@", poiName]];
        if (poiAddress != nil)
            [bodyString appendString:[NSString stringWithFormat:@"\n%@", [poiAddress stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]]];
    }
    
    return [bodyString dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)flagShouldPush {
    return YES;
}

-(BOOL)isContentValid {
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

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.accuracy = [decoder decodeDoubleForKey:@"accuracy"];
        self.latitude = [decoder decodeDoubleForKey:@"latitude"];
        self.longitude = [decoder decodeDoubleForKey:@"longitude"];
        self.poiAddress = [decoder decodeObjectOfClass:[NSString class] forKey:@"poiAddress"];
        self.poiName = [decoder decodeObjectOfClass:[NSString class] forKey:@"poiName"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeDouble:self.accuracy forKey:@"accuracy"];
    [encoder encodeDouble:self.latitude forKey:@"latitude"];
    [encoder encodeDouble:self.longitude forKey:@"longitude"];
    [encoder encodeObject:self.poiAddress forKey:@"poiAddress"];
    [encoder encodeObject:self.poiName forKey:@"poiName"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
