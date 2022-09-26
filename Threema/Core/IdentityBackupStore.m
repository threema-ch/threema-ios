//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "IdentityBackupStore.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
static const NSString *keychainLabel = @"Threema identity backup";
static const NSString *backupFileName = @"idbackup.txt";

@implementation IdentityBackupStore

+ (NSString *)loadIdentityBackup {
    NSString *backup;
    
    backup = [IdentityBackupStore loadIdentityBackupFromKeychain];
    if (backup == nil)
        backup = [IdentityBackupStore loadIdentityBackupFromFile];
    
    return backup;
}

+ (NSString *)loadIdentityBackupFromKeychain {
    NSMutableDictionary *loadDict = [NSMutableDictionary dictionaryWithDictionary:[self queryDict]];
    [loadDict setObject:@YES forKey:(__bridge id)kSecReturnData];
    
    CFDataRef resultRef;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)loadDict, (CFTypeRef *)&resultRef) == noErr) {
        return [[NSString alloc] initWithData:(__bridge NSData*)resultRef encoding:NSASCIIStringEncoding];
    }
    
    return nil;
}

+ (NSString *)loadIdentityBackupFromFile {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self backupFilePath]]) {
        NSString *backup = [NSString stringWithContentsOfFile:[self backupFilePath] encoding:NSUTF8StringEncoding error:nil];
        if (backup.length > 0)
            return backup;
    }
    
    return nil;
}

+ (BOOL)saveIdentityBackup:(NSString *)backupData {
    BOOL success = YES;
    success &= [IdentityBackupStore saveIdentityBackupToKeychain:backupData];
    success &= [IdentityBackupStore saveIdentityBackupToFile:backupData];
    return success;
}

+ (BOOL)saveIdentityBackupToKeychain:(NSString *)backupData {
    NSDictionary *queryDict = [self queryDict];
    
    /* check if we already have a keychain item and need to update */
    CFDictionaryRef resultRef;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)queryDict, (CFTypeRef *)&resultRef) == noErr) {
        if (SecItemDelete((__bridge CFDictionaryRef)queryDict) != noErr) {
            DDLogError(@"Couldn't delete keychain item");
        }
    }
    
    /* add new item */
    NSDictionary *addDict = @{
                              (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                              (__bridge id)kSecAttrLabel: keychainLabel,
                              (__bridge id)kSecValueData: [backupData dataUsingEncoding:NSASCIIStringEncoding],
                              (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked
                              };
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addDict, NULL);
    if (status == noErr) {
        return YES;
    } else {
        DDLogError(@"Couldn't add keychain item, status: %d", (int)status);
        return NO;
    }
}

+ (BOOL)saveIdentityBackupToFile:(NSString *)backupData {
    return [backupData writeToFile:[IdentityBackupStore backupFilePath] atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

+ (void)deleteIdentityBackup {
    SecItemDelete((__bridge CFDictionaryRef)[IdentityBackupStore queryDict]);
    [[NSFileManager defaultManager] removeItemAtPath:[self backupFilePath] error:nil];
}

+ (NSDictionary*)queryDict {
    return @{
             (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrLabel: keychainLabel
    };
}

+ (NSString*)backupFilePath {
    return [[FileUtility appDocumentsDirectory].path stringByAppendingPathComponent:(NSString*)backupFileName];
}

+ (void)syncKeychainWithFile {
    /* Check for an ID backup in the keychain and in a file within the app data container. If one of them is
       missing, restore it (keychain takes priority). We need both the keychain entry and the file, as the
       keychain entry survives app deletion/reinstallation, while the file survives device backup/restore
       via iCloud. */    
    NSString *keychainBackup = [IdentityBackupStore loadIdentityBackupFromKeychain];
    NSString *fileBackup = [IdentityBackupStore loadIdentityBackupFromFile];
    
    if (keychainBackup.length > 0) {
        if (fileBackup == nil || ![keychainBackup isEqualToString:fileBackup]) {
            /* Write file again */
            DDLogVerbose(@"Recreating file-based ID backup from keychain");
            [IdentityBackupStore saveIdentityBackupToFile:keychainBackup];
        }
    } else if (fileBackup.length > 0) {
        if (keychainBackup == nil || ![fileBackup isEqualToString:keychainBackup]) {
            /* Write keychain entry again */
            DDLogVerbose(@"Recreating keychain ID backup from file");
            [IdentityBackupStore saveIdentityBackupToKeychain:fileBackup];
        }
    }
}

@end
