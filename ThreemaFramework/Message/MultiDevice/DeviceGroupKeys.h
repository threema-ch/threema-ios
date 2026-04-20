#import <Foundation/Foundation.h>

#ifndef DeviceGroupKeys_h
#define DeviceGroupKeys_h

@interface DeviceGroupKeys : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDgpk:(NSData*)dgpk dgrk:(NSData*)dgrk dgdik:(NSData*)dgdik dgsddk:(NSData*)dgsddk dgtsk:(NSData*)dgtsk deviceGroupIDFirstByteHex:(NSString *)deviceGroupIDFirstByteHex;

@property (nonatomic, readonly) NSData *dgpk;
@property (nonatomic, readonly) NSData *dgrk;
@property (nonatomic, readonly) NSData *dgdik;
@property (nonatomic, readonly) NSData *dgsddk;
@property (nonatomic, readonly) NSData *dgtsk;
@property (nonatomic, readonly) NSString *deviceGroupIDFirstByteHex;

@end

#endif /* DeviceGroupKeys_h */
