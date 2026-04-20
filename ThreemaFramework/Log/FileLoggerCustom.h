#import <Foundation/Foundation.h>

@import CocoaLumberjack;

@interface FileLoggerCustom : DDAbstractLogger {
}

@property (readonly, nonatomic) NSURL *logFile;

- (instancetype)initWithLogFile:(NSURL *)logFile;

@end
