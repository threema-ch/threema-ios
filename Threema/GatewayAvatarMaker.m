//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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
#import "EntityManager.h"
#import "Contact.h"
#import "AppGroup.h"
#import "HTTPSURLLoader.h"
#import "BundleUtil.h"

#define AVATAR_EXPIRES_DICTIONARY @"GatewayAvatarExpiresDictionary"
#define AVATAR_REFRESH_TIMESTAMP @"GatewayAvatarLastRefreshDate"
#define AVATAR_CHECK_INTERVAL (24 * 60 * 60)

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

- (void)loadAvatarForId:(NSString *)identity onCompletion:(void (^)(UIImage *))onCompletion onError:(void (^)(NSError *))onError {
    NSURLRequestCachePolicy cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    if (_forceRefresh == NO && [self isExpiredForIdentiy:identity] == NO) {
        onError(nil);
        return;
    }
    
    NSURL *url = [self urlForGatewayId:identity];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:cachePolicy timeoutInterval:kBlobLoadTimeout];
    
    HTTPSURLLoader *httpsLoader = [[HTTPSURLLoader alloc] init];
    [httpsLoader startWithURLRequest:request onCompletion:^(NSData *data) {
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
        for (Contact *contact in gatewayContacts) {
            [self updateIdentity:contact.identity];
        }
        
        [self updateLastRefreshDate];
    }
}

- (void)updateIdentity:(NSString *)identity {
    NSURLRequestCachePolicy cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    if (_forceRefresh == NO && [self isExpiredForIdentiy:identity] == NO) {
        return;
    }

    NSURL *url = [self urlForGatewayId:identity];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:cachePolicy timeoutInterval:kBlobLoadTimeout];

    HTTPSURLLoader *httpsLoader = [[HTTPSURLLoader alloc] init];
    [httpsLoader startWithURLRequest:request onCompletion:^(NSData *data) {
        
        [self.entityManager performSyncBlockAndSafe:^{
            Contact *contact = [self.entityManager.entityFetcher contactForId:identity];
            contact.imageData = data;
        }];
        
        NSString *expires = [httpsLoader.responseHeaderFields objectForKey:@"Expires"];
        if (expires) {
            NSDate *expiresDate = [self parseExpiresString:expires];
            [self updateExpires:expiresDate forIdentity:identity];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationIdentityAvatarChanged object:identity];
        
    } onError:^(NSError *error) {
        if (error.code == 404) {
            [self.entityManager performSyncBlockAndSafe:^{
                Contact *contact = [self.entityManager.entityFetcher contactForId:identity];
                contact.imageData = nil;
            }];

            NSDate *expires = [self expiresIn:AVATAR_CHECK_INTERVAL];
            [self updateExpires:expires forIdentity:identity];
        }
    }];
}

- (NSDate *)expiresIn:(NSInteger)seconds {
    NSDate *expires = [[NSDate date] dateByAddingTimeInterval:seconds];
    return expires;
}

- (NSURL *)urlForGatewayId:(NSString *)gatewayId {
    NSString *urlString = [BundleUtil objectForInfoDictionaryKey:@"ThreemaAvatarURL"];
    urlString = [urlString stringByAppendingString:gatewayId];
    
    return [NSURL URLWithString:urlString];
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
