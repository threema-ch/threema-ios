//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2021 Threema GmbH
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

#import "NSString+Emoji.h"
#import <CoreText/CoreText.h>

static CFMutableCharacterSetRef *emojiCharacterSet = nil;

@implementation NSString (Emoji)

+ (void)load {
    static CFMutableCharacterSetRef set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = CFCharacterSetCreateMutableCopy(kCFAllocatorDefault, CTFontCopyCharacterSet(CTFontCreateWithName(CFSTR("AppleColorEmoji"), 0.0, NULL)));
        CFCharacterSetRemoveCharactersInString(set, CFSTR(" 0123456789#*"));
    });
    emojiCharacterSet = &set;
}

- (BOOL)isOnlyEmojisMaxCount:(int)maxCount {
    NSString *withoutWhiteSpaceString = [self stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSAttributedString *richText = [[NSAttributedString alloc] initWithString:withoutWhiteSpaceString];
    CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)richText);
    CFIndex glyphCount = CTLineGetGlyphCount(line);
    CFRelease(line);
    
    if (glyphCount > 0 && glyphCount <= maxCount) {
        BOOL __block result = YES;
        [self enumerateSubstringsInRange:NSMakeRange(0, [self length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
            if (![substring containsEmoji]) {
                if (![substring isWhiteSpace]) {
                    *stop = YES;
                    result = NO;
                }
            }
        }];
        return result;
    }
    
    return NO;
}

- (BOOL)containsEmoji {
    return CFStringFindCharacterFromSet((CFStringRef)self, *emojiCharacterSet, CFRangeMake(0, self.length), 0, NULL);
}

- (BOOL)isWhiteSpace {
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    if ([[self stringByTrimmingCharactersInSet: set] length] == 0) {
        return YES;
    }
    return NO;
}

@end
