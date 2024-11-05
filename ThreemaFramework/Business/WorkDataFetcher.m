//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "WorkDataFetcher.h"
#import "AppGroup.h"
#import "ServerAPIRequest.h"
#import "MyIdentityStore.h"
#import "LicenseStore.h"
#import "ContactStore.h"
#import "ContactEntity.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "MDMSetup.h"
#import "UserSettings.h"
#import "ThreemaError.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define WORK_DEFAULT_CHECK_INTERVAL 86400

@implementation WorkDataFetcher

+ (void)checkUpdateWorkDataForce:(BOOL)force onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError {
    [WorkDataFetcher checkUpdateWorkDataForce:force sendForce:NO onCompletion:onCompletion onError:onError];
}

+ (void)checkUpdateWorkDataForce:(BOOL)force sendForce:(BOOL)sendForce onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError {
    if (![LicenseStore requiresLicenseKey]) {
        if (onCompletion != nil) {
            onCompletion();
        }
        return;
    }

    NSUserDefaults *defaults = [AppGroup userDefaults];
    
    NSDate *lastWorkSync = [defaults objectForKey:@"WorkDataLastSync"];
    NSInteger checkInterval = [defaults integerForKey:@"WorkDataCheckInterval"];
    if (checkInterval == 0)
        checkInterval = WORK_DEFAULT_CHECK_INTERVAL;
    
    /* check if we are within the minimum interval */
    if (!force) {
        if (lastWorkSync != nil && -[lastWorkSync timeIntervalSinceNow] < checkInterval) {
            DDLogInfo(@"Still within work check interval - not syncing");
            if (onCompletion != nil) {
                onCompletion();
            }
            return;
        }
    }
    
    if ([LicenseStore sharedLicenseStore].licenseUsername == nil) {
        if (onCompletion != nil) {
            onCompletion();
        }
        return;
    }

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];

    typedef void (^OnCompletion)();

    void(^finishWorkFetch)(NSDictionary *, OnCompletion) = ^void(NSDictionary *workData, OnCompletion onCompletion) {
        /* Extract check interval, if supplied */
        NSInteger checkInterval = WORK_DEFAULT_CHECK_INTERVAL;
        if ([workData[@"checkInterval"] isKindOfClass:[NSNumber class]]) {
            NSInteger serverCheckInterval = [((NSNumber*)workData[@"checkInterval"]) integerValue];
            DDLogVerbose(@"Server supplied check interval is %ld", (long)serverCheckInterval);
            if (serverCheckInterval > 0)
                checkInterval = serverCheckInterval;
        }

        BOOL refreshWorkContactTableView = false;

        /* Check if there is a company directory */
        if (workData[@"directory"] != [NSNull null] && workData[@"directory"] != nil) {
            if ([mdmSetup disableWorkDirectory] == true) {
                [UserSettings sharedUserSettings].companyDirectory = false;
            } else {
                NSDictionary *directory = workData[@"directory"];
                BOOL enableWorkDirectory = [directory[@"enabled"] boolValue];
                if (enableWorkDirectory != [UserSettings sharedUserSettings].companyDirectory) {
                    [UserSettings sharedUserSettings].companyDirectory = enableWorkDirectory;
                    refreshWorkContactTableView = true;
                }
                [MyIdentityStore sharedMyIdentityStore].directoryCategories = directory[@"cat"];
            }
        } else {
            [UserSettings sharedUserSettings].companyDirectory = false;
        }

        if (workData[@"org"] != [NSNull null]) {
            NSDictionary *org = workData[@"org"];
            if (org[@"name"] != [NSNull null]) {
                NSString *name = org[@"name"];
                if (![name isEqualToString:[MyIdentityStore sharedMyIdentityStore].companyName]) {
                    [MyIdentityStore sharedMyIdentityStore].companyName = name;
                    refreshWorkContactTableView = true;
                }
            }
        }

        if (refreshWorkContactTableView == true) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshWorkContactTableView object:nil];
        }

        [defaults setObject:[NSDate date] forKey:@"WorkDataLastSync"];
        [defaults setInteger:checkInterval forKey:@"WorkDataCheckInterval"];
        [defaults synchronize];
        if (onCompletion != nil)
            dispatch_async(dispatch_get_main_queue(), ^{
                onCompletion();
            });
    };

    // Send Work fetch request with license username/password and list of identities in local contact list
    NSArray *contactIds = [[ContactStore sharedContactStore] allIdentities];
    NSDictionary *request = @{
                              @"username": [LicenseStore sharedLicenseStore].licenseUsername,
                              @"password": [LicenseStore sharedLicenseStore].licensePassword,
                              @"contacts": contactIds
                              };
    
    [ServerAPIRequest postJSONToWorkAPIPath:@"fetch2" data:request onCompletion:^(id jsonObject) {
        NSDictionary *workData = (NSDictionary*)jsonObject;
        
        DDLogVerbose(@"Work data: %@", workData);
        
        [mdmSetup applyThreemaMdm:workData sendForce:sendForce];

        /* Extract logo URL, if supplied */
        if (workData[@"logo"] != nil && [workData isKindOfClass:[NSDictionary class]]) {
            NSDictionary *logo = workData[@"logo"];
            NSString *oldLogoLightUrl = [MyIdentityStore sharedMyIdentityStore].licenseLogoLightUrl;
            NSString *oldLogoDarkUrl = [MyIdentityStore sharedMyIdentityStore].licenseLogoDarkUrl;
            
            if (logo[@"light"] == [NSNull null])
                [MyIdentityStore sharedMyIdentityStore].licenseLogoLightUrl = nil;
            else
                [MyIdentityStore sharedMyIdentityStore].licenseLogoLightUrl = logo[@"light"];
            
            if (logo[@"dark"] == [NSNull null])
                [MyIdentityStore sharedMyIdentityStore].licenseLogoDarkUrl = nil;
            else
                [MyIdentityStore sharedMyIdentityStore].licenseLogoDarkUrl = logo[@"dark"];
            
            if (oldLogoLightUrl != [MyIdentityStore sharedMyIdentityStore].licenseLogoLightUrl || 
                oldLogoDarkUrl != [MyIdentityStore sharedMyIdentityStore].licenseLogoDarkUrl) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationColorThemeChanged object:nil];
            }
        }
        
        /* Extract support URL, if supplied */
        if (workData[@"support"] == [NSNull null])
            [MyIdentityStore sharedMyIdentityStore].licenseSupportUrl = nil;
        else
            [MyIdentityStore sharedMyIdentityStore].licenseSupportUrl = workData[@"support"];
        
        /* Process supplied contacts */
        if (ProcessInfoHelper.isRunningForScreenshots)  {
            // do not update for screenshots
            if (onCompletion != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onCompletion();
                });
            }
        } else {
            NSArray *workContacts = workData[@"contacts"];
            NSMutableSet *workContactIds = [NSMutableSet set];
            if (workContacts != nil) {
                
                NSMutableSet *batchAddWorkContacts = [[NSMutableSet alloc] initWithCapacity:workContacts.count];
                
                for (NSDictionary *workContact in workContacts) {
                    NSString *firstName = nil;
                    NSString *lastName = nil;
                    NSString *csi = nil;
                    NSString *jobTitle = nil;
                    NSString *department = nil;
                    
                    if (workContact[@"first"] != nil && workContact[@"first"] != [NSNull null]) {
                        firstName = workContact[@"first"];
                    }
                    
                    if (workContact[@"last"] != nil && workContact[@"last"] != [NSNull null]) {
                        lastName = workContact[@"last"];
                    }
                    
                    if (workContact[@"csi"] != nil && workContact[@"csi"] != [NSNull null]) {
                        csi = workContact[@"csi"];
                    }
                    
                    if (workContact[@"jobTitle"] != nil && workContact[@"jobTitle"] != [NSNull null]) {
                        jobTitle = workContact[@"jobTitle"];
                    }
                    
                    if (workContact[@"department"] != nil && workContact[@"department"] != [NSNull null]) {
                        department = workContact[@"department"];
                    }
                                        
                    NSString *identity = workContact[@"id"];
                    NSData *publicKey = [[NSData alloc] initWithBase64EncodedString:workContact[@"pk"] options:0];
                    
                    BatchAddWorkContact *batchAddWorkContact = [[BatchAddWorkContact alloc] initWithIdentity:identity publicKey:publicKey firstName:firstName lastName:lastName csi:csi jobTitle:jobTitle department:department];
                    
                    [batchAddWorkContacts addObject:batchAddWorkContact];
                    [workContactIds addObject:identity];
                }

                [[ContactStore sharedContactStore] batchAddWorkContactsWithBatchAddContacts:[batchAddWorkContacts allObjects] completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        DDLogError(@"Adding work contacts failed: %@", error);

                        if (onError != nil) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                onError(error);
                            });
                        }
                        return;
                    }

                    finishWorkFetch(workData, onCompletion);
                }];
            }
            else {
                finishWorkFetch(workData, onCompletion);
            }
        }
    } onError:^(NSError *error) {
        DDLogError(@"Work API fetch failed: %@", error);
        if (onError != nil)
            onError(error);
    }];
}

+ (void)checkUpdateThreemaMDM:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError {
    if ([LicenseStore requiresLicenseKey] == NO) {
        DDLogWarn(@"No license is required");
        onCompletion();
        return;
    }

    NSString *username = [LicenseStore sharedLicenseStore].licenseUsername;
    NSString *password = [LicenseStore sharedLicenseStore].licensePassword;
    if (username != nil && password != nil) {
        NSDictionary *request = @{
                              @"username": username,
                              @"password": password,
                              @"contacts": @[],
                              };

        [ServerAPIRequest postJSONToWorkAPIPath:@"fetch2" data:request onCompletion:^(id jsonObject) {
            NSDictionary *workData = (NSDictionary*)jsonObject;
        
            MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
            [mdmSetup applyThreemaMdm:workData sendForce:NO];
        
            onCompletion();
        } onError:^(NSError *error) {
            DDLogError(@"Work API fetch failed: %@", error);
            onError(error);
        }];
    }
    else {
        NSError *error = [ThreemaError threemaError:@"Missing credentials (user name or password)"];
        DDLogError(@"Work API fetch failed: %@", error);
        onError(error);
    }
}

@end
