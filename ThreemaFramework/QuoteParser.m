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

#import "QuoteParser.h"
#import "NSString+Hex.h"

@implementation QuoteParser
    
+ (NSString*)parseQuoteFromMessage:(NSString*)message quotedIdentity:(NSString**)quotedIdentity remainingBody:(NSString**)remainingBody {
    if (message == nil)
        return nil;
    
    static dispatch_once_t onceToken;
    static NSRegularExpression *quoteRegex, *lineQuotesRegex;
    dispatch_once(&onceToken, ^{
        quoteRegex = [NSRegularExpression regularExpressionWithPattern:@"\\A>\\ ([A-Z0-9\\*][A-Z0-9]{7}): (.*?)^(?!>\\ )(.+)" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionDotMatchesLineSeparators error:nil];
        lineQuotesRegex = [NSRegularExpression regularExpressionWithPattern:@"^> " options:NSRegularExpressionAnchorsMatchLines error:nil];
    });
    
    NSTextCheckingResult *match = [quoteRegex firstMatchInString:message options:0 range:NSMakeRange(0, [message length])];
    if (match.numberOfRanges == 4) {
        if (quotedIdentity != nil) {
            *quotedIdentity = [message substringWithRange:[match rangeAtIndex:1]];
        }
        if (remainingBody != nil) {
            *remainingBody = [[message substringWithRange:[match rangeAtIndex:3]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        // Strip quotes at the beginning of each line in quoted text
        NSMutableString *quotedText = [NSMutableString stringWithString:[message substringWithRange:[match rangeAtIndex:2]]];
        [lineQuotesRegex replaceMatchesInString:quotedText options:0 range:NSMakeRange(0, [quotedText length]) withTemplate:@""];
        
        return [quotedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    return nil;
}

+ (NSData *)parseQuoteV2FromMessage:(NSString*)message remainingBody:(NSString**)remainingBody {
    if (message == nil)
        return nil;
    
    static dispatch_once_t onceToken;
    static NSRegularExpression *quoteRegex, *lineQuotesRegex;
    dispatch_once(&onceToken, ^{
        quoteRegex = [NSRegularExpression regularExpressionWithPattern:@"^> quote #[0-9a-f]{16}(\r?\n){2}" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
        lineQuotesRegex = [NSRegularExpression regularExpressionWithPattern:@"^> quote #" options:NSRegularExpressionAnchorsMatchLines error:nil];
    });
    
    NSTextCheckingResult *match = [quoteRegex firstMatchInString:message options:NSMatchingReportCompletion range:NSMakeRange(0, message.length)];
    if (match.numberOfRanges == 2) {
        NSRange matchRange = [match rangeAtIndex:0];
        if (matchRange.location == 0) {
            NSString *quoteString = [[message substringWithRange:[match rangeAtIndex:0]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            *remainingBody = [message substringWithRange:NSMakeRange(matchRange.length, message.length - matchRange.length)];
            
            // Strip quotes at the beginning of each line in quoted text
            NSMutableString *messageId = [NSMutableString stringWithString:quoteString];
            [lineQuotesRegex replaceMatchesInString:messageId options:0 range:NSMakeRange(0, [quoteString length]) withTemplate:@""];
            return [messageId decodeHex];
        }
    }
    
    return nil;
}

@end
