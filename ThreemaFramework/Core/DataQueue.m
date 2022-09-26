//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

#import "DataQueue.h"

@implementation DataQueue {
    NSMutableArray *queue;
    dispatch_queue_t dispatchQueue;
}

- (instancetype)init {
    if (self = [super init]) {
        queue = [[NSMutableArray alloc] init];

        dispatchQueue = dispatch_queue_create("ch.threema.DataQueue", NULL);
    }
    return self;
}

- (void)enqueue:(NSData *)data {
    dispatch_sync(dispatchQueue, ^{
        [queue addObject:data];
    });
}

- (NSData *)dequeue {
    __block NSData *item;
    dispatch_sync(dispatchQueue, ^{
        if ([queue count] > 0) {
            item = [queue objectAtIndex:0];
            if (item != nil) {
                [queue removeObjectAtIndex:0];
            }
        }
    });
    return item;
}

- (void)clear {
    dispatch_sync(dispatchQueue, ^{
        [queue removeAllObjects];
    });
}

@end
