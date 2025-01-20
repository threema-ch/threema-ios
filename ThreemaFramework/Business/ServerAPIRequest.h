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

#import <Foundation/Foundation.h>

typedef void(^CompletionCallback)(id jsonObject);
typedef void(^ErrorCallback)(NSError *error);

@interface ServerAPIRequest : NSObject <NSURLSessionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) CompletionCallback onCompletion;
@property (nonatomic, strong) ErrorCallback onError;

+ (void)loadJSONFromAPIPath:(NSString*)apiPath withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)postJSONToAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)loadJSONFromWorkAPIPath:(NSString*)apiPath getParams:(NSString*)getParams withCachePolicy:(NSURLRequestCachePolicy)cachePolicy onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

+ (void)postJSONToWorkAPIPath:(NSString*)apiPath data:(id)jsonObject onCompletion:(CompletionCallback)onCompletion onError:(ErrorCallback)onError;

@end
