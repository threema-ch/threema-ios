//
// Copyright 2011-2012 Kosher Penguin LLC
// Created by Adar Porat (https://github.com/aporat) on 1/16/2012.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//		http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "KKPasscodeLock.h"
#import "KKKeychain.h"
#import "KKPasscodeViewController.h"
#import "Utils.h"
#import "BundleUtil.h"
#import "AppGroup.h"

static KKPasscodeLock *sharedLock = nil;


@implementation KKPasscodeLock

@synthesize eraseOption = _eraseOption;
@synthesize attemptsAllowed = _attemptsAllowed;
@synthesize lastUnlockTime = _lastUnlockTime;

+ (KKPasscodeLock*)sharedLock
{
	@synchronized(self) {
		if (sharedLock == nil) {
			sharedLock = [[self alloc] init];
			sharedLock.eraseOption = YES;
			sharedLock.attemptsAllowed = 5;
            sharedLock.lastUnlockTime = 0;
		}
	}
	return sharedLock;
}

- (BOOL)isPasscodeRequired
{
	return [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
}

- (BOOL)isTouchIdOn {
    return [[KKKeychain getStringForKey:@"touch_id_on"] isEqualToString:@"YES"];
}

- (BOOL)isWithinGracePeriod {
    int gracePeriod = [[KKKeychain getStringForKey:@"grace_period"] intValue];
    if (gracePeriod > 0) {
        time_t uptime = [Utils systemUptime];
        if (uptime > 0 && self.lastUnlockTime > 0 && (uptime - self.lastUnlockTime) < gracePeriod)
            return YES;
    }
    
    return NO;
}

- (void)setDefaultSettings
{
	if (![KKKeychain getStringForKey:@"passcode_on"]) {
		[KKKeychain setString:@"NO" forKey:@"passcode_on"];
	}
	
	if (![KKKeychain getStringForKey:@"erase_data_on"]) {
		[KKKeychain setString:@"NO" forKey:@"erase_data_on"];
	}
	
	if (![KKKeychain getStringForKey:@"grace_period"]) {
		[KKKeychain setString:@"0" forKey:@"grace_period"];
    }
    
    if (![KKKeychain getStringForKey:@"touch_id_on"]) {
        [KKKeychain setString:@"NO" forKey:@"touch_id_on"];
    }
}

- (void)upgradeAccessibility {
    [KKKeychain upgradeAccessibilityForKey:@"passcode"];
    [KKKeychain upgradeAccessibilityForKey:@"passcode_on"];
    [KKKeychain upgradeAccessibilityForKey:@"erase_data_on"];
    [KKKeychain upgradeAccessibilityForKey:@"grace_period"];
    [KKKeychain upgradeAccessibilityForKey:@"touch_id_on"];
}

- (void)disablePasscode {
    [KKKeychain setString:@"NO" forKey:@"passcode_on"];
    [KKKeychain setString:@"NO" forKey:@"erase_data_on"];
    [KKKeychain setString:@"0" forKey:@"grace_period"];
    [KKKeychain setString:@"NO" forKey:@"touch_id_on"];
    [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
    [[AppGroup userDefaults] synchronize];
}

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value
{
    static NSBundle *bundle = nil;
    if (bundle == nil)
    {
        NSString *bundlePath = [[BundleUtil frameworkBundle] pathForResource:@"KKPasscodeLock" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:bundlePath] ?: [NSBundle mainBundle];
    }
    
    value = [bundle localizedStringForKey:key value:value table:nil];

    return [[BundleUtil mainBundle] localizedStringForKey:key value:value table:nil];
}

- (void)updateLastUnlockTime {
    self.lastUnlockTime = [Utils systemUptime];
}

@end
