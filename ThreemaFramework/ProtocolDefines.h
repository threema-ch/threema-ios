//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#ifndef Threema_ProtocolDefines_h
#define Threema_ProtocolDefines_h

#define kCookieLen 16
#define kIdentityLen 8
#define kLoginAckReservedLen 16
#define kMessageIdLen 8
#define kNonceLen 24
#define kClientVersionLen 32
#define kPushFromNameLen 32
#define kBlobIdLen 16
#define kBlobKeyLen 32
#define kGroupIdLen 8
#define kBallotIdLen 8
#define kDeviceGroupPathKeyLen 32
#define kDeviceIdLen 8
#define kExtensionTypeLength = 1
#define kExtensionLengthLength = 2
#define kExtensionDataMaxLength = 256

#define kConnectTimeout 15
#define kReadTimeout 20
#define kWriteTimeout 20
#define kDisconnectTimeout 3
#define kReconnectBaseInterval 2
#define kReconnectMaxInterval 10
#define kKeepAliveInterval 180
#define kErrorDisplayInterval 30
#define kBlobLoadTimeout 180
#define kBlobUploadTimeout 120

#define kMaxMessageLen 3500 // text message size limit (bytes, not characters!); must comfortably fit in maximum packet length (including 360 bytes overhead and padding)
#define kMaxPktLen 8192
#define kMinMessagePaddedLen 32

static NSInteger const kMaxFileSize = 100*1024*1024;
static NSInteger const kWebClientAvatarSize = 48;
static Float32  const kWebClientAvatarQuality = 0.6;
static NSInteger const kWebClientAvatarHiResSize = 512;
static Float32  const kWebClientAvatarHiResQuality = 0.75;
static NSInteger const kWebClientMediaPreviewSize = 50;
static NSInteger const kWebClientMediaThumbnailSize = 350;
static Float32 const kWebClientMediaQuality = 0.6;

#define kMaxVideoDurationLowMinutes 15
#define kMaxVideoDurationHighMinutes 3
#define kMaxVideoSizeLow 480
#define kMaxVideoSizeHigh 848
#define kVideoBitrateLow 384000
#define kVideoBitrateMedium 1500000
#define kVideoBitrateHigh 2000000
#define kAudioBitrateLow 32000
#define kAudioBitrateMedium 64000
#define kAudioBitrateHigh 128000
#define kAudioChannelsLow 1
#define kAudioChannelsHigh 2

#define kGroupPeriodicSyncInterval 7*86400
#define kGroupSyncRequestInterval 1*86400

#define MSGTYPE_TEXT 0x01
#define MSGTYPE_IMAGE 0x02
#define MSGTYPE_LOCATION 0x10
#define MSGTYPE_VIDEO 0x13
#define MSGTYPE_AUDIO 0x14
#define MSGTYPE_BALLOT_CREATE 0x15
#define MSGTYPE_BALLOT_VOTE 0x16
#define MSGTYPE_FILE 0x17
#define MSGTYPE_CONTACT_SET_PHOTO 0x18
#define MSGTYPE_CONTACT_DELETE_PHOTO 0x19
#define MSGTYPE_CONTACT_REQUEST_PHOTO 0x1a
#define MSGTYPE_GROUP_TEXT 0x41
#define MSGTYPE_GROUP_LOCATION 0x42
#define MSGTYPE_GROUP_IMAGE 0x43
#define MSGTYPE_GROUP_VIDEO 0x44
#define MSGTYPE_GROUP_AUDIO 0x45
#define MSGTYPE_GROUP_FILE 0x46
#define MSGTYPE_GROUP_CREATE 0x4a
#define MSGTYPE_GROUP_RENAME 0x4b
#define MSGTYPE_GROUP_LEAVE 0x4c
#define MSGTYPE_GROUP_SET_PHOTO 0x50
#define MSGTYPE_GROUP_REQUEST_SYNC 0x51
#define MSGTYPE_GROUP_BALLOT_CREATE 0x52
#define MSGTYPE_GROUP_BALLOT_VOTE 0x53
#define MSGTYPE_GROUP_DELETE_PHOTO 0x54
#define MSGTYPE_VOIP_CALL_OFFER 0x60
#define MSGTYPE_VOIP_CALL_ANSWER 0x61
#define MSGTYPE_VOIP_CALL_ICECANDIDATE 0x62
#define MSGTYPE_VOIP_CALL_HANGUP 0x63
#define MSGTYPE_VOIP_CALL_RINGING 0x64
#define MSGTYPE_DELIVERY_RECEIPT 0x80
#define MSGTYPE_TYPING_INDICATOR 0x90
#define MSGTYPE_AUTH_TOKEN 0xff

#define MESSAGE_FLAG_PUSH 0x01
#define MESSAGE_FLAG_IMMEDIATE 0x02
#define MESSAGE_FLAG_NOACK 0x04
#define MESSAGE_FLAG_GROUP 0x10
#define MESSAGE_FLAG_VOIP 0x20
// Note: This flag will only be set from server
#define MESSAGE_FLAG_NO_DELIVERY_RECEIPT 0x80

#define DELIVERYRECEIPT_MSGRECEIVED 0x01
#define DELIVERYRECEIPT_MSGREAD 0x02
#define DELIVERYRECEIPT_MSGUSERACK 0x03
#define DELIVERYRECEIPT_MSGUSERDECLINE 0x04

#define PLTYPE_ECHO_REQUEST 0x00
#define PLTYPE_ECHO_REPLY 0x80
#define PLTYPE_OUTGOING_MESSAGE 0x01
#define PLTYPE_OUTGOING_MESSAGE_ACK 0x81
#define PLTYPE_INCOMING_MESSAGE 0x02
#define PLTYPE_INCOMING_MESSAGE_ACK 0x82
#define PLTYPE_UNBLOCK_INCOMING_MESSAGES 0x03
#define PLTYPE_PUSH_NOTIFICATION_TOKEN 0x20
#define PLTYPE_PUSH_ALLOWED_IDENTITIES 0x21
#define PLTYPE_PUSH_SOUND 0x22
#define PLTYPE_PUSH_GROUP_SOUND 0x23
#define PLTYPE_VOIP_PUSH_NOTIFICATION_TOKEN 0x24
#define PLTYPE_PUSH_OVERRIDE_TIMEOUT 0x31
#define PLTYPE_QUEUE_SEND_COMPLETE 0xd0
#define PLTYPE_ERROR 0xe0
#define PLTYPE_ALERT 0xe1

#define PUSHTOKEN_TYPE_NONE				0x00
#define PUSHTOKEN_TYPE_APPLE_PROD		0x01
#define PUSHTOKEN_TYPE_APPLE_SANDBOX	0x02
#define PUSHTOKEN_TYPE_APPLE_PROD_MC    0x05
#define PUSHTOKEN_TYPE_APPLE_SANDBOX_MC 0x06

#define kWithoutVoIPFeatureMask     0x0f
#define kCurrentFeatureMask         0x3f

#define FEATURE_MASK_AUDIO_MSG      0x01
#define FEATURE_MASK_GROUP_CHAT     0x02
#define FEATURE_MASK_BALLOT         0x04
#define FEATURE_MASK_FILE_TRANSFER  0x08
#define FEATURE_MASK_VOIP           0x10
#define FEATURE_MASK_VOIP_VIDEO     0x20

#define PUSHFILTER_TYPE_NONE            0
#define PUSHFILTER_TYPE_ALLOW_LISTED	1
#define PUSHFILTER_TYPE_BLOCK_LISTED	2

#define kGeneralErrorCode               100
#define kErrorCodeUserCancelled         300
#define kBlockUnknownContactErrorCode   666
#define kBadMessageErrorCode            667
#define kUnknownMessageTypeErrorCode    668
#define kMessageProcessingErrorCode     669
#define kPendingGroupMessageErrorCode   670

#define kJPEGCompressionQualityLow 0.8
#define kJPEGCompressionQualityHigh 0.99

static Float64 const kShareExtensionMaxImagePreviewSize = 15*1024*1024;
static Float64 const kShareExtensionMaxFileShareSize = 45*1024*1024;
static Float64 const kShareExtensionMaxImageShareSize = 30*1024*1024;

static unsigned char kNonce_1[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01};
static unsigned char kNonce_2[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x02};

#pragma pack(push, 1)
#pragma pack(1)

struct plError {
    uint8_t reconnect_allowed;
    char err_message[];
};

struct plMessage {
    char from_identity[kIdentityLen];
    char to_identity[kIdentityLen];
    char message_id[kMessageIdLen];
    uint32_t date;
    uint8_t flags;
    uint8_t reserved;
    uint16_t metadata_len;
    char push_from_name[kPushFromNameLen];
    char metadata_nonce_box[];
};

struct plMessageAck {
    char from_identity[kIdentityLen];
    char message_id[kMessageIdLen];
};

struct plOutgoingMessageAck {
    char to_identity[kIdentityLen];
    char message_id[kMessageIdLen];
};

#pragma pack(pop)

#endif
