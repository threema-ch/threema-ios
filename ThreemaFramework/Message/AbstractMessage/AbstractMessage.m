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

#import "AbstractMessage.h"
#import "NaClCrypto.h"
#import "ProtocolDefines.h"
#import "BoxFileMessage.h"
#import "BallotMessageDecoder.h"
#import "FileMessageDecoder.h"
#import "BundleUtil.h"
#import "QuoteUtil.h"
#import "QuotedMessageProtocol.h"
#import "TextStyleUtils.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NSString+Hex.h"
#import "ThreemaUtilityObjC.h"
#import "NonceHasher.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation AbstractMessage

- (id)init
{
    self = [super init];
    if (self) {
        self.date = [NSDate date];
        self.messageId = [AbstractMessage randomMessageId];
    }
    return self;
}

- (BoxedMessage*)makeBox:(ContactEntity *  _Nonnull)toContact myIdentityStore:(id<MyIdentityStoreProtocol> _Nonnull)myIdentityStore {

    /* prepare data for box */
    uint8_t type = self.type;
    NSData *_body;
    if ([self conformsToProtocol:@protocol(QuotedMessageProtocol)] == NO) {
        _body = self.body;
    }
    else {
        _body = [((id<QuotedMessageProtocol>)self) quotedBody];
    }
    NSMutableData *boxData = [NSMutableData dataWithCapacity:_body.length + 1];
    [boxData appendBytes:&type length:1];
    [boxData appendData:_body];
    
    /* PKCS7 padding */
    NSData *padAmount = [[NaClCrypto sharedCrypto] randomBytes:1];
    uint8_t padbytes = *((uint8_t*)padAmount.bytes);
    if (padbytes == 0)
        padbytes = 1;
    if ((1 + _body.length + padbytes) < kMinMessagePaddedLen)
        padbytes = kMinMessagePaddedLen - 1 - _body.length;
    DDLogVerbose(@"Adding %d padding bytes", padbytes);
    uint8_t *paddata = malloc(padbytes);
    if (!paddata)
        return nil;
    for (int i = 0; i < padbytes; i++)
        paddata[i] = padbytes;
    [boxData appendData:[NSData dataWithBytesNoCopy:paddata length:padbytes]];

    // Validate receiver contact
    if (![toContact.identity isEqualToString:self.toIdentity]) {
        DDLogInfo(@"Dropping message to wrong contact for identity %@", self.toIdentity);
        return nil;
    }

    if (toContact.isValid == NO) {
        DDLogInfo(@"Dropping message to invalid identity %@", self.toIdentity);
        return nil;
    }

    if (toContact.publicKey == nil) {
        DDLogError(@"Cannot get public key for identity %@", self.toIdentity);
        return nil;
    }

    /* make random nonce and save to database */
    NSData *nonce = [[NaClCrypto sharedCrypto] randomBytes:kNaClCryptoNonceSize];

    /* sign/encrypt with our secret key */
    NSData *boxedData = [myIdentityStore encryptData:boxData withNonce:nonce publicKey:toContact.publicKey];
    
    BoxedMessage *boxmsg = [[BoxedMessage alloc] init];
    boxmsg.fromIdentity = myIdentityStore.identity;
    boxmsg.toIdentity = self.toIdentity;
    boxmsg.messageId = self.messageId;
    boxmsg.date = self.date;
    boxmsg.flags = 0;
    if (self.flagShouldPush) {
        boxmsg.flags |= MESSAGE_FLAG_SEND_PUSH;
    }
    if (self.flagDontQueue) {
        boxmsg.flags |= MESSAGE_FLAG_DONT_QUEUE;
    }
    if (self.flagDontAck) {
        boxmsg.flags |= MESSAGE_FLAG_DONT_ACK;
    }
    if (self.flagGroupMessage) {
        boxmsg.flags |= MESSAGE_FLAG_GROUP;
    }
    if (self.flagImmediateDeliveryRequired) {
        boxmsg.flags |= MESSAGE_FLAG_IMMEDIATE_DELIVERY;
    }
    boxmsg.nonce = nonce;
    boxmsg.box = boxedData;
    
    /* Encrypt metadata (only include nickname for user-initiated messages) */
    NSString *metadataNickname = nil;
    if (self.allowSendingProfile) {
        metadataNickname = myIdentityStore.pushFromName;
        
        if ([boxmsg.toIdentity hasPrefix:@"*"]) {
            boxmsg.pushFromName = myIdentityStore.pushFromName;
        }
    }
    MessageMetadata *metadata = [[MessageMetadata alloc] initWithNickname:metadataNickname messageID:self.messageId createdAt:self.date];
    boxmsg.metadataBox = [[MetadataCoder new] encodeWithMetadata:metadata nonce:nonce publicKey:toContact.publicKey];

    return boxmsg;
}

+ (NSData*)randomMessageId {
    return [[NaClCrypto sharedCrypto] randomBytes:kMessageIdLen];
}

- (uint8_t)type {
    return 0;
}

- (NSData*)body {
    return nil;
}

- (BOOL)canCreateConversation {
    return YES;
}

- (BOOL)needsConversation {
    return YES;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)flagDontQueue {
    return NO;
}

- (BOOL)flagDontAck {
    return NO;
}

- (BOOL)flagGroupMessage {
    return NO;
}

- (BOOL)flagImmediateDeliveryRequired {
    return NO;
}

- (BOOL)flagIsVoIP {
    return NO;
}

- (BOOL)supportsForwardSecurity {
    return NO;
}

- (BOOL)isContentValid {
    //method must be implemented by subclass
    [NSException raise:NSInternalInconsistencyException
                format:@"Method %@ is abstract, subclass it", NSStringFromSelector(_cmd)];
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ - msgId: %@, from: %@, to: %@", NSStringFromClass([self class]), _messageId, _fromIdentity, _toIdentity];
}

- (NSString *)pushNotificationBody {
    NSString *body = [NSString new];
    if ([self isKindOfClass:[BoxTextMessage class]]) {
        NSString *quotedIdentity = nil;
        NSString *remainingBody = nil;
        NSString *quotedText = [QuoteUtil parseQuoteFromMessage:((BoxTextMessage *)self).text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
        if (quotedText) {
            body = remainingBody;
        } else {
            body = ((BoxTextMessage *)self).text;
        }
        body = [TextStyleUtils makeMentionsStringForText:body];
    }
    else if ([self isKindOfClass:[BoxImageMessage class]]) {
        body = [BundleUtil localizedStringForKey:@"new_image_message"];
    }
    else if ([self isKindOfClass:[BoxVideoMessage class]]) {
        body = [BundleUtil localizedStringForKey:@"new_video_message"];
    }
    else if ([self isKindOfClass:[BoxLocationMessage class]]) {
        NSString *locationName = [(BoxLocationMessage *)self poiName];
        if (locationName)
            body = [NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"new_location_message"], locationName];
        else
            body = [BundleUtil localizedStringForKey:@"new_location_message"];
    }
    else if ([self isKindOfClass:[BoxAudioMessage class]]) {
        body = [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"new_audio_message"], [ThreemaUtilityObjC timeStringForSeconds:((BoxAudioMessage *)self).duration]];
    }
    else if ([self isKindOfClass:[BoxBallotCreateMessage class]]) {
        BOOL closed = [BallotMessageDecoder decodeNotificationCreateBallotStateFromBox:(BoxBallotCreateMessage *)self].integerValue == kBallotStateClosed;
        NSString *ballotTitle = [BallotMessageDecoder decodeCreateBallotTitleFromBox:(BoxBallotCreateMessage *)self];
        if (closed) {
            body = [BundleUtil localizedStringForKey:@"new_ballot_closed_message"];
        } else {
            body = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"new_ballot_create_message"], ballotTitle];
        }
    }
    else if ([self isKindOfClass:[BoxFileMessage class]]) {
        NSString *caption = [FileMessageDecoder decodeFileCaptionFromBox:(BoxFileMessage *)self];
        if (caption != nil) {
            body = caption;
        } else {
            NSString *fileName = [FileMessageDecoder decodeFilenameFromBox:(BoxFileMessage *)self];
            body = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"new_file_message"], fileName];
        }
    }
    return body;
}

- (BOOL)allowSendingProfile {
    return NO;
}

- (NSString *)getMessageIdString {
    return [NSString stringWithHexData:self.messageId];
}

- (BOOL)noDeliveryReceiptFlagSet {
    if (self.flags != nil) {
        if ([self.flags integerValue] & BaseMessageFlagsNoDeliveryReceipt) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - LoggingDescriptionProtocol

- (NSString * _Nonnull)loggingDescription {
    return [NSString stringWithFormat:@"(type: %@; id: %@)", [MediatorMessageProtocol getTypeDescriptionWithType:self.type], [NSString stringWithHexData:self.messageId]];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.fromIdentity = [decoder decodeObjectForKey:@"fromIdentity"];
        self.toIdentity = [decoder decodeObjectForKey:@"toIdentity"];
        self.messageId = [decoder decodeObjectForKey:@"messageId"];
        self.pushFromName = [decoder decodeObjectForKey:@"pushFromName"];
        self.date = [decoder decodeObjectForKey:@"date"];
        self.deliveryDate = [decoder decodeObjectForKey:@"deliveryDate"];
        self.delivered = [decoder decodeObjectForKey:@"delivered"];
        self.userAck = [decoder decodeObjectForKey:@"userAck"];
        self.sendUserAck = [decoder decodeObjectForKey:@"sendUserAck"];
        self.nonce = [decoder decodeObjectForKey:@"nonce"];
        self.receivedAfterInitialQueueSend = [decoder decodeBoolForKey:@"receivedAfterInitialQueueSend"];
        self.flags = [decoder decodeObjectForKey:@"flags"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.fromIdentity forKey:@"fromIdentity"];
    [encoder encodeObject:self.toIdentity forKey:@"toIdentity"];
    [encoder encodeObject:self.messageId forKey:@"messageId"];
    [encoder encodeObject:self.pushFromName forKey:@"pushFromName"];
    [encoder encodeObject:self.date forKey:@"date"];
    [encoder encodeObject:self.deliveryDate forKey:@"deliveryDate"];
    [encoder encodeObject:self.delivered forKey:@"delivered"];
    [encoder encodeObject:self.userAck forKey:@"userAck"];
    [encoder encodeObject:self.sendUserAck forKey:@"sendUserAck"];
    [encoder encodeObject:self.nonce forKey:@"nonce"];
    [encoder encodeBool:self.receivedAfterInitialQueueSend forKey:@"receivedAfterInitialQueueSend"];
    [encoder encodeObject:self.flags forKey:@"flags"];
}

@end
