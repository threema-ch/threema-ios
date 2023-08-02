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

#import "MessageDecoder.h"

#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NaClCrypto.h"
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
#import "GroupDeliveryReceiptMessage.h"
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
#import "QuoteUtil.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation MessageDecoder

+ (AbstractMessage*)decodeFromBoxed:(BoxedMessage*)boxmsg withPublicKey:(NSData*)publicKey {
    if (![boxmsg.toIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogError(@"Message is not for my identity - cannot decode");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Message is not for my identity - cannot decode"];
        return nil;
    }
    
    /* decrypt with our secret key */
    NSData *data = [[MyIdentityStore sharedMyIdentityStore] decryptData:boxmsg.box withNonce:boxmsg.nonce publicKey:publicKey];
    if (data == nil) {
        DDLogError(@"Decryption of message from %@ failed", boxmsg.fromIdentity);
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Decryption of message failed"];
        return nil;
    }
    
    if (data.length < 1) {
        DDLogError(@"Empty message received");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Empty message received"];
        return nil;
    }
    
    /* remove padding */
    uint8_t padbytes = *((uint8_t*)data.bytes + data.length - 1);
    int realDataLength = (int)data.length - padbytes;
    if (realDataLength < 1) {
        DDLogError(@"Bad message padding");
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Bad message padding"];
        return nil;
    }
    DDLogVerbose(@"Effective data length is %d", realDataLength);
    
    // Decrypt metadata, if present
    MessageMetadata *metadata = nil;
    if (boxmsg.metadataBox != nil) {
        NSError *err = nil;
        metadata = [[MetadataCoder new] decodeWithNonce:boxmsg.nonce box:boxmsg.metadataBox publicKey:publicKey error:&err];
        if (err != nil) {
            DDLogError(@"Metadata decryption failed: %@", err);
            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Metadata decryption failed"];
            return nil;
        }
        
        // Ensure message ID matches envelope message ID
        if (metadata.messageID != nil) {
            if (![boxmsg.messageId isEqual:metadata.messageID]) {
                DDLogError(@"Metadata message ID does not match envelope message ID");
                [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Metadata message ID does not match envelope message ID"];
                return nil;
            }
        }
    }
    
    AbstractMessage *msg = [MessageDecoder decodeRawBody:data realDataLength:realDataLength];
    
    if (msg != nil) {
        /* copy header attributes from boxed message */
        msg.fromIdentity = boxmsg.fromIdentity;
        msg.toIdentity = boxmsg.toIdentity;
        msg.messageId = boxmsg.messageId;
        msg.delivered = boxmsg.delivered;
        msg.deliveryDate = boxmsg.deliveryDate;
        msg.userAck = boxmsg.userAck;
        msg.sendUserAck = boxmsg.sendUserAck;
        msg.nonce = boxmsg.nonce;
        msg.flags = @(boxmsg.flags);
        
        // Take date from encrypted metdata, or from envelope if not present
        if (metadata != nil && metadata.createdAt != nil) {
            msg.date = metadata.createdAt;
        } else {
            msg.date = boxmsg.date;
        }
        
        // Take nickname from encrypted metadata, or from legacy field if not present
        if (metadata != nil) {
            msg.pushFromName = metadata.nickname;
        } else {
            msg.pushFromName = boxmsg.pushFromName;
        }
        
        if (msg.flagGroupMessage == YES) {
            // Set group creator and sync group id/creator with boxed message
            if ([msg isKindOfClass:[GroupCreateMessage class]] || [msg isKindOfClass:[GroupRenameMessage class]] || [msg isKindOfClass:[GroupSetPhotoMessage class]] || [msg isKindOfClass:[GroupDeletePhotoMessage class]]) {
                ((AbstractGroupMessage *)msg).groupCreator = boxmsg.fromIdentity;
            }
            else if ([msg isKindOfClass:[GroupRequestSyncMessage class]]) {
                ((AbstractGroupMessage *)msg).groupCreator = boxmsg.toIdentity;
            }
        }
    }
    
    return msg;
}

+ (AbstractMessage*)decodeRawBody:(NSData*)data realDataLength:(int)realDataLength {
    // Get message type and body, and decode it
    uint8_t *type = (uint8_t*)data.bytes;
    NSData *body = [NSData dataWithBytes:(data.bytes + 1) length:realDataLength - 1];
    return [MessageDecoder decode:(int)*type body:body];
}

+ (AbstractMessage *)decode:(int)type body:(NSData *)body {
    AbstractMessage *msg = nil;
    switch (type) {
        case MSGTYPE_AUDIO: {
            if ([body length] != (sizeof(uint16_t) + kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen) {
                DDLogWarn(@"Wrong length %lu for audio message", (unsigned long)[body length]);
                break;
            }
            BoxAudioMessage *audiomsg = [[BoxAudioMessage alloc] init];
            int i = 0;
            audiomsg.duration = *((uint16_t*)(body.bytes + i)); i += sizeof(uint16_t);
            audiomsg.audioBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            audiomsg.audioSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            audiomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = audiomsg;
            break;
        }
        case MSGTYPE_BALLOT_CREATE: {
            if ([body length] < kBallotIdLen) {
                DDLogWarn(@"Wrong length %lu for ballot create message", (unsigned long)[body length]);
                break;
            }

            int i = 0;
            BoxBallotCreateMessage *ballotCreateMsg = [[BoxBallotCreateMessage alloc] init];
            ballotCreateMsg.ballotId = [NSData dataWithBytes:body.bytes length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotCreateMsg.jsonData = [NSData dataWithBytes:(body.bytes + i) length:([body length] - i)];
            msg = ballotCreateMsg;
            break;
        }
        case MSGTYPE_BALLOT_VOTE: {
            if ([body length] < (kIdentityLen + kIdentityLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %lu for ballot vote message", (unsigned long)[body length]);
                break;
            }
            
            int i = 0;
            BoxBallotVoteMessage *ballotVoteMsg = [[BoxBallotVoteMessage alloc] init];
            ballotVoteMsg.ballotCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.ballotId = [NSData dataWithBytes:(body.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotVoteMsg.jsonChoiceData = [NSData dataWithBytes:(body.bytes + i) length:([body length] - i)];
            msg = ballotVoteMsg;
            break;
        }
        case MSGTYPE_CONTACT_DELETE_PHOTO: {
            if ([body length] != 0) {
                DDLogWarn(@"Wrong length %lu for contact delete photo message", (unsigned long)[body length]);
                break;
            }
            
            ContactDeletePhotoMessage *deletephotomsg = [[ContactDeletePhotoMessage alloc] init];
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_CONTACT_REQUEST_PHOTO: {
            if ([body length] != 0) {
                DDLogWarn(@"Wrong length %lu for contact request photo message", (unsigned long)[body length]);
                break;
            }
            
            ContactRequestPhotoMessage *deletephotomsg = [[ContactRequestPhotoMessage alloc] init];
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_CONTACT_SET_PHOTO: {
            if ([body length] != (kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %lu for contact set photo message", (unsigned long)[body length]);
                break;
            }
            
            ContactSetPhotoMessage *setphotomsg = [[ContactSetPhotoMessage alloc] init];
            int i = 0;

            setphotomsg.blobId = [NSData dataWithBytes:body.bytes length:kBlobIdLen]; i += kBlobIdLen;
            setphotomsg.size = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            setphotomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = setphotomsg;
            break;
        }
        case MSGTYPE_DELIVERY_RECEIPT: {
            long len = [body length];
            if (len < kMessageIdLen + 1 || ((len - 1) % kMessageIdLen) != 0) {
                DDLogWarn(@"Wrong length %lu for delivery receipt", len);
                break;
            }
            DeliveryReceiptMessage *receiptmsg = [[DeliveryReceiptMessage alloc] init];
            receiptmsg.receiptType = *((uint8_t*)body.bytes);
            
            long numMsgIds = ((len - 1) / kMessageIdLen);
            NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:numMsgIds];
            for (long i = 0; i < numMsgIds; i++) {
                NSData *receiptMessageId = [NSData dataWithBytes:(body.bytes + 1 + i*kMessageIdLen) length:kMessageIdLen];
                [receiptMessageIds addObject:receiptMessageId];
            }
            
            receiptmsg.receiptMessageIds = receiptMessageIds;
            msg = receiptmsg;
            break;
        }
        case MSGTYPE_FILE: {
            if ([body length] < 1) {
                DDLogWarn(@"Wrong length %lu for file message", (unsigned long)[body length]);
                break;
            }
            
            BoxFileMessage *fileMessage = [[BoxFileMessage alloc] init];
            fileMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = fileMessage;
            break;
        }
        case MSGTYPE_GROUP_AUDIO: {
            if ([body length] != (kIdentityLen + kGroupIdLen + sizeof(uint16_t) + kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen) {
                DDLogWarn(@"Wrong length %lu for group audio message", (unsigned long)[body length]);
                break;
            }
            GroupAudioMessage *audiomsg = [[GroupAudioMessage alloc] init];
            int i = 0;
            audiomsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            audiomsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            audiomsg.duration = *((uint16_t*)(body.bytes + i)); i += sizeof(uint16_t);
            audiomsg.audioBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            audiomsg.audioSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            audiomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = audiomsg;
            break;
        }
        case MSGTYPE_GROUP_BALLOT_CREATE: {
            if ([body length] < (kIdentityLen + kGroupIdLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %lu for group ballot create message", (unsigned long)[body length]);
                break;
            }
            
            int i = 0;
            GroupBallotCreateMessage *ballotCreateMsg = [[GroupBallotCreateMessage alloc] init];
            ballotCreateMsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotCreateMsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            ballotCreateMsg.ballotId = [NSData dataWithBytes:(body.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotCreateMsg.jsonData = [NSData dataWithBytes:(body.bytes + i) length:([body length] - i)];
            msg = ballotCreateMsg;
            break;
        }
        case MSGTYPE_GROUP_BALLOT_VOTE: {
            if ([body length] < (kIdentityLen + kGroupIdLen + kIdentityLen + kBallotIdLen)) {
                DDLogWarn(@"Wrong length %lu for group ballot vote message", (unsigned long)[body length]);
                break;
            }
            
            int i = 0;
            GroupBallotVoteMessage *ballotVoteMsg = [[GroupBallotVoteMessage alloc] init];
            ballotVoteMsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            ballotVoteMsg.ballotCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:(body.bytes + i) length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            ballotVoteMsg.ballotId = [NSData dataWithBytes:(body.bytes + i) length:kBallotIdLen];
            i+= kBallotIdLen;
            ballotVoteMsg.jsonChoiceData = [NSData dataWithBytes:(body.bytes + i) length:([body length] - i)];
            msg = ballotVoteMsg;
            break;
        }
        case MSGTYPE_GROUP_CREATE: {
            if ([body length] < kGroupIdLen || (([body length] - kGroupIdLen) % kIdentityLen) != 0) {
                DDLogWarn(@"Wrong length %lu for group create message", (unsigned long)[body length]);
                break;
            }
            
            GroupCreateMessage *groupcreatemsg = [[GroupCreateMessage alloc] init];
            groupcreatemsg.groupId = [NSData dataWithBytes:body.bytes length:kGroupIdLen];
            unsigned long numMembers = (([body length] - kGroupIdLen) / kIdentityLen);
            NSMutableArray *groupMembers = [NSMutableArray arrayWithCapacity:numMembers];
            for (int i = 0; i < numMembers; i++) {
                NSString *member = [[NSString alloc] initWithData:[NSData dataWithBytes:(body.bytes + kGroupIdLen + i*kIdentityLen) length:kIdentityLen] encoding:NSASCIIStringEncoding];
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
            msg = groupcreatemsg;
            break;
        }
        case MSGTYPE_GROUP_DELETE_PHOTO: {
            if ([body length] != kGroupIdLen) {
                DDLogWarn(@"Wrong length %lu for group delete photo message", (unsigned long)[body length]);
                break;
            }
            
            GroupDeletePhotoMessage *deletephotomsg = [[GroupDeletePhotoMessage alloc] init];
            deletephotomsg.groupId = [NSData dataWithBytes:body.bytes length:kGroupIdLen];
            msg = deletephotomsg;
            break;
        }
        case MSGTYPE_GROUP_FILE: {
            if ([body length] < (kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %lu for group file message", (unsigned long)[body length]);
                break;
            }
            
            int i = 0;
            GroupFileMessage *fileMessage = [[GroupFileMessage alloc] init];
            fileMessage.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            fileMessage.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            fileMessage.jsonData = [NSData dataWithBytes:(body.bytes + i) length:([body length] - i)];
            msg = fileMessage;
            break;
        }
        case MSGTYPE_GROUP_IMAGE: {
            if ([body length] != (kIdentityLen + kGroupIdLen + kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %lu for group image message", (unsigned long)[body length]);
                break;
            }
            GroupImageMessage *imagemsg = [[GroupImageMessage alloc] init];
            int i = 0;
            imagemsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            imagemsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            imagemsg.blobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            imagemsg.size = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            imagemsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = imagemsg;
            break;
        }
        case MSGTYPE_GROUP_LEAVE: {
            if ([body length] != (kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %lu for group leave message", (unsigned long)[body length]);
                break;
            }
            
            GroupLeaveMessage *groupleavemsg = [[GroupLeaveMessage alloc] init];
            groupleavemsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            groupleavemsg.groupId = [NSData dataWithBytes:(body.bytes + kIdentityLen) length:kGroupIdLen];
            msg = groupleavemsg;
            break;
        }
        case MSGTYPE_GROUP_LOCATION: {
            if ([body length] < (kIdentityLen + kGroupIdLen + 3)) {
                DDLogWarn(@"Wrong length %lu for group location message", (unsigned long)[body length]);
                break;
            }
            
            GroupLocationMessage *locationmsg = [[GroupLocationMessage alloc] init];
            locationmsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            locationmsg.groupId = [NSData dataWithBytes:(body.bytes + kIdentityLen) length:kGroupIdLen];
            
            NSString *coordinateStr = [[NSString alloc] initWithData:[NSData dataWithBytes:(body.bytes + kIdentityLen + kGroupIdLen) length:([body length] - kIdentityLen - kGroupIdLen)] encoding:NSUTF8StringEncoding];
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
        case MSGTYPE_GROUP_RENAME: {
            if ([body length] < kGroupIdLen) {
                DDLogWarn(@"Wrong length %lu for group rename message", (unsigned long)[body length]);
                break;
            }
            
            GroupRenameMessage *renamemsg = [[GroupRenameMessage alloc] init];
            renamemsg.groupId = [NSData dataWithBytes:body.bytes length:kGroupIdLen];
            renamemsg.name = [[NSString alloc] initWithData:[NSData dataWithBytes:(body.bytes + kGroupIdLen) length:([body length] - kGroupIdLen)] encoding:NSUTF8StringEncoding];
            msg = renamemsg;
            break;
        }
        case MSGTYPE_GROUP_REQUEST_SYNC: {
            if ([body length] != kGroupIdLen) {
                DDLogWarn(@"Wrong length %lu for group request sync message", (unsigned long)[body length]);
                break;
            }
            
            GroupRequestSyncMessage *groupsyncmsg = [[GroupRequestSyncMessage alloc] init];
            groupsyncmsg.groupId = [NSData dataWithBytes:body.bytes length:kGroupIdLen];
            msg = groupsyncmsg;
            break;
        }
        case MSGTYPE_GROUP_SET_PHOTO: {
            if ([body length] != (kGroupIdLen + kBlobIdLen + sizeof(uint32_t) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %lu for group set photo message", (unsigned long)[body length]);
                break;
            }
            
            GroupSetPhotoMessage *setphotomsg = [[GroupSetPhotoMessage alloc] init];
            int i = 0;
            setphotomsg.groupId = [NSData dataWithBytes:body.bytes length:kGroupIdLen]; i+= kGroupIdLen;
            setphotomsg.blobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            setphotomsg.size = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            setphotomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = setphotomsg;
            break;
        }
        case MSGTYPE_GROUP_TEXT: {
            if ([body length] < (kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %lu for group text message", (unsigned long)[body length]);
                break;
            }
            GroupTextMessage *textmsg = [[GroupTextMessage alloc] init];
            textmsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            textmsg.groupId = [NSData dataWithBytes:(body.bytes + kIdentityLen) length:kGroupIdLen];
            textmsg.text = [[NSString alloc] initWithData:[NSData dataWithBytes:(body.bytes + kIdentityLen + kGroupIdLen) length:([body length] - kIdentityLen - kGroupIdLen)] encoding:NSUTF8StringEncoding];
            
            NSString *remainingBody = nil;
            NSData *quotedMessageId = [QuoteUtil parseQuoteV2FromMessage:textmsg.text remainingBody:&remainingBody];
            if (quotedMessageId != nil) {
                textmsg.text = remainingBody;
                textmsg.quotedMessageId = quotedMessageId;
            }
            
            msg = textmsg;
            break;
        }
        case MSGTYPE_GROUP_VIDEO: {
            if ([body length] != (kIdentityLen + kGroupIdLen + sizeof(uint16_t) + 2*(kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %lu for group video message", (unsigned long)[body length]);
                break;
            }
            GroupVideoMessage *videomsg = [[GroupVideoMessage alloc] init];
            int i = 0;
            videomsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            videomsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;
            videomsg.duration = *((uint16_t*)(body.bytes + i)); i += sizeof(uint16_t);
            videomsg.videoBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.videoSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            videomsg.thumbnailBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.thumbnailSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            videomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = videomsg;
            break;
        }
        case MSGTYPE_GROUP_DELIVERY_RECEIPT: {
            long len = [body length];
            if (len < kGroupCreatorLen + kGroupIdLen + kMessageIdLen + 1 || ((len - kGroupCreatorLen - kGroupIdLen - 1) % kMessageIdLen) != 0) {
                DDLogWarn(@"Wrong length %lu for group request sync message", (unsigned long)len);
                break;
            }
            GroupDeliveryReceiptMessage *groupReceiptMsg = [[GroupDeliveryReceiptMessage alloc] init];
            int i = 0;
            groupReceiptMsg.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding]; i += kIdentityLen;
            groupReceiptMsg.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen]; i+= kGroupIdLen;

            groupReceiptMsg.receiptType = *((uint8_t*)body.bytes+i);
            
            long numMsgIds = ((len - i - 1) / kMessageIdLen);
            NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:numMsgIds];
            for (long j = 0; j < numMsgIds; j++) {
                NSData *receiptMessageId = [NSData dataWithBytes:(body.bytes + 1 + i + j*kMessageIdLen) length:kMessageIdLen];
                [receiptMessageIds addObject:receiptMessageId];
            }
            
            groupReceiptMsg.receiptMessageIds = receiptMessageIds;
            msg = groupReceiptMsg;
            break;
        }
        case MSGTYPE_IMAGE: {
            if ([body length] != (kBlobIdLen + sizeof(uint32_t) + kNonceLen)) {
                DDLogWarn(@"Wrong length %lu for image message", (unsigned long)[body length]);
                break;
            }
            BoxImageMessage *imgmsg = [[BoxImageMessage alloc] init];
            imgmsg.blobId = [NSData dataWithBytes:body.bytes length:kBlobIdLen];
            imgmsg.size = *((uint32_t*)(body.bytes + kBlobIdLen));
            imgmsg.imageNonce = [NSData dataWithBytes:(body.bytes + kBlobIdLen + sizeof(uint32_t)) length:kNonceLen];
            msg = imgmsg;
            break;
        }
        case MSGTYPE_LOCATION: {
            if ([body length] < 3) {
                DDLogWarn(@"Wrong length %lu for location message", (unsigned long)[body length]);
                break;
            }
            
            NSString *coordinateStr = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:[body length]] encoding:NSUTF8StringEncoding];
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
        case MSGTYPE_TEXT: {
            if ([body length] < 1) {
                DDLogWarn(@"Wrong length for text message");
                break;
            }
            BoxTextMessage *textmsg = [[BoxTextMessage alloc] init];
            textmsg.text = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:[body length]] encoding:NSUTF8StringEncoding];
            
            NSString *remainingBody = nil;
            NSData *quotedMessageId = [QuoteUtil parseQuoteV2FromMessage:textmsg.text remainingBody:&remainingBody];
            
            if (quotedMessageId != nil) {
                textmsg.text = remainingBody;
                textmsg.quotedMessageId = quotedMessageId;
            }
            msg = textmsg;
            break;
        }
        case MSGTYPE_TYPING_INDICATOR: {
            if ([body length] != 1) {
                DDLogWarn(@"Wrong length %lu for typing indicator", (unsigned long)[body length]);
                break;
            }
            TypingIndicatorMessage *typingmsg = [[TypingIndicatorMessage alloc] init];
            typingmsg.typing = *((uint8_t*)body.bytes) ? YES : NO;
            msg = typingmsg;
            break;
        }
        case MSGTYPE_VIDEO: {
            if ([body length] != (sizeof(uint16_t) + 2*(kBlobIdLen + sizeof(uint32_t)) + kBlobKeyLen)) {
                DDLogWarn(@"Wrong length %lu for video message", (unsigned long)[body length]);
                break;
            }
            BoxVideoMessage *videomsg = [[BoxVideoMessage alloc] init];
            int i = 0;
            videomsg.duration = *((uint16_t*)(body.bytes + i)); i += sizeof(uint16_t);
            videomsg.videoBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.videoSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            videomsg.thumbnailBlobId = [NSData dataWithBytes:(body.bytes + i) length:kBlobIdLen]; i += kBlobIdLen;
            videomsg.thumbnailSize = *((uint32_t*)(body.bytes + i)); i += sizeof(uint32_t);
            videomsg.encryptionKey = [NSData dataWithBytes:(body.bytes + i) length:kBlobKeyLen];
            msg = videomsg;
            break;
        }
        case MSGTYPE_VOIP_CALL_ANSWER: {
            if ([body length] < 1) {
                DDLogWarn(@"Wrong length %lu for call answer message", (unsigned long)[body length]);
                break;
            }

            BoxVoIPCallAnswerMessage *answerMessage = [[BoxVoIPCallAnswerMessage alloc] init];
            answerMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = answerMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_HANGUP: {
            BoxVoIPCallHangupMessage *hangupMessage = [[BoxVoIPCallHangupMessage alloc] init];
            hangupMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = hangupMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_ICECANDIDATE: {
            if ([body length] < 1) {
                DDLogWarn(@"Wrong length %lu for call ice casndidate message", [body length]);
                break;
            }

            BoxVoIPCallIceCandidatesMessage *iceCandidateMessage = [[BoxVoIPCallIceCandidatesMessage alloc] init];
            iceCandidateMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = iceCandidateMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_OFFER: {
            if ([body length] < 1) {
                DDLogWarn(@"Wrong length %lu for call offer message", [body length]);
                break;
            }
                    
            BoxVoIPCallOfferMessage *offerMessage = [[BoxVoIPCallOfferMessage alloc] init];
            offerMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = offerMessage;
            break;
        }
        case MSGTYPE_VOIP_CALL_RINGING: {
            BoxVoIPCallRingingMessage *ringingMessage = [[BoxVoIPCallRingingMessage alloc] init];
            ringingMessage.jsonData = [NSData dataWithBytes:body.bytes length:[body length]];
            msg = ringingMessage;
            break;
        }
        case MSGTYPE_FORWARD_SECURITY: {
            NSData *protobufData = [NSData dataWithBytes:body.bytes length:[body length]];
            NSError *protobufError = nil;
            ForwardSecurityData *fsData = [ForwardSecurityData fromProtobufWithRawProtobufMessage:protobufData error:&protobufError];
            if (protobufError != nil) {
                DDLogWarn(@"Cannot decode FS message: %@", protobufError);
                break;
            }
            ForwardSecurityEnvelopeMessage *envelopeMessage = [[ForwardSecurityEnvelopeMessage alloc] initWithData:fsData];
            msg = envelopeMessage;
            break;
        }
        case MSGTYPE_GROUP_CALL_START: {
            if ([body length] < (kIdentityLen + kGroupIdLen)) {
                DDLogWarn(@"Wrong length %lu for group file message", (unsigned long)[body length]);
                break;
            }
            
            NSError *protobufError = nil;
            
            int i = 0;
            GroupCallStartMessage *groupCallStartMessage = [[GroupCallStartMessage alloc] init];
            groupCallStartMessage.groupCreator = [[NSString alloc] initWithData:[NSData dataWithBytes:body.bytes length:kIdentityLen] encoding:NSASCIIStringEncoding];
            i+= kIdentityLen;
            groupCallStartMessage.groupId = [NSData dataWithBytes:(body.bytes + i) length:kGroupIdLen];
            i+= kGroupIdLen;
            [groupCallStartMessage fromRawProtoBufMessageWithRawProtobufMessage:[NSData dataWithBytes:(body.bytes + i) length:[body length] - i] error:&protobufError];
            
            if(protobufError != nil) {
                DDLogWarn(@"Cannot decode Group Call Start Message: %@", protobufError);
                break;
            }
            msg = groupCallStartMessage;
            break;
        }
        default: {
            DDLogWarn(@"Unsupported message type %d", type);
            msg = [[UnknownTypeMessage alloc] init];
            break;
        }
    }
    return msg;
}

@end
