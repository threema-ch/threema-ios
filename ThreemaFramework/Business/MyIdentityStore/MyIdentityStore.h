#import <Foundation/Foundation.h>

@protocol MyIdentityStoreProtocol <NSObject>

@property (strong, nonatomic, readwrite) NSString *identity;
@property (nullable, strong, nonatomic, readwrite) NSString *pushFromName;

@property (nullable, strong, nonatomic, readwrite) NSString *createIDEmail;
@property (nonatomic, readwrite) BOOL linkEmailPending;
@property (nullable, strong, nonatomic, readwrite) NSString *linkedEmail;

@property (nullable, strong, nonatomic, readwrite) NSString *createIDPhone;
@property (nonatomic, readwrite) BOOL linkMobileNoPending;
@property (nullable, strong, nonatomic, readwrite) NSString *linkedMobileNo;

@property (nullable, strong, nonatomic, readwrite) NSMutableDictionary *profilePicture;

@property (strong, nonatomic, readwrite) NSData *publicKey;
@property (nullable, strong, nonatomic, readwrite) NSData *clientKey;

@property (nullable, strong, nonatomic, readwrite) NSString *firstName;
@property (nullable, strong, nonatomic, readwrite) NSString *lastName;
@property (nullable, strong, nonatomic, readwrite) NSString *csi;
@property (nullable, strong, nonatomic, readwrite) NSString *jobTitle;
@property (nullable, strong, nonatomic, readwrite) NSString *department;
@property (nullable, strong, nonatomic, readwrite) NSString *category;

@property (nonnull, strong, nonatomic, readonly) UIImage *resolvedProfilePicture;
@property (nonnull, strong, nonatomic, readonly) UIColor *idColor;
@property (nonnull, strong, nonatomic, readonly) UIImage *resolvedGroupCallProfilePicture;
@property (nonatomic, readonly) BOOL isDefaultProfilePicture;

@property (nullable, strong, nonatomic, readwrite) NSString *companyName;
@property (nullable, strong, nonatomic, readwrite) NSMutableDictionary *directoryCategories;

- (nullable NSData *)encryptData:(nonnull NSData *)data withNonce:(nonnull NSData *)nonce publicKey:(nonnull NSData *)publicKey;
- (nullable NSData *)decryptData:(nonnull NSData *)data withNonce:(nonnull NSData *)nonce publicKey:(nonnull NSData *)_publicKey;
- (nullable NSData *)sharedSecretWithPublicKey:(nonnull NSData *)publicKey;
- (nullable NSData *)mySharedSecret;

/// Exists there a valid identity?
///
/// This might also be `true` during setup if just the app was deleted, but an identity still exists in the keychain
@property (nonatomic, readonly) BOOL isValidIdentity;

- (nonnull NSString *)displayName;
- (nullable NSString *)backupIdentityWithPassword:(nonnull NSString *)password;

@property (nullable, strong, nonatomic, readwrite) NSDate *revocationPasswordSetDate;
@property (nullable, strong, nonatomic, readwrite) NSDate *revocationPasswordLastCheck;

@property (nullable, strong, nonatomic, readwrite) NSString *licenseSupportUrl NS_SWIFT_NAME(licenseSupportURL);

@property (nullable, strong, nonatomic, readwrite) NSString *serverGroup;

@end

@interface MyIdentityStore : NSObject <MyIdentityStoreProtocol>

@property (nullable, strong, nonatomic, readwrite) NSMutableDictionary *profilePicture;

@property (nonatomic, readwrite) BOOL linkEmailPending;
@property (nullable, strong, nonatomic, readwrite) NSString *linkedEmail;

@property (nonatomic, readwrite) BOOL linkMobileNoPending;
@property (nullable, strong, nonatomic, readwrite) NSString *linkMobileNoVerificationId NS_SWIFT_NAME(linkMobileNoVerificationID);
@property (nullable, strong, nonatomic, readwrite) NSDate *linkMobileNoStartDate;
@property (nullable, strong, nonatomic, readwrite) NSString *linkedMobileNo;

@property (nullable, strong, nonatomic, readwrite) NSDate *privateIdentityInfoLastUpdate;

@property (nonatomic, readwrite) NSInteger lastSentFeatureMask;

@property (nullable, strong, nonatomic, readwrite) NSDate *licenseLastCheck;
@property (nullable, strong, nonatomic, readwrite) NSString *licenseLogoLightUrl NS_SWIFT_NAME(licenseLogoLightURL);
@property (nullable, strong, nonatomic, readwrite) NSString *licenseLogoDarkUrl NS_SWIFT_NAME(licenseLogoDarkURL);

@property (nullable, strong, nonatomic, readwrite) NSData *lastWorkUpdateRequestHash;
@property (nullable, strong, nonatomic, readwrite) NSDate *lastWorkUpdateDate;

@property (nullable, strong, nonatomic, readwrite) NSString *lastWorkInfoLanguage;
@property (nullable, strong, nonatomic, readwrite) NSString *lastWorkInfoMdmDescription;

+ (nonnull MyIdentityStore *)sharedMyIdentityStore;
- (nonnull instancetype) __unavailable init;

+ (void)resetSharedInstance;

- (void)generateKeyPairWithSeed:(nonnull NSData *)seed;
- (nonnull NSArray *)directoryCategoryIdsSortedByName NS_SWIFT_NAME(directoryCategoryIDsSortedByName());

- (nonnull NSString *)addBackupGroupDashes:(nonnull NSString *)backup;
- (void)restoreFromBackup:(nonnull NSString *)backup withPassword:(nonnull NSString *)password onCompletion:(void(^_Nonnull)(void))onCompletion onError:(void(^_Nonnull)(NSError * _Nonnull error))onError;
- (void)restoreFromBackup:(nonnull NSString *)myIdentity withSecretKey:(nonnull NSData *)mySecretKey onCompletion:(void(^_Nonnull)(void))onCompletion onError:(void(^_Nonnull)(NSError * _Nonnull error))onError;
- (BOOL)sendUpdateWorkInfoStatus;

- (NSString *)profilePicturePath;

@end
