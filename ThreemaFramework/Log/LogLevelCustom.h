#define DD_LEGACY_MACROS 0
#define LOG_FLAG_NOTICE (1 << 5)
#define DDLogNotice(frmt, ...)  LOG_MAYBE(YES, ddLogLevel, LOG_FLAG_NOTICE,  0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

@import CocoaLumberjack;

static uint const DDLogFlagNotice = LOG_FLAG_NOTICE;
static uint const DDLogLevelNotice = DDLogFlagError | DDLogFlagWarning | DDLogFlagNotice;
