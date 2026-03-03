//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@import FileUtility;
@import Keychain;

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation MyIdentityStore

@synthesize identity;
@synthesize serverGroup;
@synthesize publicKey;
@synthesize clientKey;

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
        [self migrateProfilePicture];
    }
    return self;
}

- (BOOL)isValidIdentity {
    return identity != nil && publicKey != nil && serverGroup != nil && clientKey != nil;
}

- (void)generateKeyPairWithSeed:(NSData*)seed {
    NSData *newPublicKey;
    NSData *newClientKey;
    
    DDLogInfo(@"Generating key pair");
    [[NaClCrypto sharedCrypto] generateKeyPairPublicKey:&newPublicKey secretKey:&newClientKey withSeed:seed];
    identity = nil;
    serverGroup = nil;
    publicKey = newPublicKey;
    clientKey = newClientKey;
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
        FileUtility *fileUtility = [FileUtility new];
        if ([fileUtility fileExistsAtPath:[self profilePicturePath]]) {
            NSError *error;
            [fileUtility deleteAtPath:[self profilePicturePath] error:&error];
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

- (nonnull NSString *)displayName {
    
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

- (NSString *)jobTitle {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"JobTitle"];
    DDLogWarn(@"[MyIdentityStore] get job title %@", value);
    return value;
}

- (void)setJobTitle:(NSString *)jobTitle {
    DDLogWarn(@"[MyIdentityStore] set new job title %@, old was %@", jobTitle, [[AppGroup userDefaults] stringForKey:@"JobTitle"]);
    [[AppGroup userDefaults] setObject:jobTitle forKey:@"JobTitle"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)department {
    NSString *value = [[AppGroup userDefaults] stringForKey:@"Department"];
    DDLogWarn(@"[MyIdentityStore] get department %@", value);
    return value;
}

- (void)setDepartment:(NSString *)department {
    DDLogWarn(@"[MyIdentityStore] set new department %@, old was %@", department, [[AppGroup userDefaults] stringForKey:@"Department"]);
    [[AppGroup userDefaults] setObject:department forKey:@"Department"];
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

- (NSData *)lastWorkUpdateRequestHash {
    return [[AppGroup userDefaults] objectForKey:@"LastWorkUpdateRequestHash"];
}

- (void)setLastWorkUpdateRequestHash:(NSData *)lastWorkUpdateRequestHash {
    [[AppGroup userDefaults] setObject:lastWorkUpdateRequestHash forKey:@"LastWorkUpdateRequestHash"];
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

- (NSData*)encryptData:(NSData*)data withNonce:(NSData*)nonce publicKey:(NSData*)_publicKey {

    NSData *mySecretKey = [self clientKey];
    
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
    
    NSData *mySecretKey = [self clientKey];
    
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
    NSData *mySecretKey = [self clientKey];
    if (mySecretKey == nil) {
        DDLogError(@"Cannot calculate shared secret: no secret key");
        return nil;
    }
    return [[NaClCrypto sharedCrypto] sharedSecretForPublicKey:publicKey secretKey:mySecretKey];
}

- (NSData*)mySharedSecret {
    NSData *mySecretKey = [self clientKey];
    if (mySecretKey == nil) {
        DDLogError(@"Cannot calculate shared secret: no secret key");
        return nil;
    }
    return [[NaClCrypto sharedCrypto] sharedSecretForPublicKey:publicKey secretKey:mySecretKey];
}

- (NSString*)backupIdentityWithPassword:(NSString*)password {
    if (![self isValidIdentity]) {
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
    
    NSData *mySecretKey = [self clientKey];
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
        onError([ThreemaError threemaError:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"bad_identity_backup"], TargetManagerObjC.localizedAppName]]);
        return;
    }
    
    /* Extract salt and derive key */
    NSData *salt = [NSData dataWithBytes:backupDecoded.bytes length:8];
    NSData *keyData = [self deriveBackupKeyFromPassword:password salt:salt];
    if (keyData == nil) {
        DDLogError(@"Invalid password");
        onError([ThreemaError threemaError:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"bad_identity_backup"], TargetManagerObjC.localizedAppName]]);
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
        onError([ThreemaError threemaError:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"bad_identity_backup"], TargetManagerObjC.localizedAppName]]);
        return;
    }
    
    identity = [[NSString alloc] initWithData:[NSData dataWithBytes:backupDataDecrypted.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
    clientKey = [NSData dataWithBytes:(backupDataDecrypted.bytes + 8) length:kNaClCryptoSecKeySize];
    
    [self restoreFromBackup:identity withSecretKey:clientKey onCompletion:onCompletion onError:onError];
}

- (void)restoreFromBackup:(NSString*)myIdentity withSecretKey:(NSData*)mySecretKey onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    identity = [[NSString alloc]  initWithString:myIdentity];
    clientKey = [NSData dataWithBytes:(mySecretKey.bytes) length:kNaClCryptoSecKeySize];

    /* derive public key and store everything */
    publicKey = [[NaClCrypto sharedCrypto] derivePublicKeyFromSecretKey:clientKey];
    if (publicKey == nil) {
        /* should never happen, even if the data is invalid */
        onError([ThreemaError threemaError:@"Public key derivation failed"]);
        return;
    }
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
