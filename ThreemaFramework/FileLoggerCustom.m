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

#import <Foundation/Foundation.h>
#import "FileLoggerCustom.h"
#import "LogFormatterCustom.h"

@implementation FileLoggerCustom {
}

static dispatch_queue_t dispatchQueue;

+ (void)initialize {
    if (dispatchQueue == nil) {
        dispatchQueue = dispatch_queue_create("ch.threema.FileLoggerCustom.main", NULL);
    }
}

- (instancetype)initWithLogFile:(NSURL *)logFile
{
    self = [super init];
    if (self) {
        _logFile = logFile;
        self->_logFormatter = [[LogFormatterCustom alloc] init];
    }
    return self;
}

- (void) logMessage:(DDLogMessage *)logMessage {
    NSString *logMsg = logMessage.message;
    
    if (self->_logFormatter)
        logMsg = [self->_logFormatter formatLogMessage:logMessage];
    
    if (logMsg) {
        
        dispatch_sync(dispatchQueue, ^{
            /* append to log file */
            FILE *f = fopen([[_logFile path] UTF8String], "a");
            if (f != NULL) {
                NSData *strdata = [[NSString stringWithFormat:@"%@\n", logMsg] dataUsingEncoding:NSUTF8StringEncoding];
                fwrite(strdata.bytes, 1, strdata.length, f);
                fsync(fileno(f));
            }
            fclose(f);
        });
    }
}

@end
