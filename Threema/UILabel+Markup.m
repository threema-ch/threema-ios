//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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

#import "UILabel+Markup.h"
#import "TTTAttributedLabel.h"
#import "UIFont+Traits.h"

@implementation UILabel (Markup)

typedef enum : int {
    StyleTypeBold,
    StyleTypeItalic,
    StyleTypeStrikethrough,
} StyleType;

- (void)applyMarkup {
    NSAttributedString *inputString;
    if (self.text) {
        inputString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    } else {
        inputString = [[NSMutableAttributedString alloc] initWithString:self.text];
    }
    
    NSAttributedString *string = [self applyMarkupFor:inputString];
    
    [self setAttributedText:string];
}

- (NSAttributedString *)applyMarkupFor:(NSAttributedString *)text {
    NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:text];
    if (text.length > 0) {
        NSRange range = NSMakeRange(0, 1);
        NSDictionary *attributes = [mutableString attributesAtIndex:0 effectiveRange:&range];
        self.font = attributes[NSFontAttributeName];
    }
    [self handleItalicTagsIn:mutableString];
    [self handleBoldTagsIn:mutableString];
    [self handleStrikethroughTagsIn:mutableString];
    
    return mutableString;
}

- (void)applyAttributes:(NSDictionary *)attributes on:(NSMutableAttributedString *)attributedString matching:(NSRegularExpression *)regex type:(StyleType)type {
    NSArray *matches = [regex matchesInString:attributedString.string
                                      options:0
                                        range:NSMakeRange(0, [attributedString.string length])];
    
    NSArray *sortedMatches = [matches sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSUInteger loc1 = ((NSTextCheckingResult*)obj1).range.location;
        NSUInteger loc2 = ((NSTextCheckingResult*)obj2).range.location;
        
        if (loc1 > loc2) {
            return NSOrderedAscending;
        } else if (loc1 < loc2) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    for (NSTextCheckingResult *match in sortedMatches) {
        NSRange matchRange = [match range];
        
        NSMutableArray *specialFormat = [NSMutableArray new];
        [attributedString enumerateAttributesInRange:matchRange options:NSAttributedStringEnumerationReverse usingBlock:
         ^(NSDictionary *attributes, NSRange range, BOOL *stop) {
             NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
             UIFont *currentFont = [mutableAttributes objectForKey: NSFontAttributeName];
             if (currentFont.isItalic) {
                 [specialFormat addObject:[NSValue valueWithRange:range]];
             }
         }];
        
        [attributedString addAttributes:attributes range:matchRange];
        
        if (specialFormat.count > 0) {
            for (int i = 0; i < specialFormat.count; i++) {
                NSRange r = [specialFormat[i] rangeValue];
                NSDictionary *newAttributes = @{NSFontAttributeName: [self fontWithTraits:UIFontDescriptorTraitBold|UIFontDescriptorTraitItalic]};
                [attributedString addAttributes:newAttributes range:r];
            }
        }
        
        [attributedString deleteCharactersInRange:NSMakeRange(matchRange.location, 1)];
        [attributedString deleteCharactersInRange:NSMakeRange(matchRange.location + matchRange.length - 2, 1)];
    }
}

- (void)handleStrikethroughTagsIn:(NSMutableAttributedString *)attributedString {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\B~[^\\r\\n]+?~\\B" options:0 error:nil];
    
    NSDictionary *attributes = @{NSBaselineOffsetAttributeName: @0, NSStrikethroughStyleAttributeName: [NSNumber numberWithInt:NSUnderlinePatternSolid | NSUnderlineStyleSingle], kTTTStrikeOutAttributeName: [NSNumber numberWithInt:NSUnderlinePatternSolid | NSUnderlineStyleSingle]};

    [self applyAttributes:attributes on:attributedString matching:regex type:StyleTypeStrikethrough];
}

- (void)handleBoldTagsIn:(NSMutableAttributedString *)attributedString {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\B\\*[^\\r\\n]+?\\*\\B" options:0 error:nil];
    
    NSDictionary *attributes = @{NSFontAttributeName: [self fontWithTraits:UIFontDescriptorTraitBold]};
    [self applyAttributes:attributes on:attributedString matching:regex type:StyleTypeBold];
}

- (void)handleItalicTagsIn:(NSMutableAttributedString *)attributedString {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\b_[^\\r\\n]+?_\\b" options:0 error:nil];
    
    NSDictionary *attributes = @{NSFontAttributeName: [self fontWithTraits:UIFontDescriptorTraitItalic]};
    [self applyAttributes:attributes on:attributedString matching:regex type:StyleTypeItalic];
}

- (UIFont*)fontWithTraits:(UIFontDescriptorSymbolicTraits)traits {
    UIFontDescriptor *fontDescriptor = self.font.fontDescriptor;
    UIFontDescriptor *traitedFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    
    return [UIFont fontWithDescriptor:traitedFontDescriptor size:self.font.pointSize];
}


@end

