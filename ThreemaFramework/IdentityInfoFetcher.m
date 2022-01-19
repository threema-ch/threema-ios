//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

#import "IdentityInfoFetcher.h"
#import "ServerAPIConnector.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation IdentityInfoFetcher {
    NSMutableDictionary *prefetchCache;
    NSMutableDictionary *pendingFetchCompletionHandlersByIdentity;
    NSMutableDictionary *pendingFetchErrorHandlersByIdentity;
    NSMutableDictionary *workInfoBlockUnknownCache;

    dispatch_queue_t queue;
}

+ (IdentityInfoFetcher*)sharedIdentityInfoFetcher {
    static IdentityInfoFetcher *instance;
    
    @synchronized (self) {
        if (!instance)
            instance = [[IdentityInfoFetcher alloc] init];
    }
    
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        queue = dispatch_queue_create("ch.threema.identityinfofetcher", DISPATCH_QUEUE_SERIAL);
        prefetchCache = [NSMutableDictionary dictionary];
        pendingFetchCompletionHandlersByIdentity = [NSMutableDictionary dictionary];
        pendingFetchErrorHandlersByIdentity = [NSMutableDictionary dictionary];
        workInfoBlockUnknownCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)prefetchIdentityInfo:(NSSet*)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {    
    ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
    [apiConnector fetchBulkIdentityInfo:[identities allObjects] onCompletion:^(NSArray *identities, NSArray *publicKeys, NSArray *featureMasks, NSArray *states, NSArray *types) {
        dispatch_async(queue, ^{
            // Add results to cache
            for (int i = 0; i < identities.count; i++) {
                [prefetchCache setObject:@{
                    @"publicKey": publicKeys[i],
                    @"featureMask": featureMasks[i],
                    @"state": states[i],
                    @"type": types[i]
                } forKey:identities[i]];
            }
            onCompletion();
        });
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)fetchIdentityInfoFor:(NSString*)identity onCompletion:(void(^)(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask))onCompletion onError:(void(^)(NSError *error))onError {
    
    dispatch_async(queue, ^{
        // Check prefetch cache
        NSDictionary *cachedIdentityInfo = [prefetchCache objectForKey:identity];
        if (cachedIdentityInfo != nil) {
            onCompletion(cachedIdentityInfo[@"publicKey"], cachedIdentityInfo[@"state"], cachedIdentityInfo[@"type"], cachedIdentityInfo[@"featureMask"]);
            return;
        }
        
        // Not in prefetch cache - fetch now
        if (pendingFetchCompletionHandlersByIdentity[identity]) {
            // A fetch request is already pending for this identity.
            // Store the completion/error blocks and call them later to avoid fetching multiple times in parallel.
            [pendingFetchCompletionHandlersByIdentity[identity] addObject:[onCompletion copy]];
            [pendingFetchErrorHandlersByIdentity[identity] addObject:[onError copy]];
        } else {
            // No other fetch pending for this identity
            pendingFetchCompletionHandlersByIdentity[identity] = [NSMutableArray arrayWithObject:[onCompletion copy]];
            pendingFetchErrorHandlersByIdentity[identity] = [NSMutableArray arrayWithObject:[onError copy]];
            
            ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
            DDLogVerbose(@"Fetching identity %@ from server", identity);
            [apiConnector fetchIdentityInfo:identity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
                dispatch_async(queue, ^{
                    for (void(^completionHandler)(NSData*, NSNumber*, NSNumber*, NSNumber*) in pendingFetchCompletionHandlersByIdentity[identity]) {
                        completionHandler(publicKey, state, type, featureMask);
                    }
                    [pendingFetchCompletionHandlersByIdentity removeObjectForKey:identity];
                    [pendingFetchErrorHandlersByIdentity removeObjectForKey:identity];
                });
            } onError:^(NSError *error) {
                dispatch_async(queue, ^{
                    for (void(^errorHandler)(NSError *) in pendingFetchErrorHandlersByIdentity[identity]) {
                        errorHandler(error);
                    }
                    [pendingFetchCompletionHandlersByIdentity removeObjectForKey:identity];
                    [pendingFetchErrorHandlersByIdentity removeObjectForKey:identity];
                });
            }];
        }
    });
}

- (void)fetchWorkIdentitiesInfoInBlockUnknownCheck:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError {
    NSMutableArray *cachedIdentities = [NSMutableArray new];
    BOOL allIdentitiesAreCached = true;
    
    for (NSString *identity in identities) {
        if ([workInfoBlockUnknownCache.allKeys containsObject:identity]) {
            NSDictionary *identityInfo = [workInfoBlockUnknownCache valueForKey:identity];
            if (![identityInfo isEqual:[NSNull null]]) {
                [cachedIdentities addObject:identityInfo];
            }
        } else {
            allIdentitiesAreCached = false;
            break;
        }
    }
    
    if (allIdentitiesAreCached) {
        onCompletion(cachedIdentities);
        return;
    }
        
    ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
    [apiConnector fetchWorkIdentitiesInfo:identities onCompletion:^(NSArray *foundIdentities) {
        dispatch_async(queue, ^{
            
            for (NSDictionary *foundIdentity in foundIdentities) {
                [workInfoBlockUnknownCache setObject:foundIdentity forKey:foundIdentity[@"id"]];
            }
            
            if (foundIdentities.count < identities.count) {
                for (NSString *identity in identities) {
                    if (![foundIdentities containsObject:identity]) {
                        [workInfoBlockUnknownCache setObject:[NSNull null] forKey:identity];
                    }
                }
            }
            
            onCompletion(foundIdentities);
        });
    } onError:^(NSError *error) {
        onError(error);
    }];
}

@end
