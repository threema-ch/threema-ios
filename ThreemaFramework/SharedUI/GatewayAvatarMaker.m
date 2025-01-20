//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import "GatewayAvatarMaker.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ContactEntity.h"
#import "AppGroup.h"
#import "HTTPSURLLoader.h"
#import "BundleUtil.h"
#import "UserSettings.h"

#define AVATAR_EXPIRES_DICTIONARY @"GatewayAvatarExpiresDictionary"
#define AVATAR_REFRESH_TIMESTAMP @"GatewayAvatarLastRefreshDate"
#define AVATAR_CHECK_INTERVAL (24 * 60 * 60)

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface GatewayAvatarMaker ()

@property (nonatomic) EntityManager *entityManager;
@property (nonatomic) NSMutableDictionary *expiresDictionary;

@property BOOL forceRefresh;

@end

@implementation GatewayAvatarMaker

+ (instancetype)gatewayAvatarMaker {
    return [[GatewayAvatarMaker alloc] init];
}

- (void)refresh {
    _forceRefresh = NO;

    [self loadCache];
}

- (void)refreshForced {
    _forceRefresh = YES;
    
    [self deleteExpires];
    [self loadCache];
}

- (void)loadAndSaveAvatarForId:(NSString *)identity {
    _forceRefresh = YES;
    [self updateIdentity:identity];
}

- (void)loadAvatarDataForId:(NSString *)identity onCompletion:(void (^)(NSData *, NSString *expires))onCompletion onError:(void (^)(NSError *))onError {
    NSURLRequestCachePolicy cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    if (_forceRefresh == NO && [self isExpiredForIdentiy:identity] == NO) {
        onError(nil);
        return;
    }
    
    [self urlForGatewayId:identity onCompletion:^(NSURL *url) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:cachePolicy timeoutInterval:kBlobLoadTimeout];
        [[AuthTokenManager shared] obtainTokenWithCompletionHandler:^(NSString * _Nullable authToken, NSError * _Nullable error) {
            if (error != nil) {
                onError(error);
                return;
            } else {
                if (authToken != nil) {
                    [request addValue:[NSString stringWithFormat:@"Token %@", authToken] forHTTPHeaderField:@"Authorization"];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    HTTPSURLLoader *httpsLoader = [[HTTPSURLLoader alloc] init];
                    [httpsLoader startWithURLRequest:request onCompletion:^(NSData *data) {
                        onCompletion(data, [httpsLoader.responseHeaderFields objectForKey:@"Expires"]);
                    } onError:^(NSError *loaderError) {
                        onError(loaderError);
                    }];
                });
            }
        }];
    } onError:^(NSError *error) {
        onError(error);
    }];    
}

- (void)loadAvatarForId:(NSString *)identity onCompletion:(void (^)(UIImage *))onCompletion onError:(void (^)(NSError *))onError {
    [self loadAvatarDataForId:identity onCompletion:^(NSData *data, NSString *expires) {
        onCompletion([UIImage imageWithData:data]);
    } onError:^(NSError *error) {
        onError(error);
    }];  
}

- (EntityManager *)entityManager {
    if (_entityManager == nil) {
        _entityManager = [[EntityManager alloc] init];
    }
    
    return _entityManager;
}

- (NSMutableDictionary *)expiresDictionary {
    if (_expiresDictionary == nil) {
        NSDictionary *currentDictionary = [[AppGroup userDefaults] objectForKey:AVATAR_EXPIRES_DICTIONARY];
        if (currentDictionary) {
            _expiresDictionary = [NSMutableDictionary dictionaryWithDictionary:currentDictionary];
        } else {
            _expiresDictionary = [NSMutableDictionary dictionary];
        }
    }
    
    return _expiresDictionary;
}

- (void)loadCache {
    NSArray *gatewayContacts = [self.entityManager.entityFetcher allGatewayContacts];

    if ([gatewayContacts count] > 0) {
        for (ContactEntity *contact in gatewayContacts) {
            [self updateIdentity:contact.identity];
        }
        
        [self updateLastRefreshDate];
    }
}

- (void)updateIdentity:(NSString *)identity {
    [self loadAvatarDataForId:identity onCompletion:^(NSData *data, NSString *expires) {
        [self updateProfileImage:data identity:identity];

        if (expires) {
            NSDate *expiresDate = [self parseExpiresString:expires];
            [self updateExpires:expiresDate forIdentity:identity];
        }
        
    } onError:^(NSError *error) {
        if (error.code == 404) {
            [self updateProfileImage:nil identity:identity];

            NSDate *expires = [self expiresIn:AVATAR_CHECK_INTERVAL];
            [self updateExpires:expires forIdentity:identity];
        }
    }];
}

/**
 Update and reflect profile image of a contact it has changed.

 @param image: Profile image, is it null profile image will be delete
 @param identity: Threema ID (Gateway ID) of the contact
 */
- (void)updateProfileImage:(nullable NSData *)image identity:(nonnull NSString *)identity {
    __block BOOL hasChanged = NO;

    [self.entityManager performBlockAndWait:^{
        ContactEntity *contact = [self.entityManager.entityFetcher contactForId:identity];

        if ((image && [contact.imageData isEqualToData:image] == NO) || (image == nil && contact.imageData)) {
            [self.entityManager performSyncBlockAndSafe:^{
                contact.imageData = image;
            }];

            hasChanged = YES;
        }
    }];

    if (hasChanged) {
        [[ContactStore sharedContactStore] reflectContact:identity];
    }
}

- (NSDate *)expiresIn:(NSInteger)seconds {
    NSDate *expires = [[NSDate date] dateByAddingTimeInterval:seconds];
    return expires;
}

- (void)urlForGatewayId:(NSString *)gatewayId onCompletion:(void (^)(NSURL *))onCompletion onError:(void (^)(NSError *))onError {
    [[ServerInfoProviderFactory makeServerInfoProvider] avatarServerWithIpv6:NO completionHandler:^(AvatarServerInfo * _Nullable avatarServerInfo, NSError * _Nullable error) {
        if (error != nil) {
            onError(error);
        } else {
            NSURL *url = [NSURL URLWithString:avatarServerInfo.url];
            onCompletion([url URLByAppendingPathComponent:gatewayId]);
        }
    }];
}

- (NSDate *)parseExpiresString:(NSString *)expiresString {
    static NSDateFormatter *rfc1123Formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rfc1123Formatter = [[NSDateFormatter alloc] init];
        rfc1123Formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        rfc1123Formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        rfc1123Formatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
    });
    
    return [rfc1123Formatter dateFromString:expiresString];
}

- (void)updateExpires:(NSDate *)expires forIdentity:(NSString *)identity {
    [self.expiresDictionary setObject:expires forKey:identity];
    
    [[AppGroup userDefaults] setObject:self.expiresDictionary forKey:AVATAR_EXPIRES_DICTIONARY];
    [[AppGroup userDefaults] synchronize];
}

- (BOOL)isExpiredForIdentiy:(NSString *)identity {
    NSDate *expires = [self.expiresDictionary objectForKey:identity];
    NSDate *now = [NSDate date];
    if (expires && [now timeIntervalSinceDate:expires] < 0.0) {
        return NO;
    }
    
    return YES;
}

- (void)deleteExpires {
    [[AppGroup userDefaults] removeObjectForKey:AVATAR_EXPIRES_DICTIONARY];
    [[AppGroup userDefaults] synchronize];
}

- (void)updateLastRefreshDate {
    NSDate *date = [NSDate date];
    [[AppGroup userDefaults] setObject:date forKey:AVATAR_REFRESH_TIMESTAMP];
    [[AppGroup userDefaults] synchronize];
}

- (NSDate *)lastRefreshDate {
    return [[AppGroup userDefaults] objectForKey:AVATAR_REFRESH_TIMESTAMP];
}

@end
