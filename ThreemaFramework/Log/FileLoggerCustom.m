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
