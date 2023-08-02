//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "NaClCrypto.h"
#import "NSData+Base32.h"
#import "CryptoUtils.h"
#import "NaClCrypto.h"
#import "ThreemaError.h"
#import "AppGroup.h"
#import "UserSettings.h"
#import "ValidationLogger.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
static const NSString *keychainLabel = @"Threema identity 1";

@implementation MyIdentityStore {
    NSData *secretKey;
    BOOL secretKeyInKeychain;
    BOOL keychainLocked;
}

@synthesize identity;
@synthesize serverGroup;
@synthesize publicKey;

static MyIdentityStore *instance;

+ (MyIdentityStore*)sharedMyIdentityStore {
	@synchronized (self) {
		if (!instance)
			instance = [[MyIdentityStore alloc] init];
	}
	
	return instance;
}

+ (void)resetSharedInstance {
    instance = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        OSStatus status = [self loadFromKeychain];
        
        if (identity == nil) {
            if (status == errSecInteractionNotAllowed) {
                keychainLocked = YES;
            } else if (status == errSecItemNotFound) {
                /* This can happen when a backup is restored to a new phone, and we have our NSUserDefaults
                 but no keychain item. Make sure the identity-specific defaults are wiped to avoid confusion
                 later on */
                DDLogVerbose(@"No identity - clearing identity-specific user defaults");
                [self removeIdentityUserDefaults];
            }
        }
        
        
        [self migrateProfilePicture];
    }
    return self;
}

- (BOOL)isProvisioned {
    /* check prerequisites */
    if ([self isInvalidIdentity]) {
        return false;
    }
    
    if (self.pendingCreateID) {
        return false;
    }
    
    return true;
}

- (BOOL)isKeychainLocked {
    return keychainLocked;
}

- (BOOL)isInvalidIdentity {
    return identity == nil || publicKey == nil || serverGroup == nil || (secretKey == nil && !secretKeyInKeychain);
}

- (void)generateKeyPairWithSeed:(NSData*)seed {
    NSData *newPublicKey, *newSecretKey;
    
    DDLogInfo(@"Generating key pair");
    [[NaClCrypto sharedCrypto] generateKeyPairPublicKey:&newPublicKey secretKey:&newSecretKey withSeed:seed];
    identity = nil;
    serverGroup = nil;
    publicKey = newPublicKey;
    secretKey = newSecretKey;
    secretKeyInKeychain = NO;
}

- (OSStatus)loadFromKeychain {
    NSMutableDictionary *keychainDict = [NSMutableDictionary dictionary];
    
    [keychainDict setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [keychainDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [keychainDict setObject:keychainLabel forKey:(__bridge id)kSecAttrLabel];

    CFDictionaryRef resultRef;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(keychainDict), (CFTypeRef *)&resultRef);

    if (status == noErr) {
        NSDictionary *result = (__bridge_transfer NSDictionary *)resultRef;
        
        /* sanity check on identity and public key; backup/restore to a new iPhone can produce
           strange results */
        NSString *tmpIdentity = [result objectForKey:(__bridge id)(kSecAttrAccount)];
        NSData *tmpPublicKey = [result objectForKey:(__bridge id)(kSecAttrGeneric)];
        
        if (tmpIdentity.length != kIdentityLen || tmpPublicKey.length != kNaClCryptoPubKeySize) {
            DDLogError(@"Got bad identity or key from keychain; ignoring");
            return status;
        }
        
        identity = tmpIdentity;
        publicKey = tmpPublicKey;
        serverGroup = [result objectForKey:(__bridge id)(kSecAttrService)];
        secretKey = nil;
        secretKeyInKeychain = YES;
        
        DDLogInfo(@"Loaded identity %@ from keychain", identity);
    } else {
        if (status != errSecItemNotFound) {
            [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Keychain: Error accessing keychain, status: %i", (int)status]];
            DDLogError(@"Error accessing keychain, status: %i", (int)status);
        }
    }
    return status;
}

- (void)storeInKeychain {
    
    if (identity == nil || publicKey == nil || secretKey == nil || serverGroup == nil) {
        DDLogError(@"Not enough data to store in keychain");
        return;
    }
    
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    [queryDict setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryDict setObject:keychainLabel forKey:(__bridge id)kSecAttrLabel];
    
    /* check if we already have a keychain item and need to update */
    CFDictionaryRef resultRef;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)(queryDict), (CFTypeRef *)&resultRef) == noErr) {
        if (SecItemDelete((__bridge CFDictionaryRef)(queryDict)) != noErr) {
            DDLogError(@"Couldn't delete keychain item");
        }
    }
    
    /* add new item */
    NSMutableDictionary *addDict = [NSMutableDictionary dictionary];
    [addDict setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [addDict setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
    [addDict setObject:publicKey forKey:(__bridge id)kSecAttrGeneric];
    [addDict setObject:identity forKey:(__bridge id)kSecAttrAccount];
    [addDict setObject:serverGroup forKey:(__bridge id)kSecAttrService];
    [addDict setObject:keychainLabel forKey:(__bridge id)kSecAttrLabel];
    [addDict setObject:secretKey forKey:(__bridge id)kSecValueData];
    if (SecItemAdd((__bridge CFDictionaryRef)(addDict), NULL) != noErr) {
        DDLogError(@"Couldn't add keychain item");
    } else {
        secretKey = nil;
        secretKeyInKeychain = YES;
    }
    
    self.privateIdentityInfoLastUpdate = [NSDate date];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCreatedIdentity object:nil];    
}

- (void)updateConnectionRights {
    OSStatus status = [self loadFromKeychain];
    if (status != errSecInteractionNotAllowed) {
        secretKey = [self _obtainSecretKey];
        if (secretKey != nil) {
            [self deleteFromKeychain];
            [self storeInKeychain];
        }
    }
}

- (void)deleteFromKeychain {
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    [queryDict setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryDict setObject:keychainLabel forKey:(__bridge id)kSecAttrLabel];
    if (SecItemDelete((__bridge CFDictionaryRef)(queryDict)) != noErr) {
        DDLogError(@"Couldn't delete keychain item");
    }
    secretKeyInKeychain = NO;
}

- (void)destroy {
    [self deleteFromKeychain];

    DeviceGroupKeyManager *deviceGroupKeyManager = [[DeviceGroupKeyManager alloc] initWithMyIdentityStore:self];
    [deviceGroupKeyManager destroy];
    
    [self removeIdentityUserDefaults];
    [[UserSettings sharedUserSettings] setPushDecrypt:NO];
    [[UserSettings sharedUserSettings] setAskedForPushDecryption:NO];
    [[UserSettings sharedUserSettings] setSafeConfig:nil];
    self.tempSafePassword = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDestroyedIdentity object:nil];
}

- (void)removeIdentityUserDefaults {
    [[KeychainKeyWrapper new] deleteWrappingKey];
    [DeviceCookieManager deleteDeviceCookie];
    
    [[AppGroup userDefaults] removeObjectForKey:@"PushFromName"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[self profilePicturePath]]) {
        NSError *error;
        [fileManager removeItemAtPath:[self profilePicturePath] error:&error];
        if (error) {
        }
    }
    [[AppGroup userDefaults] removeObjectForKey:@"ProfilePicture"];
    [[AppGroup userDefaults] removeObjectForKey:kWallpaperKey];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkedEmail"];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkEmailPending"];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkedMobileNo"];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkMobileNoPending"];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkMobileNoVerificationId"];
    [[AppGroup userDefaults] removeObjectForKey:@"LinkMobileNoStartDate"];
    [[AppGroup userDefaults] removeObjectForKey:@"PrivateIdentityInfoLastUpdate"];
    [[AppGroup userDefaults] removeObjectForKey:@"LastSentFeatureMask"];
    [[AppGroup userDefaults] removeObjectForKey:@"RevocationPasswordSetDate"];
    [[AppGroup userDefaults] removeObjectForKey:@"RevocationPasswordLastCheck"];
    [[AppGroup userDefaults] removeObjectForKey:@"PendingCreateID"];
    [[AppGroup userDefaults] removeObjectForKey:@"CreateIDEmail"];
    [[AppGroup userDefaults] removeObjectForKey:@"CreateIDPhone"];
    [[AppGroup userDefaults] removeObjectForKey:@"FirstName"];
    [[AppGroup userDefaults] removeObjectForKey:@"LastName"];
    [[AppGroup userDefaults] removeObjectForKey:@"CSI"];
    [[AppGroup userDefaults] removeObjectForKey:@"Category"];
    [[AppGroup userDefaults] removeObjectForKey:@"CompanyName"];
    [[AppGroup userDefaults] removeObjectForKey:@"DirectoryCategories"];
    [[AppGroup userDefaults] removeObjectForKey:@"LastWorkUpdateRequest"];
    [[AppGroup userDefaults] removeObjectForKey:@"LastWorkUpdateDate"];
    [[AppGroup userDefaults] removeObjectForKey:@"MessageDrafts"];
    [[AppGroup userDefaults] removeObjectForKey:@"PushNotificationEncryptionKey"];
    [[AppGroup userDefaults] removeObjectForKey:@"MatchToken"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)pushFromName {
    return [[AppGroup userDefaults] objectForKey:@"PushFromName"];
}

- (void)setPushFromName:(NSString *)pushFromName {
    [[AppGroup userDefaults] setObject:pushFromName forKey:@"PushFromName"];
    [[AppGroup userDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationProfileNicknameChanged object:nil];
}

- (NSMutableDictionary *)profilePicture {
    return [NSMutableDictionary dictionaryWithContentsOfFile:[self profilePicturePath]];
}

- (void)setProfilePicture:(NSMutableDictionary *)profilePicture {
    if (!profilePicture) {
        [[AppGroup userDefaults] removeObjectForKey:@"ProfilePicture"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:[self profilePicturePath]]) {
            NSError *error;
            [fileManager removeItemAtPath:[self profilePicturePath] error:&error];
            if (error) {
            }
        }
    } else {
        [profilePicture writeToFile:[self profilePicturePath] atomically:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationProfilePictureChanged object:nil];
}

- (NSString *)linkedEmail {
    return [[AppGroup userDefaults] objectForKey:@"LinkedEmail"];
}

- (void)setLinkedEmail:(NSString *)linkedEmail {
    [[AppGroup userDefaults] setObject:linkedEmail forKey:@"LinkedEmail"];
    [[AppGroup userDefaults] synchronize];
}

- (BOOL)linkEmailPending {
    return [[AppGroup userDefaults] boolForKey:@"LinkEmailPending"];
}

- (void)setLinkEmailPending:(BOOL)linkEmailPending {
    [[AppGroup userDefaults] setBool:linkEmailPending forKey:@"LinkEmailPending"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)linkedMobileNo {
    return [[AppGroup userDefaults] objectForKey:@"LinkedMobileNo"];
}

- (void)setLinkedMobileNo:(NSString *)linkedMobileNo {
    [[AppGroup userDefaults] setObject:linkedMobileNo forKey:@"LinkedMobileNo"];
    [[AppGroup userDefaults] synchronize];
}

- (BOOL)linkMobileNoPending {
    return [[AppGroup userDefaults] boolForKey:@"LinkMobileNoPending"];
}

- (void)setLinkMobileNoPending:(BOOL)linkMobileNoPending {
    [[AppGroup userDefaults] setBool:linkMobileNoPending forKey:@"LinkMobileNoPending"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)linkMobileNoVerificationId {
    return [[AppGroup userDefaults] stringForKey:@"LinkMobileNoVerificationId"];
}

- (void)setLinkMobileNoVerificationId:(NSString *)linkMobileNoVerificationId {
    [[AppGroup userDefaults] setObject:linkMobileNoVerificationId forKey:@"LinkMobileNoVerificationId"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)linkMobileNoStartDate {
    return [[AppGroup userDefaults] objectForKey:@"LinkMobileNoStartDate"];
}

- (void)setLinkMobileNoStartDate:(NSDate *)linkMobileNoStartDate {
    [[AppGroup userDefaults] setObject:linkMobileNoStartDate forKey:@"LinkMobileNoStartDate"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)privateIdentityInfoLastUpdate {
    return [[AppGroup userDefaults] objectForKey:@"PrivateIdentityInfoLastUpdate"];
}

- (void)setPrivateIdentityInfoLastUpdate:(NSDate *)privateIdentityInfoLastUpdate {
    [[AppGroup userDefaults] setObject:privateIdentityInfoLastUpdate forKey:@"PrivateIdentityInfoLastUpdate"];
    [[AppGroup userDefaults] synchronize];
}

- (NSInteger)lastSentFeatureMask {
    return [[AppGroup userDefaults] integerForKey:@"LastSentFeatureMask"];
}

- (void)setLastSentFeatureMask:(NSInteger)lastSentFeatureMask {
    [[AppGroup userDefaults] setInteger:lastSentFeatureMask forKey:@"LastSentFeatureMask"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)revocationPasswordSetDate {
    return [[AppGroup userDefaults] objectForKey:@"RevocationPasswordSetDate"];
}

- (void)setRevocationPasswordSetDate:(NSDate *)revocationPasswordSetDate {
    [[AppGroup userDefaults] setObject:revocationPasswordSetDate forKey:@"RevocationPasswordSetDate"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)revocationPasswordLastCheck {
    return [[AppGroup userDefaults] objectForKey:@"RevocationPasswordLastCheck"];
}

- (void)setLicenseLastCheck:(NSDate *)licenseLastCheck {
    [[AppGroup userDefaults] setObject:licenseLastCheck forKey:@"LicenseLastCheck"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)licenseLastCheck {
    return [[AppGroup userDefaults] objectForKey:@"LicenseLastCheck"];
}

- (void)setLicenseLogoLightUrl:(NSString *)licenseLogoLightUrl {
    [[AppGroup userDefaults] setObject:licenseLogoLightUrl forKey:@"LicenseLogoLightUrl"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)licenseLogoLightUrl {
    return [[AppGroup userDefaults] objectForKey:@"LicenseLogoLightUrl"];
}

- (void)setLicenseLogoDarkUrl:(NSString *)licenseLogoDarkUrl {
    [[AppGroup userDefaults] setObject:licenseLogoDarkUrl forKey:@"LicenseLogoDarkUrl"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)licenseLogoDarkUrl {
    return [[AppGroup userDefaults] objectForKey:@"LicenseLogoDarkUrl"];
}

- (void)setLicenseSupportUrl:(NSString *)licenseSupportUrl {
    [[AppGroup userDefaults] setObject:licenseSupportUrl forKey:@"LicenseSupportUrl"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)licenseSupportUrl {
    return [[AppGroup userDefaults] objectForKey:@"LicenseSupportUrl"];
}

- (void)setRevocationPasswordLastCheck:(NSDate *)revocationPasswordLastCheck {
    [[AppGroup userDefaults] setObject:revocationPasswordLastCheck forKey:@"RevocationPasswordLastCheck"];
    [[AppGroup userDefaults] synchronize];
}


- (BOOL)pendingCreateID {
    return [[AppGroup userDefaults] boolForKey:@"PendingCreateID"];
}

- (void)setPendingCreateID:(BOOL)pendingCreateID {
    [[AppGroup userDefaults] setBool:pendingCreateID forKey:@"PendingCreateID"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString*)createIDEmail {
    return [[AppGroup userDefaults] stringForKey:@"CreateIDEmail"];
}

- (void)setCreateIDEmail:(NSString *)createIDEmail {
    [[AppGroup userDefaults] setObject:createIDEmail forKey:@"CreateIDEmail"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString*)createIDPhone {
    return [[AppGroup userDefaults] stringForKey:@"CreateIDPhone"];
}

- (void)setCreateIDPhone:(NSString *)createIDPhone {
    [[AppGroup userDefaults] setObject:createIDPhone forKey:@"CreateIDPhone"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)firstName {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"FirstName"];
    DDLogWarn(@"[MyIdentityStore] get firstName %@", value);
    return value;
}

- (void)setFirstName:(NSString *)firstName {
    DDLogWarn(@"[MyIdentityStore] set new firstName %@, old was %@", firstName,  [[AppGroup userDefaults] stringForKey:@"FirstName"]);
    [[AppGroup userDefaults] setObject:firstName forKey:@"FirstName"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)lastName {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"LastName"];
    DDLogWarn(@"[MyIdentityStore] get lastName %@", value);
    return value;
}

- (void)setLastName:(NSString *)lastName {
    DDLogWarn(@"[MyIdentityStore] set new lastName %@, old was %@", lastName, [[AppGroup userDefaults] stringForKey:@"LastName"]);
    [[AppGroup userDefaults] setObject:lastName forKey:@"LastName"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString * _Nonnull)displayName {
    
    NSString *name = [ContactUtil nameFromFirstname:[self firstName] lastname:[self lastName]];
    
    if (name != nil && name.length > 0) {
        return name;
    }
    
    NSString *nickname = [self pushFromName];
    if (nickname != nil && nickname.length > 0 && ![nickname isEqualToString:identity]) {
        return nickname;
    }
    
    NSString *meString = [BundleUtil localizedStringForKey:@"me"];
    if (identity != nil && identity.length > 0) {
        return [NSString stringWithFormat:@"%@ (%@)", identity, meString];
    }
    
    return meString;
}

- (NSString *)csi {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"CSI"];
    DDLogWarn(@"[MyIdentityStore] get csi %@", value);
    return value;
}

- (void)setCsi:(NSString *)csi {
    DDLogWarn(@"[MyIdentityStore] set new csi %@, old was %@", csi, [[AppGroup userDefaults] stringForKey:@"CSI"]);
    [[AppGroup userDefaults] setObject:csi forKey:@"CSI"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)category {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"Category"];
    DDLogWarn(@"[MyIdentityStore] get category %@", value);
    return value;
}

- (void)setCategory:(NSString *)category {
    DDLogWarn(@"[MyIdentityStore] set new category %@, old was %@", category,  [[AppGroup userDefaults] stringForKey:@"Category"]);
    [[AppGroup userDefaults] setObject:category forKey:@"Category"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)companyName {
    return [[AppGroup userDefaults] stringForKey:@"CompanyName"];
}

- (void)setCompanyName:(NSString *)companyName {
    [[AppGroup userDefaults] setObject:companyName forKey:@"CompanyName"];
    [[AppGroup userDefaults] synchronize];
}

- (NSMutableDictionary *)directoryCategories {
    return [[AppGroup userDefaults] objectForKey:@"DirectoryCategories"];
}

- (void)setDirectoryCategories:(NSMutableDictionary *)directoryCategories {
    [[AppGroup userDefaults] setObject:directoryCategories forKey:@"DirectoryCategories"];
    [[AppGroup userDefaults] synchronize];
}

- (NSArray *)directoryCategoryIdsSortedByName {
    NSDictionary *allCategories = [self directoryCategories];
    NSArray *keys = [allCategories allKeys];
    NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [allCategories objectForKey:a];
        NSString *second = [allCategories objectForKey:b];
        return [first caseInsensitiveCompare:second];
    }];
    
    return sortedKeys;
}

- (NSDictionary *)lastWorkUpdateRequest {
    return [[AppGroup userDefaults] objectForKey:@"LastWorkUpdateRequest"];
}

- (void)setLastWorkUpdateRequest:(NSDictionary *)lastWorkUpdateRequest {
    [[AppGroup userDefaults] setObject:lastWorkUpdateRequest forKey:@"LastWorkUpdateRequest"];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)lastWorkUpdateDate {
    return [[AppGroup userDefaults] objectForKey:@"LastWorkUpdateDate"];
}

- (void)setLastWorkUpdateDate:(NSDate *)lastWorkUpdateDate {
    [[AppGroup userDefaults] setObject:lastWorkUpdateDate forKey:@"LastWorkUpdateDate"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)lastWorkInfoLanguage {
    return [[AppGroup userDefaults] objectForKey:@"lastWorkInfoLanguage"];
}

- (void)setLastWorkInfoLanguage:(NSString *)newLastWorkInfoLanguage {
    [[AppGroup userDefaults] setObject:newLastWorkInfoLanguage forKey:@"lastWorkInfoLanguage"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)lastWorkInfoMdmDescription {
    return [[AppGroup userDefaults] objectForKey:@"lastWorkInfoMdmDescription"];
}

- (void)setLastWorkInfoMdmDescription:(NSString *)newLastWorkInfoMdmDescription {
    [[AppGroup userDefaults] setObject:newLastWorkInfoMdmDescription forKey:@"lastWorkInfoMdmDescription"];
    [[AppGroup userDefaults] synchronize];
}

- (NSData*)keySecret {
    NSData *mySecretKey = [self _obtainSecretKey];
    return mySecretKey;
}

- (NSData*)encryptData:(NSData*)data withNonce:(NSData*)nonce publicKey:(NSData*)_publicKey {

    NSData *mySecretKey = [self _obtainSecretKey];
    
    if (mySecretKey == nil) {
        DDLogError(@"Cannot encrypt: no secret key");
        return nil;
    }
    
    @try {
        return [[NaClCrypto sharedCrypto] encryptData:data withPublicKey:_publicKey signKey:mySecretKey nonce:nonce];
    }
    @catch (NSException *exception) {
        DDLogError(@"Cannot encrypt: %@", [exception reason]);
        return nil;
    }
}

- (NSData*)decryptData:(NSData*)data withNonce:(NSData*)nonce publicKey:(NSData*)_publicKey {
    
    NSData *mySecretKey = [self _obtainSecretKey];
    
    if (mySecretKey == nil) {
        DDLogError(@"Cannot decrypt: no secret key");
        return nil;
    }
    
    @try {
        return [[NaClCrypto sharedCrypto] decryptData:data withSecretKey:mySecretKey signKey:_publicKey nonce:nonce];
    }
    @catch (NSException *exception) {
        DDLogError(@"Cannot decrypt: %@", [exception reason]);
        return nil;
    }
}

- (NSData*)sharedSecretWithPublicKey:(NSData*)publicKey {
    NSData *mySecretKey = [self _obtainSecretKey];
    if (mySecretKey == nil) {
        DDLogError(@"Cannot calculate shared secret: no secret key");
        return nil;
    }
    return [[NaClCrypto sharedCrypto] sharedSecretForPublicKey:publicKey secretKey:mySecretKey];
}

- (NSData*)_obtainSecretKey {
    NSData *mySecretKey = secretKey;
    if (mySecretKey == nil && secretKeyInKeychain) {
        NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
        [queryDict setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        [queryDict setObject:keychainLabel forKey:(__bridge id)kSecAttrLabel];
        [queryDict setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
        CFDataRef resultRef;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)(queryDict), (CFTypeRef *)&resultRef) == noErr) {
            mySecretKey = (__bridge_transfer NSData*)resultRef;
        }
    }
    return mySecretKey;
}

- (NSString*)backupIdentityWithPassword:(NSString*)password {
    if ([self isInvalidIdentity]) {
        return nil;
    }
    
    /* Identity backup: derive an encryption key from the given password
       using PBKDF2 with 100000 iterations and a 64 bit salt.
       Then use it to encrypt a binary string of the following format
       using crypto_stream (zero nonce):
     
       <identity><private key><hash>
     
       hash = first two bytes of SHA256(<identity><private key>)
     
       Prepend the salt to the encrypted string and Base32-encode the result.
       Finally, split into groups of 4 and separate with dashes.
       The result will look like:
     
       XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-
       XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
    */
    NSData *salt = [[NaClCrypto sharedCrypto] randomBytes:8];
    NSData *keyData = [self deriveBackupKeyFromPassword:password salt:salt];
    if (keyData == nil)
        return nil;
    
    NSData *mySecretKey = [self _obtainSecretKey];
    NSMutableData *idData = [NSMutableData dataWithCapacity:(mySecretKey.length + kIdentityLen + 2)];
    [idData appendData:[identity dataUsingEncoding:NSASCIIStringEncoding]];
    [idData appendData:mySecretKey];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(idData.bytes, (CC_LONG)idData.length, digest);
    [idData appendBytes:digest length:2];
    
    NSData *nonceData = [[NaClCrypto sharedCrypto] zeroBytes:kNaClCryptoStreamNonceSize];
    NSData *idDataEncrypted = [[NaClCrypto sharedCrypto] streamXorData:idData secretKey:keyData nonce:nonceData];
    
    /* Concatenate salt + encrypted data. The result should be 50 bytes. */
    NSMutableData *idDataWithSalt = [NSMutableData dataWithData:salt];
    [idDataWithSalt appendData:idDataEncrypted];
    
    NSString *base32 = [idDataWithSalt base32String];
    NSString *grouped = [self addBackupGroupDashes:base32];
    
    return grouped;
}

- (NSString*)addBackupGroupDashes:(NSString*)backup {
    NSString *myBackup = [backup stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSMutableString *grouped = [NSMutableString string];
    
    for (int i = 0; i < myBackup.length; i += 4) {
        NSUInteger len = 4;
        if ((i + len) > myBackup.length)
            len = myBackup.length - i;
        
        if (grouped.length > 0)
            [grouped appendString:@"-"];
        [grouped appendString:[myBackup substringWithRange:NSMakeRange(i, len)]];
    }
    
    return grouped;
}

- (void)restoreFromBackup:(NSString*)backup withPassword:(NSString*)password onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {

    /* decode Base32 data */
    NSData *backupDecoded = [NSData dataWithBase32String:backup];
    if (backupDecoded.length != 50) {
        DDLogError(@"Invalid decoded backup length: %lu", (unsigned long)backupDecoded.length);
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"bad_identity_backup"]]);
        return;
    }
    
    /* Extract salt and derive key */
    NSData *salt = [NSData dataWithBytes:backupDecoded.bytes length:8];
    NSData *keyData = [self deriveBackupKeyFromPassword:password salt:salt];
    if (keyData == nil) {
        DDLogError(@"Invalid password");
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"bad_identity_backup"]]);
        return;
    }
    
    /* Decrypt backup data */
    NSData *backupData = [NSData dataWithBytes:(backupDecoded.bytes + 8) length:42];
    
    NSData *nonceData = [[NaClCrypto sharedCrypto] zeroBytes:kNaClCryptoStreamNonceSize];
    NSData *backupDataDecrypted = [[NaClCrypto sharedCrypto] streamXorData:backupData secretKey:keyData nonce:nonceData];
    if (backupDataDecrypted == nil) {
        /* should never happen, even if the data is invalid */
        onError([ThreemaError threemaError:@"Backup decryption failed"]);
        return;
    }
    
    /* Calculate digest and verify */
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(backupDataDecrypted.bytes, 40, digest);
    
    if (memcmp(digest, backupDataDecrypted.bytes + 40, 2) != 0) {
        DDLogWarn(@"Digest mismatch in decrypted identity backup");
        onError([ThreemaError threemaError:[BundleUtil localizedStringForKey:@"bad_identity_backup"]]);
        return;
    }
    
    identity = [[NSString alloc] initWithData:[NSData dataWithBytes:backupDataDecrypted.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
    secretKey = [NSData dataWithBytes:(backupDataDecrypted.bytes + 8) length:kNaClCryptoSecKeySize];
    
    [self restoreFromBackup:identity withSecretKey:secretKey onCompletion:onCompletion onError:onError];
}

- (void)restoreFromBackup:(NSString*)myIdentity withSecretKey:(NSData*)mySecretKey onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    identity = [[NSString alloc]  initWithString:myIdentity];
    secretKey = [NSData dataWithBytes:(mySecretKey.bytes) length:kNaClCryptoSecKeySize];

    /* derive public key and store everything */
    publicKey = [[NaClCrypto sharedCrypto] derivePublicKeyFromSecretKey:secretKey];
    if (publicKey == nil) {
        /* should never happen, even if the data is invalid */
        onError([ThreemaError threemaError:@"Public key derivation failed"]);
        return;
    }
    secretKeyInKeychain = NO;
    serverGroup = nil;
    DDLogInfo(@"Restored identity %@ from backup", identity);
    
    onCompletion();
}

- (BOOL)isValidBackupFormat:(NSString *)backup {
    if (backup == nil)
        return NO;
    
    NSData *backupDecoded = [NSData dataWithBase32String:backup];
    return (backupDecoded.length == 50);
}

- (NSData*)deriveBackupKeyFromPassword:(NSString*)password salt:(NSData*)salt {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t key[kNaClCryptoStreamKeySize];
    
    if (CCKeyDerivationPBKDF(kCCPBKDF2, passwordData.bytes, passwordData.length,
                             salt.bytes, salt.length, kCCPRFHmacAlgSHA256, 100000,
                             key, kNaClCryptoStreamKeySize) != 0) {
        
        DDLogError(@"PBKDF key derivation failed");
        return nil;
    }
    
    return [NSData dataWithBytes:key length:kNaClCryptoStreamKeySize];
}

- (void)migrateProfilePicture {
    NSMutableDictionary *profile = [[AppGroup userDefaults] objectForKey:@"ProfilePicture"];
    if (profile != nil) {
        [profile writeToFile:[self profilePicturePath] atomically:YES];
        [[AppGroup userDefaults] removeObjectForKey:@"ProfilePicture"];
    }
}

- (NSString *)profilePicturePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"ProfilePicture.out"];
}

- (BOOL)sendUpdateWorkInfoStatus {
    NSDate *dateLastCheck = [self lastWorkUpdateDate];
    if (dateLastCheck == nil) {
        return true;
    }
    
    return ![[NSCalendar currentCalendar] isDate:dateLastCheck inSameDayAsDate:[NSDate date]];
}


@end
