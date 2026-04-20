#import <Foundation/Foundation.h>
#import <ThreemaFramework/AbstractGroupMessage.h>
#import <ThreemaFramework/UserSettings.h>

/// Handling of group messages
///
/// - Important: There is a similar implementation in `CommonGroupReceiveSteps`. These should be merged in the future
@interface GroupMessageProcessor : NSObject

/**
 @param message: Group message to process
 @param myIdentityStore: My identity store
 @param userSetting: User settings
 @param groupManager: Must be a id<GroupManagerProtocolObjc>, is NSObject because GroupManagerProtocolObjc is implemented in Swift (circularity #import not possible)
 @param entityManager: Must be an EntityManager, is NSObject because EntityManager is implemented in Swift (circularity #import not possible)
 @param nonceGuard: Must be an id<NonceGuardProtocolObjc>, is NSObject because NonceGuard is implemented in Swift (circularity #import not possible)
 */
- (nonnull instancetype)initWithMessage:(nonnull AbstractGroupMessage *)message myIdentityStore:(id<MyIdentityStoreProtocol> _Nonnull)myIdentityStore userSettings:(id<UserSettingsProtocol> _Nonnull)userSettings groupManager:(nonnull NSObject *)groupManagerObject entityManager:(nonnull NSObject *)entityManagerObject nonceGuard:(nonnull NSObject *)nonceGuardObject;

- (void)handleMessageOnCompletion:(void (^ _Nonnull)(BOOL))onCompletion onError:(void(^ _Nonnull)(NSError * _Nonnull error))onError;

@end
