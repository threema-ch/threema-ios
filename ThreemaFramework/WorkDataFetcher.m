//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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
#import "Contact.h"
#import "EntityManager.h"
#import "MDMSetup.h"
#import "UserSettings.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define WORK_DEFAULT_CHECK_INTERVAL 86400

@implementation WorkDataFetcher

+ (void)checkUpdateWorkDataForce:(BOOL)force onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError {
    if (![LicenseStore requiresLicenseKey]) {
        if (onCompletion != nil)
            onCompletion();
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
            return;
        }
    }
    
    if ([LicenseStore sharedLicenseStore].licenseUsername == nil) {
        if (onCompletion != nil)
            onCompletion();
        return;
    }
    
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
        
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
        [mdmSetup applyThreemaMdm:workData];
        
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
        NSArray *workContacts = workData[@"contacts"];
        NSMutableSet *workContactIds = [NSMutableSet set];
        if (workContacts != nil) {
            for (NSDictionary *workContact in workContacts) {
                Contact *contact = [[ContactStore sharedContactStore] addContactWithIdentity:workContact[@"id"] publicKey:[[NSData alloc] initWithBase64EncodedString:workContact[@"pk"] options:0] cnContactId:nil verificationLevel:kVerificationLevelUnverified state:nil type:@1 featureMask:nil alerts:NO];
                if ((contact.firstName == nil && contact.lastName == nil) || contact.cnContactId == nil) {
                    if (workContact[@"first"] != nil && workContact[@"first"] != [NSNull null] && workContact[@"last"] != nil && workContact[@"last"] != [NSNull null]) {
                        NSString *first = workContact[@"first"];
                        NSString *last = workContact[@"last"];
                        if (first.length > 0 || last.length > 0) {
                            EntityManager *entityManager = [[EntityManager alloc] init];
                            [entityManager performSyncBlockAndSafe:^{
                                contact.firstName = first;
                                contact.lastName = last;
                            }];
                        }
                    }
                }
                [workContactIds addObject:workContact[@"id"]];
            }
        }
        
        [[ContactStore sharedContactStore] updateFeatureMasksForIdentities:[workContactIds allObjects] onCompletion:^{
        } onError:^(NSError *error) {
        }];
        
        /* Get all work verified contacts from DB and set those that have not been supplied in this sync back to non-work */
        NSArray *allContacts = [[ContactStore sharedContactStore] allContacts];
        for (Contact *contact in allContacts) {
            BOOL isWorkContact = [workContactIds containsObject:contact.identity];
            if (contact.workContact == nil || contact.workContact.boolValue != isWorkContact) {
                [[ContactStore sharedContactStore] setWorkContact:contact workContact:isWorkContact];
            }
        }
        
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
        if (workData[@"directory"] != [NSNull null]) {
            if (workData[@"directory"] != nil) {
                NSDictionary *directory = workData[@"directory"];
                BOOL enableWorkDirectory = [directory[@"enabled"] boolValue];
                if (enableWorkDirectory != [UserSettings sharedUserSettings].companyDirectory) {
                    [UserSettings sharedUserSettings].companyDirectory = [directory[@"enabled"] boolValue];
                    refreshWorkContactTableView = true;
                }
                [MyIdentityStore sharedMyIdentityStore].directoryCategories = directory[@"cat"];
            } else {
                [UserSettings sharedUserSettings].companyDirectory = false;
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
            onCompletion();
    } onError:^(NSError *error) {
        DDLogError(@"Work API fetch failed: %@", error);
        if (onError != nil)
            onError(error);
    }];
}

+ (void)checkUpdateThreemaMDM:(void(^)(void))onCompletion onError:(void(^)(NSError*))onError {
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
            [mdmSetup applyThreemaMdm:workData];
        
            onCompletion();
        } onError:^(NSError *error) {
            DDLogError(@"Work API fetch failed: %@", error);
            onError(error);
        }];
    } else {
        onError(nil);
    }
}

@end
