//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "BlobUtil.h"
#import "NSString+Hex.h"
#import "UserSettings.h"
#import "BundleUtil.h"

@implementation BlobUtil

+ (NSURLRequest *)urlRequestForBlobId:(NSData *)blobId {
    NSURL *url = [self urlForBlobId:blobId];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobLoadTimeout];
    return request;
}

+ (NSURL *)urlForBlobId:(NSData*)blobId {
    NSString *blobIdHex = [NSString stringWithHexData:blobId];
    NSString *blobFirstByteHex = [blobIdHex substringWithRange:NSMakeRange(0, 2)];
 
    if ([UserSettings sharedUserSettings].enableIPv6) {
        return [NSURL URLWithString:[NSString stringWithFormat:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobURLv6"], blobFirstByteHex, blobIdHex]];
    } else {
        return [NSURL URLWithString:[NSString stringWithFormat:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobURL"], blobFirstByteHex, blobIdHex]];
    }
}

+ (NSURL *)urlForBlobUpload {
    if ([UserSettings sharedUserSettings].enableIPv6) {
        return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobUploadURLv6"]];
    } else {
        return [NSURL URLWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobUploadURL"]];
    }
}

@end
