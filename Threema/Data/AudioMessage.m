//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

#import "AudioMessage.h"
#import "AudioData.h"
#import "NSString+Hex.h"
#import "UTIConverter.h"
#import "Utils.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation AudioMessage

@dynamic duration;
@dynamic encryptionKey;
@dynamic progress;
@dynamic audioBlobId;
@dynamic audioSize;
@dynamic audio;

- (NSString*)logText {
    int seconds = self.duration.intValue;
    int minutes = seconds / 60;
    seconds -= minutes * 60;
    return [NSString stringWithFormat:@"%@ (%02d:%02d, %@)", NSLocalizedString(@"audio", nil), minutes, seconds, [self blobGetFilename]];
}

- (NSString*)previewText {
    return [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"audio", nil), [Utils timeStringForSeconds:self.duration.integerValue]];
}

#pragma mark - BlobData

- (NSData *)blobGetData {
    if (self.audio) {
        return self.audio.data;
    }
    
    return nil;
}

- (NSData *)blobGetId {
    return self.audioBlobId;
}

- (NSData *)blobGetEncryptionKey {
    return self.encryptionKey;
}

- (NSNumber *)blobGetSize {
    return self.audioSize;
}

- (void)blobSetData:(NSData *)data {
    AudioData *dbData = [NSEntityDescription
              insertNewObjectForEntityForName:@"AudioData"
              inManagedObjectContext:self.managedObjectContext];

    dbData.data = data;
    self.audio = dbData;
}

- (NSData *)blobGetThumbnail {
    return nil;
}

- (NSString *)blobGetUTI {
    return UTTYPE_AUDIO;
}

- (NSString *)blobGetFilename {
    return [NSString stringWithFormat: @"%@.%@", [NSString stringWithHexData:self.id], MEDIA_EXTENSION_AUDIO];
}

- (NSString *)blobGetWebFilename {
    return [NSString stringWithFormat: @"threema-%@-audio.%@", [DateFormatter getDateForWeb:self.date], MEDIA_EXTENSION_AUDIO];
}

- (void)blobUpdateProgress:(NSNumber *)progress {
    self.progress = progress;
}

- (NSNumber *)blobGetProgress {
    return self.progress;
}

- (NSString *)getExternalFilename {
    return [[self audio] getFilename];
}

#pragma mark - Misc

#ifdef DEBUG
#else
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", [self class], self, @"duration = ", self.duration.description, @"encryptionKey = ", @"***", @"progress = ", self.progress.description, @"audioBlobId = ", @"***", @"audioSize = ", self.audioSize.description, @"audio = ", self.audio.description];
}
#endif

@end
