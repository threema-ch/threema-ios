//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2025 Threema GmbH
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

#import "AbstractGroupMessage.h"
#import "BundleUtil.h"
#import "GroupTextMessage.h"
#import "GroupImageMessage.h"
#import "GroupVideoMessage.h"
#import "GroupLocationMessage.h"
#import "GroupAudioMessage.h"
#import "GroupBallotCreateMessage.h"
#import "GroupFileMessage.h"
#import "BallotMessageDecoder.h"
#import "FileMessageDecoder.h"
#import "QuoteUtil.h"
#import "TextStyleUtils.h"
#import "ThreemaUtilityObjC.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NSString+Hex.h"

@implementation AbstractGroupMessage

@synthesize groupCreator;
@synthesize groupId;

- (BOOL)flagGroupMessage {
    return YES;
}

- (NSString *)description {
    NSString *result = [super description];
    return [result stringByAppendingFormat:@" groupCreator: %@ - groupId: %@ ", groupCreator, groupId];
}

- (NSString *)pushNotificationBody {
    NSString *body = [NSString new];
    if ([self isKindOfClass:[GroupTextMessage class]]) {
        NSString *quotedIdentity = nil;
        NSString *remainingBody = nil;
        NSString *quotedText = [QuoteUtil parseQuoteFromMessage:((GroupTextMessage *)self).text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
        if (quotedText) {
            body = remainingBody;
        } else {
            body = ((GroupTextMessage *)self).text;
        }
        body = [TextStyleUtils makeMentionsStringForText:body];
    }
    else if ([self isKindOfClass:[GroupImageMessage class]]) {
        body = [BundleUtil localizedStringForKey:@"new_image_message"];
    }
    else if ([self isKindOfClass:[GroupVideoMessage class]]) {
        body = [BundleUtil localizedStringForKey:@"new_video_message"];
    }
    else if ([self isKindOfClass:[GroupLocationMessage class]]) {
        NSString *locationName = [(GroupLocationMessage *)self poiName];
        if (locationName)
            body = [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"new_location_message"], locationName];
        else
            body = [BundleUtil localizedStringForKey:@"new_location_message"];
    }
    else if ([self isKindOfClass:[GroupAudioMessage class]]) {
        body = [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"file_message_voice"], [ThreemaUtilityObjC timeStringForSeconds:((GroupAudioMessage *)self).duration]];
    }
    else if ([self isKindOfClass:[GroupBallotCreateMessage class]]) {
        BOOL closed = [BallotMessageDecoder decodeNotificationCreateBallotStateFromBox:(BoxBallotCreateMessage *)self].intValue == BallotStateClosed;
        NSString *ballotTitle = [BallotMessageDecoder decodeCreateBallotTitleFromBox:(BoxBallotCreateMessage *)self];
        if (closed) {
            body = [BundleUtil localizedStringForKey:@"new_ballot_closed_message"];
        } else {
            body = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"new_ballot_create_message"], ballotTitle];
        }
    }
    else if ([self isKindOfClass:[GroupFileMessage class]]) {
        NSString *caption = [FileMessageDecoder decodeGroupFileCaptionFromBox:(GroupFileMessage *)self];
        if (caption != nil) {
            body = caption;
        } else {
            NSString *fileName = [FileMessageDecoder decodeGroupFilenameFromBox:(GroupFileMessage *)self];
            body = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"new_file_message"], fileName];
        }
        
    }
    return body;
}

- (BOOL)allowSendingProfile {
    return NO;
}

- (BOOL)isGroupControlMessage {
    return false;
}

- (BOOL)isGroupCallMessage {
    return false;
}

- (BOOL)noDeliveryReceiptFlagSet {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV12;
}

#pragma mark - LoggingDescriptionProtocol

- (NSString * _Nonnull)loggingDescription {
    return [NSString stringWithFormat:@"(type: %@; id: %@; groupIdentity: id: %@ creator: %@)",
            [MediatorMessageProtocol getTypeDescriptionWithType:self.type],
            [NSString stringWithHexData:self.messageId],
            [NSString stringWithHexData:groupId],
            groupCreator];
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.groupCreator = [decoder decodeObjectOfClass:[NSString class] forKey:@"groupCreator"];
        self.groupId = [decoder decodeObjectOfClass:[NSData class] forKey:@"groupId"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.groupCreator forKey:@"groupCreator"];
    [encoder encodeObject:self.groupId forKey:@"groupId"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
