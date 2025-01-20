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

#import "NSLocale+OverrideLocale.h"
#import "NSObject+Swizzling.h"
#import <objc/runtime.h>


@implementation NSLocale (OverrideLocale)

+ (void)load
{
    [self ttt_swizzleLocales];
}

static NSLocale *ttt_locale = nil;

+ (void)ttt_overrideRuntimeLocale:(NSLocale *)locale
{
    ttt_locale = locale;
}

+ (void)ttt_resetRuntimeLocale
{
    ttt_locale = nil;
}

+ (void)ttt_swizzleLocales
{
    [self ttt_swizzleClassMethod:@selector(autoupdatingCurrentLocale) withReplacement:@selector(ttt_autoupdatingCurrentLocale)];
    [self ttt_swizzleClassMethod:@selector(currentLocale) withReplacement:@selector(ttt_currentLocale)];
    [self ttt_swizzleClassMethod:@selector(systemLocale) withReplacement:@selector(ttt_systemLocale)];
}

+ (id /* NSLocale * */)ttt_autoupdatingCurrentLocale
{
    return ttt_locale ?: [self ttt_autoupdatingCurrentLocale];
}

+ (id /* NSLocale * */)ttt_currentLocale
{
    return ttt_locale ?: [self ttt_currentLocale];
}

+ (id /* NSLocale * */)ttt_systemLocale
{
    return ttt_locale ?: [self ttt_systemLocale];
}

@end
