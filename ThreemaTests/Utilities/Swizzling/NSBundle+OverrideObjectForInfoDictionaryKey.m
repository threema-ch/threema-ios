//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "NSBundle+OverrideObjectForInfoDictionaryKey.h"
#import "NSObject+Swizzling.h"

@implementation NSBundle (OverrideObjectForInfoDictionaryKey)

static NSMutableDictionary *dictionary = nil;

+ (void)load
{
    [self ttt_swizzleMethods];
    
    dictionary = [NSMutableDictionary dictionary];
}

+ (void)ttt_swizzleMethods
{
    [self ttt_swizzleInstanceMethod:@selector(objectForInfoDictionaryKey:)
                    withReplacement:@selector(ttt_objectForInfoDictionaryKey:)];
}

+ (void)ttt_overrideKey:(NSString *)key withValue:(NSString *) value
{
    [dictionary setObject: value forKey: key];
}

+ (void)ttt_reset
{
    dictionary = nil;
}

- (NSString *)ttt_objectForInfoDictionaryKey:(NSString *)key
{
    if (dictionary)
    {
        NSString *value = [dictionary valueForKey: key];
        if (value) {
            return value;
        }
    }
    
    return [self ttt_objectForInfoDictionaryKey:key];
}
@end
