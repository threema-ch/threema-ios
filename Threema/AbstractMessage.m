//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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
#import "EntityManager.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "Contact.h"
#import "BoxFileMessage.h"
#import "BallotMessageDecoder.h"
#import "FileMessageDecoder.h"
#import "BundleUtil.h"
#import "QuoteParser.h"
#import "TextStyleUtils.h"
#import "NSString+Hex.h"
#import "Utils.h"
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

- (BoxedMessage*)makeBox {
    /* prepare data for box */
    uint8_t type = self.type;
    NSData *_body = self.body;
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
    
    /* obtain receiver's key */
    __block Contact *contact;
    __block BOOL isValid;
    __block NSData *receiverPublicKey;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performBlockAndWait:^{
        contact = [entityManager.entityFetcher contactForId:self.toIdentity];
        isValid = contact.isValid;
        receiverPublicKey = contact.publicKey;
    }];
    
    if (contact == nil) {
        DDLogError(@"Contact not found for identity %@", self.toIdentity);
        return nil;
    }
    
    if (isValid == NO) {
        DDLogInfo(@"Dropping message to invalid identity %@", self.toIdentity);
        return nil;
    }
    
    if (receiverPublicKey == nil) {
        DDLogError(@"Cannot get public key for identity %@", self.toIdentity);
        return nil;
    }
    
    /* make random nonce and save to database */
    NSData *nonce = [[NaClCrypto sharedCrypto] randomBytes:kNaClCryptoNonceSize];
    
    if (!self.immediate) {
        [entityManager performAsyncBlockAndSafe:^{
            [entityManager.entityCreator nonceWithData:[NonceHasher hashedNonce:nonce]];
        }];
    }
    
    /* sign/encrypt with our secret key */
    NSData *boxedData = [[MyIdentityStore sharedMyIdentityStore] encryptData:boxData withNonce:nonce publicKey:receiverPublicKey];
    
    BoxedMessage *boxmsg = [[BoxedMessage alloc] init];
    boxmsg.fromIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
    boxmsg.toIdentity = self.toIdentity;
    boxmsg.messageId = self.messageId;
    boxmsg.date = self.date;
    boxmsg.flags = 0;
    if (self.shouldPush)
        boxmsg.flags |= MESSAGE_FLAG_PUSH;
    if (self.immediate)
        boxmsg.flags |= MESSAGE_FLAG_IMMEDIATE;
    if (self.noAck)
        boxmsg.flags |= MESSAGE_FLAG_NOACK;
    if (self.isGroup)
        boxmsg.flags |= MESSAGE_FLAG_GROUP;
    if (self.isVoIP)
        boxmsg.flags |= MESSAGE_FLAG_VOIP;
    boxmsg.pushFromName = [MyIdentityStore sharedMyIdentityStore].pushFromName;
    boxmsg.nonce = nonce;
    boxmsg.box = boxedData;
    
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

- (BOOL)shouldPush {
    return NO;
}

- (BOOL)immediate {
    return NO;
}

- (BOOL)noAck {
    return NO;
}

- (BOOL)isGroup {
    return NO;
}

- (BOOL)isVoIP {
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
        NSString *quotedText = [QuoteParser parseQuoteFromMessage:((BoxTextMessage *)self).text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
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
        body = [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"new_audio_message"], [Utils timeStringForSeconds:((BoxAudioMessage *)self).duration]];
    }
    else if ([self isKindOfClass:[BoxBallotCreateMessage class]]) {
        BallotMessageDecoder *decoder = [BallotMessageDecoder messageDecoder];
        BOOL closed = [decoder decodeNotificationCreateBallotStateFromBox:(BoxBallotCreateMessage *)self].integerValue == kBallotStateClosed;
        NSString *ballotTitle = [decoder decodeCreateBallotTitleFromBox:(BoxBallotCreateMessage *)self];
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

- (BOOL)allowToSendProfilePicture {
    return NO;
}

- (NSString *)getMessageIdString {
    return [NSString stringWithHexData:self.messageId];
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
