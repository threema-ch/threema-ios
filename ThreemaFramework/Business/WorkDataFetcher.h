#import <Foundation/Foundation.h>

@interface WorkDataFetcher : NSObject

+ (void)checkUpdateWorkDataForce:(BOOL)force onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError;

/**
 Fetch work data (fetch2) depending on interval time is set.

 @param force: If YES fetch work data anyway
 @param sendForce: Send update work info anyway
 */
+ (void)checkUpdateWorkDataForce:(BOOL)force sendForce:(BOOL)sendForce onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError;

+ (void)checkUpdateThreemaMDM:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError;

@end
