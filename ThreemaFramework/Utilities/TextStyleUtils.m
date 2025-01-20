//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

#import "TextStyleUtils.h"
#import "ContactStore.h"
#import "ContactEntity.h"
#import "MyIdentityStore.h"
#import "UILabel+Markup.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

static NSString *regex = @"@\\[[0-9A-Z*@]{8}\\]";

@implementation TextStyleUtils

+ (NSAttributedString*)makeAttributedStringFromString:(NSString*)string withFont:(UIFont*)font textColor:(UIColor *)textColor isOwn:(BOOL)isOwn application:(UIApplication *)application {
    if (string == nil)
        return nil;
    
    NSTextCheckingTypes textCheckingTypes = NSTextCheckingTypeLink;
    
    if (application) {
        static dispatch_once_t onceToken;
        static BOOL canOpenPhoneLinks;
        dispatch_once(&onceToken, ^{
            canOpenPhoneLinks = [application canOpenURL:[NSURL URLWithString:@"tel:0"]];
        });
        if (canOpenPhoneLinks)
            textCheckingTypes |= NSTextCheckingTypePhoneNumber;
    }
    
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:textCheckingTypes error:NULL];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor ? textColor : UIColor.labelColor}];
    [detector enumerateMatchesInString:string options:0 range:NSMakeRange(0, string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        attributes[@"ZSWTappableLabelTappableRegionAttributeName"] = @YES;
        attributes[@"ZSWTappableLabelHighlightedForegroundAttributeName"] = Colors.textLink;
        attributes[NSForegroundColorAttributeName] = Colors.textLink;
        attributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
        attributes[@"NSTextCheckingResult"] = result;
        [attributedString addAttributes:attributes range:result.range];
    }];
    
    return attributedString;
}

+ (NSString *)makeMentionsStringForText:(NSString *)text {
    if (!text) {
        return text;
    }
    
    NSRegularExpression *mentionsRegex = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
    
    BOOL finished = NO;
    int lastNotFoundIndex = -1;
    
    while (!finished) {
        NSArray *mentionResults = [mentionsRegex matchesInString:text options:NSMatchingReportCompletion range:NSMakeRange(0, [text length])];
        
        NSTextCheckingResult *result = nil;
        if (lastNotFoundIndex == -1) {
            result = mentionResults.firstObject;
        } else {
            if (mentionResults.count >= lastNotFoundIndex+2) {
                result = mentionResults[lastNotFoundIndex+1];
            }
        }
        
        if (!result) {
            finished = YES;
            break;
        }
        
        NSString *mentionTag = [text substringWithRange:result.range];
        NSString *identity = [mentionTag substringWithRange:NSMakeRange(2, 8)].uppercaseString;
        
        ContactEntity *contact = [[ContactStore sharedContactStore] contactForIdentity:identity];
        
        if (contact || [identity isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]] || [identity isEqualToString:@"@@@@@@@@"]) {
            NSString *displayName = [[MyIdentityStore sharedMyIdentityStore] displayName];
            if (contact) {
                displayName = contact.mentionName;
            } else if ([identity isEqualToString:@"@@@@@@@@"]) {
                displayName = [BundleUtil localizedStringForKey:@"all"];
            }
            text = [text stringByReplacingCharactersInRange:result.range withString:[NSString stringWithFormat:@"@%@", displayName]];
        } else {
            text = [text stringByReplacingCharactersInRange:result.range withString:[NSString stringWithFormat:@"@%@", identity]];
            if (lastNotFoundIndex == -1) {
                lastNotFoundIndex = 0;
            } else {
                lastNotFoundIndex++;
            }
        }
    }
    
    return text;
}

+ (NSAttributedString *)makeMentionsAttributedStringForAttributedString:(NSMutableAttributedString *)text textFont:(UIFont *)textFont atColor:(UIColor *)atColor messageInfo:(int)messageInfo application:(UIApplication *)application {
    NSRegularExpression *mentionsRegex = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSMutableAttributedString *origTextAttributed = text;
    BOOL finished = NO;
    int lastNotFoundIndex = -1;
    
    while (!finished) {
        NSArray *mentionResults = [mentionsRegex matchesInString:origTextAttributed.string options:NSMatchingReportCompletion range:NSMakeRange(0, [origTextAttributed.string length])];
        
        NSTextCheckingResult *result = nil;
        if (lastNotFoundIndex == -1) {
            result = mentionResults.firstObject;
        } else {
            if (mentionResults.count >= lastNotFoundIndex+2) {
                result = mentionResults[lastNotFoundIndex+1];
            }
        }
        
        if (!result) {
            finished = YES;
            break;
        }
        
        NSString *mentionTag = [origTextAttributed.string substringWithRange:result.range];
        NSString *identity = [mentionTag substringWithRange:NSMakeRange(2, 8)].uppercaseString;
        
        ContactEntity *contact = [[ContactStore sharedContactStore] contactForIdentity:identity];
        UIColor *backgroundMention = [Colors backgroundMentionWithMessageInfo:messageInfo];
        NSMutableDictionary *paddingAttributeLeft = [[NSMutableDictionary alloc] initWithDictionary:@{@"TTTBackgroundFillColor": backgroundMention,
                                                                                             NSForegroundColorAttributeName: backgroundMention,
                                                                                             NSTextEffectAttributeName: NSTextEffectLetterpressStyle,
                                                                                             @"TTTBackgroundCornerRadius": [NSNumber numberWithFloat:3.0f],
                                                                                             @"ZSWTappableLabelTappableRegionAttributeName": @NO,
                                                                                             @"TTTBackgroundFillPadding": [NSNumber valueWithUIEdgeInsets:UIEdgeInsetsMake(-1, 0, -1, 5)]                                                                                         }];
        NSMutableDictionary *paddingAttributeRight = [[NSMutableDictionary alloc] initWithDictionary:@{@"TTTBackgroundFillColor": backgroundMention,
                                                                                                  NSForegroundColorAttributeName: backgroundMention,
                                                                                                  NSTextEffectAttributeName: NSTextEffectLetterpressStyle,
                                                                                                  @"TTTBackgroundCornerRadius": [NSNumber numberWithFloat:3.0f],
                                                                                                  @"ZSWTappableLabelTappableRegionAttributeName": @NO,
                                                                                                  @"TTTBackgroundFillPadding": [NSNumber valueWithUIEdgeInsets:UIEdgeInsetsMake(-1, 5, -1, 0)]                                                                                         }];
        NSMutableDictionary *attributeAt = [[NSMutableDictionary alloc] initWithDictionary:@{@"TTTBackgroundFillColor": backgroundMention,
                                                                                             NSForegroundColorAttributeName: atColor,
                                                                                             NSTextEffectAttributeName: NSTextEffectLetterpressStyle,
                                                                                             @"TTTBackgroundCornerRadius": [NSNumber numberWithFloat:0.0f],
                                                                                             @"ZSWTappableLabelTappableRegionAttributeName": @NO,
                                                                                             NSBaselineOffsetAttributeName: @1,
                                                                                             @"TTTBackgroundFillPadding": [NSNumber valueWithUIEdgeInsets:UIEdgeInsetsMake(-1, 0, -1, 0)]
                                                                                             }];
        if (contact || [identity isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]] || [identity isEqualToString:@"@@@@@@@@"]) {
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithDictionary:@{@"TTTBackgroundFillColor": backgroundMention,
                                                                                                NSTextEffectAttributeName: NSTextEffectLetterpressStyle,
                                                                                                @"TTTBackgroundCornerRadius": [NSNumber numberWithFloat:0.0f],
                                                                                                @"TTTBackgroundFillPadding": [NSNumber valueWithUIEdgeInsets:UIEdgeInsetsMake(-1, 0, -1, 0)]
                                                                                                }];
            NSString *displayName = [[MyIdentityStore sharedMyIdentityStore] displayName];
            UIColor *backgroundMentionMe = [Colors backgroundMentionMeWithMessageInfo:messageInfo];
            UIColor *fontMentionMe = [Colors textMentionMeWithMessageInfo:messageInfo];
            if (contact) {
                displayName = contact.mentionName;
                [attributes setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [attributes setObject:contact forKey:@"NSTextCheckingResult"];
                [attributes setObject:UIColor.labelColor forKey:NSForegroundColorAttributeName];
                [paddingAttributeLeft setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [paddingAttributeLeft setObject:contact forKey:@"NSTextCheckingResult"];
                [paddingAttributeRight setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [paddingAttributeRight setObject:contact forKey:@"NSTextCheckingResult"];
                [attributeAt setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [attributeAt setObject:contact forKey:@"NSTextCheckingResult"];
            } else if ([identity isEqualToString:@"@@@@@@@@"]) {
                displayName = [BundleUtil localizedStringForKey:@"all"];
                [paddingAttributeLeft setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [paddingAttributeLeft setObject:backgroundMentionMe forKey:NSForegroundColorAttributeName];
                
                [paddingAttributeRight setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [paddingAttributeRight setObject:backgroundMentionMe forKey:NSForegroundColorAttributeName];
                
                [attributeAt setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [attributeAt setObject:[fontMentionMe colorWithAlphaComponent:0.6] forKey:NSForegroundColorAttributeName];
                
                [attributes setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [attributes setObject:fontMentionMe forKey:NSForegroundColorAttributeName];
            } else {
                // me
                [paddingAttributeLeft setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [paddingAttributeLeft setObject:@"meContact" forKey:@"NSTextCheckingResult"];
                [paddingAttributeRight setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [paddingAttributeRight setObject:@"meContact" forKey:@"NSTextCheckingResult"];
                [attributeAt setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [attributeAt setObject:@"meContact" forKey:@"NSTextCheckingResult"];
                [attributes setObject:@YES forKey:@"ZSWTappableLabelTappableRegionAttributeName"];
                [attributes setObject:@"meContact" forKey:@"NSTextCheckingResult"];
                
                [paddingAttributeLeft setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [paddingAttributeLeft setObject:backgroundMentionMe forKey:NSForegroundColorAttributeName];
                
                [paddingAttributeRight setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [paddingAttributeRight setObject:backgroundMentionMe forKey:NSForegroundColorAttributeName];
                
                [attributeAt setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [attributeAt setObject:[fontMentionMe colorWithAlphaComponent:0.6] forKey:NSForegroundColorAttributeName];
                
                [attributes setObject:backgroundMentionMe forKey:@"TTTBackgroundFillColor"];
                [attributes setObject:fontMentionMe forKey:NSForegroundColorAttributeName];
            }
            
            displayName = [NSString stringWithFormat:@".@%@.", displayName];
            [origTextAttributed replaceCharactersInRange:result.range withString:displayName];
            [origTextAttributed addAttributes:attributes range:NSMakeRange(result.range.location, displayName.length)];
            [origTextAttributed addAttributes:attributeAt range:NSMakeRange(result.range.location+1, 1)];
            [origTextAttributed addAttributes:paddingAttributeLeft range:NSMakeRange(result.range.location, 1)];
            [origTextAttributed addAttributes:paddingAttributeRight range:NSMakeRange(result.range.location+displayName.length-1, 1)];
        } else {
            NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithDictionary:@{@"TTTBackgroundFillColor": backgroundMention,
                                                                                                NSTextEffectAttributeName: NSTextEffectLetterpressStyle,
                                                                                                @"TTTBackgroundCornerRadius": [NSNumber numberWithFloat:1.0f],
                                                                                                @"TTTBackgroundFillPadding": [NSNumber valueWithUIEdgeInsets:UIEdgeInsetsMake(-1, 0, -1, 0)]
                                                                                                }];
            identity = [NSString stringWithFormat:@".@%@.", identity];
            [origTextAttributed replaceCharactersInRange:result.range withString:identity];
            [origTextAttributed addAttributes:attributes range:NSMakeRange(result.range.location, identity.length)];
            [origTextAttributed addAttributes:attributeAt range:NSMakeRange(result.range.location+1, 1)];
            [origTextAttributed addAttributes:paddingAttributeLeft range:NSMakeRange(result.range.location, 1)];
            [origTextAttributed addAttributes:paddingAttributeRight range:NSMakeRange(result.range.location+identity.length-1, 1)];
            if (lastNotFoundIndex == -1) {
                lastNotFoundIndex = 0;
            } else {
                lastNotFoundIndex++;
            }
        }
    }
    
    return origTextAttributed;
}

+ (NSAttributedString *)makeMentionsAttributedStringForText:(NSString *)text textFont:(UIFont *)textFont textColor:(UIColor *)textColor isOwn:(BOOL)isOwn  messageInfo:(int)messageInfo application:(UIApplication *)application {
    NSMutableAttributedString *origTextAttributed = [[NSMutableAttributedString alloc] initWithAttributedString:[TextStyleUtils makeAttributedStringFromString:text withFont:textFont textColor:textColor isOwn:isOwn application:application]];
    return [TextStyleUtils makeMentionsAttributedStringForAttributedString:origTextAttributed textFont:textFont atColor:[textColor colorWithAlphaComponent:0.4] messageInfo:messageInfo application:application];
}

+ (BOOL)isMeOrAllMentionInText:(NSString *)text {
    if (!text) {
        return NO;
    }
    
    NSRegularExpression *mentionsRegex = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:nil];
    
    BOOL found = NO;
    BOOL finished = NO;
    int lastNotFoundIndex = -1;
    
    while (!finished || !found) {
        NSArray *mentionResults = [mentionsRegex matchesInString:text options:NSMatchingReportCompletion range:NSMakeRange(0, [text length])];
        
        NSTextCheckingResult *result = nil;
        if (lastNotFoundIndex == -1) {
            result = mentionResults.firstObject;
        } else {
            if (mentionResults.count >= lastNotFoundIndex+2) {
                result = mentionResults[lastNotFoundIndex+1];
            }
        }
        
        if (!result) {
            finished = YES;
            break;
        }
        
        NSString *mentionTag = [text substringWithRange:result.range];
        NSString *identity = [mentionTag substringWithRange:NSMakeRange(2, 8)].uppercaseString;
        
        if ([identity isEqualToString:[[MyIdentityStore sharedMyIdentityStore] identity]] || [identity isEqualToString:@"@@@@@@@@"]) {
            found = YES;
            break;
        } else {
            lastNotFoundIndex += 1;
        }
    }
    
    return found;
}

@end
