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

#import <Foundation/Foundation.h>
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "BaseMessage.h"
#import "BlobOrigin.h"

@interface BlobMessageLoader : NSObject

@property EntityManager *entityManager;

- (void)startWithMessage:(BaseMessage<BlobData> *)message onCompletion:(void (^)(BaseMessage<BlobData> *loadedMessage))onCompletion onError:(void (^)(NSError *error))onError;

- (void)updateDBObject:(BaseMessage<BlobData> *)message with:(NSData *)data;

@end
