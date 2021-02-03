//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

#import "BackgroundTaskManagerProxy.h"

static id<BackgroundTaskManagerProtocol> backgroundTaskManager;

@implementation BackgroundTaskManagerProxy

+ (void)wireBackgroundTaskManager:(id<BackgroundTaskManagerProtocol>)backgroundTaskManagerImpl {
    backgroundTaskManager = backgroundTaskManagerImpl;
}

+ (void)cancelBackgroundTaskWithKey:(NSString *)key {
    if (backgroundTaskManager) {
        [backgroundTaskManager cancelBackgroundTaskWithKey:key];
    }
}

+ (void)newBackgroundTaskWithKey:(NSString *)key timeout:(int)timeout completionHandler:(void (^)(void))completionHandler {
    if (backgroundTaskManager) {
        [backgroundTaskManager newBackgroundTaskWithKey:key timeout:timeout completionHandler:completionHandler];
    }
}

+ (NSString *)counterWithIdentifier:(NSString *)identifier {
    if (backgroundTaskManager) {
        return [backgroundTaskManager counterWithIdentifier:identifier];
    }
    return identifier;
}

@end
