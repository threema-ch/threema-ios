//
// Copyright 2011-2012 Kosher Penguin LLC
// Created by Adar Porat (https://github.com/aporat) on 1/16/2012.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "KKKeychain.h"
#import <Security/Security.h>
#import "BundleUtil.h"

@implementation KKKeychain

+ (NSString*)appName
{
	NSBundle *bundle = [BundleUtil mainBundle];
	NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (!appName) {
		appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
	}
	return appName;
}

+ (BOOL)setString:(NSString*)string forKey:(NSString*)key
{
	if (string == nil || key == nil) {
		return NO;
	}
	
	key = [NSString stringWithFormat:@"%@ - %@", [KKKeychain appName], key];
    
	// First check if it already exists, by creating a search dictionary and requesting that
	// nothing be returned, and performing the search anyway.
	NSMutableDictionary *existsQueryDictionary = [NSMutableDictionary dictionary];
	
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	
	[existsQueryDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
	
	// Add the keys to the search dict
	[existsQueryDictionary setObject:@"service" forKey:(__bridge id)kSecAttrService];
	[existsQueryDictionary setObject:key forKey:(__bridge id)kSecAttrAccount];
    
    // Have SecItemCopyMatching return the data even though we're not interested in it (to work around a Citrix Worx bug)
    CFTypeRef dataDummy = nil;
    [existsQueryDictionary setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
    OSStatus res = SecItemCopyMatching((__bridge CFDictionaryRef)existsQueryDictionary, &dataDummy);
    
    if (dataDummy)
        CFRelease(dataDummy);
    
    [existsQueryDictionary removeObjectForKey:(__bridge id)kSecReturnData];
    
	if (res == errSecItemNotFound) {
		if (string != nil) {
			NSMutableDictionary *addDict = existsQueryDictionary;
			[addDict setObject:data forKey:(__bridge id)kSecValueData];
            [addDict setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
            
			res = SecItemAdd((__bridge CFDictionaryRef)addDict, NULL);
			NSAssert1(res == errSecSuccess, @"Recieved %ld from SecItemAdd!", (long)res);
		}
	} else if (res == errSecSuccess) {
		// Modify an existing one
		// Actually pull it now of the keychain at this point.
        NSDictionary *attributeDict = @{
                                        (__bridge id)kSecValueData: data,
                                        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock
                                        };
		res = SecItemUpdate((__bridge CFDictionaryRef)existsQueryDictionary, (__bridge CFDictionaryRef)attributeDict);
		NSAssert1(res == errSecSuccess, @"SecItemUpdated returned %ld!", (long)res);
	} else {
		NSAssert1(NO, @"Received %ld from SecItemCopyMatching!", (long)res);
	}
	return YES;
}

+ (NSString*)getStringForKey:(NSString*)key
{
	key = [NSString stringWithFormat:@"%@ - %@", [KKKeychain appName], key];
	NSMutableDictionary *existsQueryDictionary = [NSMutableDictionary dictionary];
	[existsQueryDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
	
	// Add the keys to the search dict
	[existsQueryDictionary setObject:@"service" forKey:(__bridge id)kSecAttrService];
	[existsQueryDictionary setObject:key forKey:(__bridge id)kSecAttrAccount];
	
	// We want the data back!
	CFTypeRef data = nil;
	
	[existsQueryDictionary setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
	OSStatus res = SecItemCopyMatching((__bridge CFDictionaryRef)existsQueryDictionary, &data);
    
	if (res == errSecSuccess) {
		NSString *string = [[NSString alloc] initWithData:(__bridge NSData*)data encoding:NSUTF8StringEncoding];
        CFRelease(data);
		return string;
    } else {
        if (data)
            CFRelease(data);
		NSAssert1(res == errSecItemNotFound, @"SecItemCopyMatching returned %ld!", (long)res);
	}
	
	return nil;
}

+ (void)upgradeAccessibilityForKey:(NSString*)key {
    // Check if the accessibility attributes need to be upgraded
    NSString *derivedKey = [NSString stringWithFormat:@"%@ - %@", [KKKeychain appName], key];
    NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];
    [queryDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    // Add the keys to the search dict
    [queryDictionary setObject:@"service" forKey:(__bridge id)kSecAttrService];
    [queryDictionary setObject:derivedKey forKey:(__bridge id)kSecAttrAccount];
    
    CFTypeRef attrs = nil;
    
    [queryDictionary setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [queryDictionary setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
    OSStatus res = SecItemCopyMatching((__bridge CFDictionaryRef)queryDictionary, &attrs);
    
    if (res == errSecSuccess) {
        NSDictionary *attrsDict = (__bridge NSDictionary*)attrs;
        if (![[attrsDict objectForKey:(__bridge id)kSecAttrAccessible] isEqualToString:(__bridge NSString*)kSecAttrAccessibleAfterFirstUnlock]) {
            // Need to upgrade the accessibility on this key by setting it again
            [KKKeychain setString:[[NSString alloc] initWithData:[attrsDict objectForKey:(__bridge id)kSecValueData] encoding:NSUTF8StringEncoding] forKey:key];
        }
    }
    
    if (attrs)
        CFRelease(attrs);
}


@end
