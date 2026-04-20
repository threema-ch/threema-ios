#import <Foundation/Foundation.h>
#import "DeviceGroupKeys.h"

@implementation DeviceGroupKeys {
    NSData *dgpk;
    NSData *dgrk;
    NSData *dgdik;
    NSData *dgsddk;
    NSData *dgtsk;
    NSString *deviceGroupIDFirstByteHex;
}

@synthesize dgpk;
@synthesize dgrk;
@synthesize dgdik;
@synthesize dgsddk;
@synthesize dgtsk;
@synthesize deviceGroupIDFirstByteHex;

- (instancetype)initWithDgpk:(NSData*)dgpk dgrk:(NSData*)dgrk dgdik:(NSData*)dgdik dgsddk:(NSData*)dgsddk dgtsk:(NSData*)dgtsk deviceGroupIDFirstByteHex:(NSString *)deviceGroupIDFirstByteHex {
    if (self) {
        self->dgpk = dgpk;
        self->dgrk = dgrk;
        self->dgdik = dgdik;
        self->dgsddk = dgsddk;
        self->dgtsk = dgtsk;
        self->deviceGroupIDFirstByteHex = deviceGroupIDFirstByteHex;
    }
    return self;
}

- (NSData *)dgpk {
    return self->dgpk;
}

- (NSData *)dgrk {
    return self->dgrk;
}

- (NSData *)dgdik {
    return self->dgdik;
}

- (NSData *)dgsddk {
    return self->dgsddk;
}

- (NSData *)dgtsk {
    return self->dgtsk;
}

- (NSString *)deviceGroupIDFirstByteHex {
    return self->deviceGroupIDFirstByteHex;
}

@end
