//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "TextMessage.h"
#import "QuoteUtil.h"
#import "NSString+Hex.h"

@implementation TextMessage

@dynamic text;
@dynamic quotedMessageId;

- (nullable NSString*)additionalExportInfo {
    return self.text;
}

- (nonnull NSString*) previewText {
    // Strip quote, if any
    if (self.quotedMessageId == nil) {
        NSString *remainingBody = nil;
        [QuoteUtil parseQuoteFromMessage:self.text quotedIdentity:nil remainingBody:&remainingBody];
        if (remainingBody != nil) {
            return remainingBody;
        }
    }
    
    if (self.text != nil) {
        return self.text;
    }
    
    return @"";
}

- (nullable NSString *)contentToCheckForMentions {
    return self.text;
}

@end
