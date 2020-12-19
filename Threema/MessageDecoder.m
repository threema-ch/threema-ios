//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "MessageDecoder.h"

#import "NaClCrypto.h"
#import "ContactStore.h"
#import "MyIdentityStore.h"
#import "BoxedMessage.h"
#import "ProtocolDefines.h"
#import "BoxTextMessage.h"
#import "BoxImageMessage.h"
#import "BoxVideoMessage.h"
#import "BoxLocationMessage.h"
#import "BoxAudioMessage.h"
#import "DeliveryReceiptMessage.h"
#import "TypingIndicatorMessage.h"
#import "GroupCreateMessage.h"
#import "GroupRenameMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupTextMessage.h"
#import "GroupLocationMessage.h"
#import "GroupImageMessage.h"
#import "GroupVideoMessage.h"
#import "GroupAudioMessage.h"
#import "GroupSetPhotoMessage.h"
#import "GroupRequestSyncMessage.h"
#import "UnknownTypeMessage.h"
#import "BoxBallotCreateMessage.h"
#import "BoxBallotVoteMessage.h"
#import "GroupBallotCreateMessage.h"
#import "GroupBallotVoteMessage.h"
#import "BoxFileMessage.h"
#import "GroupFileMessage.h"
#import "ContactSetPhotoMessage.h"
#import "ContactDeletePhotoMessage.h"
#import "ContactRequestPhotoMessage.h"
#import "BoxVoIPCallOfferMessage.h"
#import "BoxVoIPCallAnswerMessage.h"
#import "BoxVoIPCallIceCandidatesMessage.h"
#import "BoxVoIPCallHangupMessage.h"
#import "BoxVoIPCallRingingMessage.h"
#import "ValidationLogger.h"
#import "GroupDeletePhotoMessage.h"
#import "QuoteParser.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation MessageDecoder

+ (void)decodeFromBoxed:(BoxedMessage*)boxmsg isIncomming:(BOOL)isIncomming onCompletion:(void(^)(AbstractMessage *msg))onCompletion onError:(void(^)(NSError *err))onError {
    /* obtain sender's key, via API if necessary */
    [[ContactStore sharedContactStore] fetchPublicKeyForIdentity:boxmsg.fromIdentity onCompletion:^(NSData *publicKey) {
        AbstractMessage *msg = [MessageDecoder decodeFromBoxed:boxmsg isIncomming:isIncomming withPublicKey:publicKey];
        onCompletion(msg);
    } onError:^(NSError *error) {
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:isIncomming description:@"PublicKey from Threema-ID not found"];
        onError(error);
    }];
}

+ (AbstractMessage*)decodeFromBoxed:(BoxedMessage*)boxmsg isIncomming:(BOOL)isIncomming withPublicKey:(NSData*)publicKey {
    if (![boxmsg.toIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogError(@"Message is not for my identity - cannot decode");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:isIncomming description:@"Message is not for my identity - cannot decode"];
        return nil;
    }
    
    /* decrypt with our secret key */
    NSData *data = [[MyIdentityStore sharedMyIdentityStore] decryptData:boxmsg.box withNonce:boxmsg.nonce publicKey:publicKey];
    if (data == nil) {
        DDLogError(@"Decryption of message from %@ failed", boxmsg.fromIdentity);
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:isIncomming description:@"Decryption of message failed"];
        return nil;
    }
    
    if (data.length < 1) {
        DDLogError(@"Empty message received");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:isIncomming description:@"Empty message received"];
        return nil;
    }
    
    /* remove padding */
    uint8_t padbytes = *((uint8_t*)data.bytes + data.length - 1);
    int realDataLength = (int)data.length - padbytes;
    if (realDataLength < 1) {
        DDLogError(@"Bad message padding");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:isIncomming description:@"Bad message padding"];
        return nil;
    }
    DDLogVerbose(@"Effective data length is %d", realDataLength);
    
    uint8_t *type = (uint8_t*)data.bytes;
    AbstractMessage *msg = [MessageDecoder messageFromType: type data: data realDataLength: realDataLength fromIdentity: boxmsg.fromIdentity];
    
    if (msg != nil) {
        /* copy header attributes from boxed message */
        msg.fromIdentity = boxmsg.fromIdentity;
        msg.toIdentity = boxmsg.toIdentity;
        msg.messageId = boxmsg.messageId;
        msg.pushFromName = boxmsg.pushFromName;
        msg.date = boxmsg.date;
        msg.delivered = boxmsg.delivered;
        msg.deliveryDate = boxmsg.deliveryDate;
        msg.userAck = boxmsg.userAck;
        msg.sendUserAck = boxmsg.sendUserAck;
        msg.nonce = boxmsg.nonce;
        msg.flags = @(boxmsg.flags);
    }
    
    return msg;
}

+ (AbstractMessage*)messageFromType:(uint8_t*)type data:(NSData *) data realDataLength: (int) realDataLength fromIdentity: (NSString*) fromIdentity{
    /* first byte of data is type */
    AbstractMessage *msg = nil;
    switch (*type) {
        case MSGTYPE_TEXT: {
            if (realDataLength < 1) {
                DDLogWarn(@"Wrong length %d for text message", realDataLength);
                break;
            }
            BoxTextMessage *textmsg = [[BoxTextMessage alloc] init];
            textmsg.text = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1) length:(realDataLength - 1)] encoding:NSUTF8StringEncoding];
            
            NSString *remainingBody = nil;
            NSData *quotedMessageId = [QuoteParser parseQuoteV2FromMessage:textmsg.text remainingBody:&remainingBody];
            
            if (quotedMessageId != nil) {
                textmsg.text = remainingBody;
                textmsg.quotedMessageId = quotedMessageId;
            }
            msg = textmsg;
            break;
        }
        case MSGTYPE_IMAGE: {
            if (realDataLength != (1 + kBlobIdLen + sizeof(uint32_t) + kNonceLen)) {
                DDLogWarn(@"Wrong length %d for image message", realDataLength);
                break;
            }
            BoxImageMessage *imgmsg = [[BoxImageMessage alloc] init];
            imgmsg.blobId = [NSData dataWithBytes:(data.bytes + 1) length:kBlobIdLen];
            imgmsg.size = *((uint32_t*)(data.bytes + 1 + kBlobIdLen));
            imgmsg.imageNonce = [NSData dataWithBytes:(data.bytes + 1 + kBlobIdLen + sizeof(uint32_t)) length:kNonceLen];
            msg = imgmsg;
            break;
        }
        case MSGTYPE_VIDEO: {
            if (realDataLength != (1 + sizeof(uint16_t) + 2*(kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %d for video message", realDataLength);
                break;
            }
            BoxVideoMessage *videomsg = [[BoxVideoMessage alloc] init];
            int i = 1;
            videomsg.duration = *((uint16_t*)(data.bytes + i)); i += sizeof(uint16_t);
            videomsg.videoBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.videoSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            videomsg.thumbnailBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.thumbnailSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            videomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = videomsg;
            break;
        }
        case MSGTYPE_LOCATION: {
            if (realDataLength < 4) {
                DDLogWarn(@"Wrong length %d for location message", realDataLength);
                break;
            }
            
            NSString *coordinateStr = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1) length:(realDataLength - 1)] encoding:NSUTF8StringEncoding];
            if (coordinateStr == nil) {
                DDLogWarn(@"Bad coordinate string");
                break;
            }
            
            NSArray *lines = [coordinateStr componentsSeparatedByString:@"\n"];
            if (lines.count < 1) {
                DDLogWarn(@"Bad coordinate string");
                break;
            }
            
            NSArray *components = [lines[0] componentsSeparatedByString:@","];
            if (components.count < 2 || components.count > 3) {
                DDLogWarn(@"Bad coordinate format in location message");
                break;
            }
            
            BoxLocationMessage *locationmsg = [[BoxLocationMessage alloc] init];
            locationmsg.latitude = [components[0] doubleValue];
            locationmsg.longitude = [components[1] doubleValue];
            
            if (components.count == 3)
                locationmsg.accuracy = [components[2] doubleValue];
            else
                locationmsg.accuracy = 0;
            
            if (lines.count >= 2) {
                locationmsg.poiName = lines[1];
                if (lines.count >= 3)
                    locationmsg.poiAddress = [lines[2] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
            }
            
            if (locationmsg.latitude < -90.0 || locationmsg.latitude > 90.0 || locationmsg.longitude < -180.0 || locationmsg.longitude > 180.0) {
                DDLogWarn(@"Invalid coordinate values in location message");
                break;
            }
            
            msg = locationmsg;
            break;
        }
        case MSGTYPE_AUDIO: {
            if (realDataLength != (1 + sizeof(uint16_t) + kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen) {
                DDLogWarn(@"Wrong length %d for audio message", realDataLength);
                break;
            }
            BoxAudioMessage *audiomsg = [[BoxAudioMessage alloc] init];
            int i = 1;
            audiomsg.duration = *((uint16_t*)(data.bytes + i)); i += sizeof(uint16_t);
            audiomsg.audioBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            audiomsg.audioSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            audiomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = audiomsg;
            break;
        }
        case MSGTYPE_DELIVERY_RECEIPT: {
            if (realDataLength < kMessageIdLen + 2 || ((realDataLength - 2) % kMessageIdLen) != 0) {
                DDLogWarn(@"Wrong length %d for delivery receipt", realDataLength);
                break;
            }
            DeliveryReceiptMessage *receiptmsg = [[DeliveryReceiptMessage alloc] init];
            receiptmsg.receiptType = *((uint8_t*)(data.bytes + 1));
            
            int numMsgIds = ((realDataLength - 2) / kMessageIdLen);
            NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:numMsgIds];
            for (int i = 0; i < numMsgIds; i++) {
                NSData *receiptMessageId = [NSData dataWithBytes:(data.bytes + 2 + i*kMessageIdLen) length:kMessageIdLen];
                [receiptMessageIds addObject:receiptMessageId];
            }
            
            receiptmsg.receiptMessageIds = receiptMessageIds;
            msg = receiptmsg;
            break;
        }
        case MSGTYPE_TYPING_INDICATOR: {
            if (realDataLength != 2) {
                DDLogWarn(@"Wrong length %d for typing indicator", realDataLength);
                break;
            }
            TypingIndicatorMessage *typingmsg = [[TypingIndicatorMessage alloc] init];
            typingmsg.typing = *((uint8_t*)(data.bytes + 1)) ? YES : NO;
            msg = typingmsg;
            break;
        }
        case MSGTYPE_GROUP_CREATE: {
            if (realDataLength < (1 + kGroupIdLen) || ((realDataLength - 1 - kGroupIdLen) % kIdentityLen) != 0) {
                DDLogWarn(@"Wrong length %d for group create message", realDataLength);
                break;
            }
            
            GroupCreateMessage *groupcreatemsg = [[GroupCreateMessage alloc] init];
            groupcreatemsg.groupId = [NSData dataWithBytes:(data.bytes + 1) length:kGroupIdLen];
            int numMembers = ((realDataLength - kGroupIdLen - 1) / kIdentityLen);
            NSMutableArray *groupMembers = [NSMutableArray arrayWithCapacity:numMembers];
            for (int i = 0; i < numMembers; i++) {
                NSString *member = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1 + kGroupIdLen + i*kIdentityLen) length:kIdentityLen] encoding:NSASCIIStringEncoding];
                if (member == nil) {
                    DDLogWarn(@"Invalid group member ID");
                    groupMembers = nil;
                    break;
                }
                [groupMembers addObject:member];
            }
            if (groupMembers == nil)
                break;
            groupcreatemsg.groupMembers = groupMembers;
            groupcreatemsg.groupCreator = fromIdentity;
            msg = groupcreatemsg;
            break;
        }
        case MSGTYPE_GROUP_RENAME: {
            if (realDataLength < (1 + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group rename message", realDataLength);
                break;
            }
            
            GroupRenameMessage *renamemsg = [[GroupRenameMessage alloc] init];
            renamemsg.groupId = [NSData dataWithBytes:(data.bytes + 1) length:kGroupIdLen];
            renamemsg.name = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1 + kGroupIdLen) length:(realDataLength - 1 - kGroupIdLen)] encoding:NSUTF8StringEncoding];
            renamemsg.groupCreator = fromIdentity;
            msg = renamemsg;
            break;
        }
        case MSGTYPE_GROUP_LEAVE: {
            if (realDataLength != (1 + kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group leave message", realDataLength);
                break;
            }
            
            GroupLeaveMessage *groupleavemsg = [[GroupLeaveMessage alloc] init];
            groupleavemsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            groupleavemsg.groupId = [NSData dataWithBytes:(data.bytes + 1 + kIdentityLen) length:kGroupIdLen];
            msg = groupleavemsg;
            break;
        }
        case MSGTYPE_GROUP_TEXT: {
            if (realDataLength < (1 + kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group text message", realDataLength);
                break;
            }
            GroupTextMessage *textmsg = [[GroupTextMessage alloc] init];
            textmsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            textmsg.groupId = [NSData dataWithBytes:(data.bytes + 1 + kIdentityLen) length:kGroupIdLen];
            textmsg.text = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1 + kIdentityLen + kGroupIdLen) length:(realDataLength - 1 - kIdentityLen - kGroupIdLen)] encoding:NSUTF8StringEncoding];
            
            NSString *remainingBody = nil;
            NSData *quotedMessageId = [QuoteParser parseQuoteV2FromMessage:textmsg.text remainingBody:&remainingBody];
            if (quotedMessageId != nil) {
                textmsg.text = remainingBody;
                textmsg.quotedMessageId = quotedMessageId;
            }
            
            msg = textmsg;
            break;
        }
        case MSGTYPE_GROUP_LOCATION: {
            if (realDataLength < (kIdentityLen + kGroupIdLen + 4)) {
                DDLogWarn(@"Wrong length %d for group location message", realDataLength);
                break;
            }
            
            GroupLocationMessage *locationmsg = [[GroupLocationMessage alloc] init];
            locationmsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            locationmsg.groupId = [NSData dataWithBytes:(data.bytes + 1 + kIdentityLen) length:kGroupIdLen];
            
            NSString *coordinateStr = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + 1 + kIdentityLen + kGroupIdLen) length:(realDataLength - 1 - kIdentityLen - kGroupIdLen)] encoding:NSUTF8StringEncoding];
            if (coordinateStr == nil) {
                DDLogWarn(@"Bad coordinate string");
                break;
            }
            
            NSArray *lines = [coordinateStr componentsSeparatedByString:@"\n"];
            if (lines.count < 1) {
                DDLogWarn(@"Bad coordinate string");
                break;
            }
            
            NSArray *components = [lines[0] componentsSeparatedByString:@","];
            if (components.count < 2 || components.count > 3) {
                DDLogWarn(@"Bad coordinate format in location message");
                break;
            }
            
            locationmsg.latitude = [components[0] doubleValue];
            locationmsg.longitude = [components[1] doubleValue];
            
            if (components.count == 3)
                locationmsg.accuracy = [components[2] doubleValue];
            else
                locationmsg.accuracy = 0;
            
            if (lines.count >= 2) {
                locationmsg.poiName = lines[1];
                if (lines.count >= 3)
                    locationmsg.poiAddress = [lines[2] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
            }
            
            if (locationmsg.latitude < -90.0 || locationmsg.latitude > 90.0 || locationmsg.longitude < -180.0 || locationmsg.longitude > 180.0) {
                DDLogWarn(@"Invalid coordinate values in location message");
                break;
            }
            
            msg = locationmsg;
            break;
        }
        case MSGTYPE_GROUP_IMAGE: {
            if (realDataLength != (1 + kIdentityLen + kGroupIdLen + kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %d for group image message", realDataLength);
                break;
            }
            GroupImageMessage *imagemsg = [[GroupImageMessage alloc] init];
            int i = 1;
            imagemsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            imagemsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            imagemsg.blobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            imagemsg.size = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            imagemsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = imagemsg;
            break;
        }
        case MSGTYPE_GROUP_VIDEO: {
            if (realDataLength != (1 + kIdentityLen + kGroupIdLen + sizeof(uint16_t) + 2*(kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %d for group video message", realDataLength);
                break;
            }
            GroupVideoMessage *videomsg = [[GroupVideoMessage alloc] init];
            int i = 1;
            videomsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            videomsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            videomsg.duration = *((uint16_t*)(data.bytes + i)); i += sizeof(uint16_t);
            videomsg.videoBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.videoSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            videomsg.thumbnailBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.thumbnailSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            videomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = videomsg;
            break;
        }
        case MSGTYPE_GROUP_AUDIO: {
            if (realDataLength != (1 + kIdentityLen + kGroupIdLen + sizeof(uint16_t) + kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen) {
                DDLogWarn(@"Wrong length %d for group audio message", realDataLength);
                break;
            }
            GroupAudioMessage *audiomsg = [[GroupAudioMessage alloc] init];
            int i = 1;
            audiomsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            audiomsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            audiomsg.duration = *((uint16_t*)(data.bytes + i)); i += sizeof(uint16_t);
            audiomsg.audioBlobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            audiomsg.audioSize = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            audiomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = audiomsg;
            break;
        }
        case MSGTYPE_GROUP_SET_PHOTO: {
            if (realDataLength != (1 + kGroupIdLen + kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %d for group set photo message", realDataLength);
                break;
            }
            
            GroupSetPhotoMessage *setphotomsg = [[GroupSetPhotoMessage alloc] init];
            int i = 1;
            setphotomsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            setphotomsg.blobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            setphotomsg.size = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            setphotomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            setphotomsg.groupCreator = fromIdentity;
            msg = setphotomsg;
            break;
        }
        case MSGTYPE_GROUP_REQUEST_SYNC: {
            if (realDataLength != (1 + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group request sync message", realDataLength);
                break;
            }
            
            GroupRequestSyncMessage *groupsyncmsg = [[GroupRequestSyncMessage alloc] init];
            groupsyncmsg.groupId = [NSData dataWithBytes:(data.bytes + 1) length:kGroupIdLen];
            msg = groupsyncmsg;
            break;
        }
        case MSGTYPE_BALLOT_CREATE: {
            if (realDataLength < (1 + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %d for ballot create message", realDataLength);
                break;
            }

            int i = 1;
            BoxBallotCreateMessage *ballotCreateMsg = [[BoxBallotCreateMessage alloc] init];
            ballotCreateMsg.ballotId = [NSData dataWithBytes:(data.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotCreateMsg.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = ballotCreateMsg;
            break;
        }
        case MSGTYPE_BALLOT_VOTE: {
            if (realDataLength < (1 + kIdentityLen + kIdentityLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %d for ballot vote message", realDataLength);
                break;
            }
            
            int i = 1;
            BoxBallotVoteMessage *ballotVoteMsg = [[BoxBallotVoteMessage alloc] init];
            ballotVoteMsg.ballotCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.ballotId = [NSData dataWithBytes:(data.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotVoteMsg.jsonChoiceData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = ballotVoteMsg;
            break;
        }
        case MSGTYPE_GROUP_BALLOT_CREATE: {
            if (realDataLength < (1 + kIdentityLen + kGroupIdLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %d for group ballot create message", realDataLength);
                break;
            }
            
            int i = 1;
            GroupBallotCreateMessage *ballotCreateMsg = [[GroupBallotCreateMessage alloc] init];
            ballotCreateMsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotCreateMsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            ballotCreateMsg.ballotId = [NSData dataWithBytes:(data.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotCreateMsg.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = ballotCreateMsg;
            break;
        }
        case MSGTYPE_GROUP_BALLOT_VOTE: {
            if (realDataLength < (1 + kIdentityLen + kGroupIdLen + kIdentityLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %d for group ballot vote message", realDataLength);
                break;
            }
            
            int i = 1;
            GroupBallotVoteMessage *ballotVoteMsg = [[GroupBallotVoteMessage alloc] init];
            ballotVoteMsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            ballotVoteMsg.ballotCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.ballotId = [NSData dataWithBytes:(data.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotVoteMsg.jsonChoiceData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = ballotVoteMsg;
            break;
        }
        case MSGTYPE_GROUP_DELETE_PHOTO: {
            if (realDataLength != (1 + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group delete photo message", realDataLength);
                break;
            }
            
            GroupDeletePhotoMessage *deletephotomsg = [[GroupDeletePhotoMessage alloc] init];
            deletephotomsg.groupId = [NSData dataWithBytes:(data.bytes + 1) length:kGroupIdLen];
            deletephotomsg.groupCreator = fromIdentity;
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_FILE: {
            if (realDataLength < 1) {
                DDLogWarn(@"Wrong length %d for file message", realDataLength);
                break;
            }
            
            int i = 1;
            BoxFileMessage *fileMessage = [[BoxFileMessage alloc] init];
            fileMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = fileMessage;
            break;
        }
        case MSGTYPE_GROUP_FILE: {
            if (realDataLength < (1 + kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %d for group file message", realDataLength);
                break;
            }
            
            int i = 1;
            GroupFileMessage *fileMessage = [[GroupFileMessage alloc] init];
            fileMessage.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(data.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            fileMessage.groupId = [NSData dataWithBytes:(data.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            fileMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = fileMessage;
            break;
        }
        case MSGTYPE_CONTACT_SET_PHOTO: {
            if (realDataLength != (1 + kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %d for contact set photo message", realDataLength);
                break;
            }
            
            ContactSetPhotoMessage *setphotomsg = [[ContactSetPhotoMessage alloc] init];
            int i = 1;

            setphotomsg.blobId = [NSData dataWithBytes:(data.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            setphotomsg.size = *((uint32_t*)(data.bytes + i)); i += sizeof(uint32_t);
            setphotomsg.encryptionKey = [NSData dataWithBytes:(data.bytes + i) length:kBlobKeyLen];
            msg = setphotomsg;
            break;
        }
        case MSGTYPE_CONTACT_DELETE_PHOTO: {
            if (realDataLength != 1) {
                DDLogWarn(@"Wrong length %d for contact delete photo message", realDataLength);
                break;
            }
            
            ContactDeletePhotoMessage *deletephotomsg = [[ContactDeletePhotoMessage alloc] init];
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_CONTACT_REQUEST_PHOTO: {
            if (realDataLength != 1) {
                DDLogWarn(@"Wrong length %d for contact request photo message", realDataLength);
                break;
            }
            
            ContactRequestPhotoMessage *deletephotomsg = [[ContactRequestPhotoMessage alloc] init];
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_VOIP_CALL_OFFER: {
            if (realDataLength < 1) {
                DDLogWarn(@"Wrong length %d for call offer message", realDataLength);
                break;
            }
            
            int i = 1;
            BoxVoIPCallOfferMessage *offerMessage = [[BoxVoIPCallOfferMessage alloc] init];
            offerMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = offerMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_ANSWER: {
            if (realDataLength < 1) {
                DDLogWarn(@"Wrong length %d for call answer message", realDataLength);
                break;
            }
            
            int i = 1;
            BoxVoIPCallAnswerMessage *answerMessage = [[BoxVoIPCallAnswerMessage alloc] init];
            answerMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = answerMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_ICECANDIDATE: {
            if (realDataLength < 1) {
                DDLogWarn(@"Wrong length %d for call ice candidate message", realDataLength);
                break;
            }
            
            int i = 1;
            BoxVoIPCallIceCandidatesMessage *iceCandidateMessage = [[BoxVoIPCallIceCandidatesMessage alloc] init];
            iceCandidateMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = iceCandidateMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_HANGUP: {
            int i = 1;
            BoxVoIPCallHangupMessage *hangupMessage = [[BoxVoIPCallHangupMessage alloc] init];
            hangupMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = hangupMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_RINGING: {
            int i = 1;
            BoxVoIPCallRingingMessage *ringingMessage = [[BoxVoIPCallRingingMessage alloc] init];
            ringingMessage.jsonData = [NSData dataWithBytes:(data.bytes + i) length:(realDataLength - i)];
            msg = ringingMessage;
            break;
        }
        default:
            DDLogWarn(@"Unsupported message type %d", *type);
            msg = [[UnknownTypeMessage alloc] init];
            break;
    }
    
    return msg;
}

@end
