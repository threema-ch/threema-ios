//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "DocumentManager.h"
#import "AppGroup.h"


@implementation DocumentManager

+ (NSURL *)groupDocumentsDirectory
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[AppGroup groupId]];
}

+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

+ (NSURL *)cacheDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

+ (NSURL *)documentsDirectory {
    return [self groupDocumentsDirectory];
}

+ (NSURL *)databaseDirectory {
    return [self documentsDirectory];
}

+ (unsigned long long)sizeOfObjectAtPath:(NSString*)path {
    
    /* Check if this is a file or directory */
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
        return 0;
    
    if (!isDirectory) {
        /* file */
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        return [fileDictionary fileSize];
    } else {
        /* directory */
        unsigned long long size = 0;
        
        NSDirectoryEnumerator *subPathsEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
        
        NSString *curSubpath;
        while (curSubpath = [subPathsEnumerator nextObject]) {
            NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:curSubpath] error:nil];
            size += [fileDictionary fileSize];
        }
        
        return size;
    }
}

+ (void)removeItemIfExists:(NSURL *)item {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:item.path]) {
        [fileManager removeItemAtURL:item error:nil];
    }
}

+ (void)moveItemIfExists:(NSURL *)source destination:(NSURL *)destination {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:source.path]) {
        [fileManager moveItemAtURL:source toURL:destination error:nil];
    }
}

@end
