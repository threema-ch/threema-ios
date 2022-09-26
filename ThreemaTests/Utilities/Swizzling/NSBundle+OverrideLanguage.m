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

#import "NSBundle+OverrideLanguage.h"
#import "NSObject+Swizzling.h"

@implementation NSBundle (OverrideLanguage)

+ (void)load
{
    [self ttt_swizzleLanguageBundles];
}

+ (void)ttt_swizzleLanguageBundles
{
    [self ttt_swizzleInstanceMethod:@selector(localizedStringForKey:value:table:)
                    withReplacement:@selector(ttt_localizedStringForKey:value:table:)];
}

static NSBundle *ttt_languageBundle = nil;

+ (void)ttt_overrideLanguage:(NSString *)language
{
    NSString *path = [[NSBundle mainBundle] pathForResource:language ofType:@"lproj"];
    ttt_languageBundle = [NSBundle bundleWithPath:path];
}

+ (void)ttt_resetLanguage
{
    ttt_languageBundle = nil;
}

- (NSString *)ttt_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName NS_FORMAT_ARGUMENT(1);
{
    if (ttt_languageBundle)
    {
        return [ttt_languageBundle ttt_localizedStringForKey:key value:value table:tableName];
    }
    
    return [self ttt_localizedStringForKey:key value:value table:tableName];
}
@end
