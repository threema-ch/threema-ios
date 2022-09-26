//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "VideoMessageLoader.h"
#import "UserSettings.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation VideoMessageLoader

- (void)updateDBObject:(BaseMessage<BlobData> *)message with:(NSData *)data {
    [super updateDBObject:message with:data];

    /* Add to photo library */
    if ([UserSettings sharedUserSettings].autoSaveMedia) {
        /* write video to temp. file */
        NSString *filename = [NSString stringWithFormat:@"%f.%@", [[NSDate date] timeIntervalSinceReferenceDate], MEDIA_EXTENSION_VIDEO];
        NSURL *tmpurl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
        if (![data writeToURL:tmpurl atomically:NO]) {
            DDLogWarn(@"Writing movie to temporary file failed");
        } else {
            [[AlbumManager shared] saveMovieToLibraryWithMovieURL:tmpurl completionHandler:^(BOOL success) {
                [[NSFileManager defaultManager] removeItemAtPath:tmpurl.path error:nil];
            }];
        }
    }
}

@end
