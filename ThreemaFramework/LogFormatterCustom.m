//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

#import "LogFormatterCustom.h"
#import <Foundation/Foundation.h>

@implementation LogFormatterCustom {
    NSString *processName;
    NSString *processID;
}

static NSString *dateFormatString = @"yyyy-MM-dd HH:mm:ss.SSSZZZZZ";

- (instancetype)init
{
    self = [super init];
    if (self) {
        processName = [[NSProcessInfo processInfo] processName];
        processID = [NSString stringWithFormat:@"%i", (int)getpid()];
    }
    return self;
}

- (NSString *)stringFromDate:(NSDate *)date {
    atomic_fetch_add_explicit(&atomicLoggerCount, 0, memory_order_relaxed);
    
    if (atomicLoggerCount <= 1) {
        // Single-threaded mode.
        
        if (threadUnsafeDateFormatter == nil) {
            threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
            [threadUnsafeDateFormatter setDateFormat:dateFormatString];
        }
        
        return [threadUnsafeDateFormatter stringFromDate:date];
    } else {
        // Multi-threaded mode.
        // NSDateFormatter is NOT thread-safe.
        
        NSString *key = @"MyCustomFormatter_NSDateFormatter";
        
        NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
        NSDateFormatter *dateFormatter = [threadDictionary objectForKey:key];
        
        if (dateFormatter == nil) {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:dateFormatString];
            
            [threadDictionary setObject:dateFormatter forKey:key];
        }
        
        return [dateFormatter stringFromDate:date];
    }
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *logLevel;
    switch (logMessage->_flag) {
        case DDLogFlagError    : logLevel = @"[Err]"; break;
        case DDLogFlagWarning  : logLevel = @"[Warn]"; break;
        case DDLogFlagInfo     : logLevel = @"[Info]"; break;
        case DDLogFlagDebug    : logLevel = @"[Debug]"; break;
        case DDLogFlagNotice   : logLevel = @"[Notice]"; break;
        default                : logLevel = @"[Verbose]"; break;
    }
    
    NSString *dateAndTime = [self stringFromDate:logMessage.timestamp];
    
    return [NSString stringWithFormat:@"%@ %@[%@:%@] %@:%lu %@ %@", dateAndTime, processName, processID, logMessage->_threadID, logMessage->_fileName, logMessage->_line, logLevel, logMessage->_message];
}

- (void)didAddToLogger:(id <DDLogger>)logger {
    atomic_fetch_add_explicit(&atomicLoggerCount, 1, memory_order_relaxed);
}

- (void)willRemoveFromLogger:(id <DDLogger>)logger {
    atomic_fetch_sub_explicit(&atomicLoggerCount, 1, memory_order_relaxed);
}

@end
