#import <Foundation/Foundation.h>

@interface GatewayAvatarMaker : NSObject

+ (instancetype)gatewayAvatarMaker;

- (void)refresh;

- (void)refreshForced;

- (void)loadAndSaveAvatarForId:(NSString *)identity;

- (void)loadAvatarForId:(NSString *)identity onCompletion:(void (^)(UIImage *))onCompletion onError:(void (^)(NSError *))onError;

@end
