//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import <UIKit/UIKit.h>

// In this header, you should import all the public headers of your framework using statements like #import <ThreemaFramework/PublicHeader.h>

#import <ThreemaFramework/AbstractMessage.h>
#import <ThreemaFramework/AbstractGroupMessage.h>
#import <ThreemaFramework/AppGroup.h>
#import <ThreemaFramework/AvatarMaker.h>
#import <ThreemaFramework/AudioMessageEntity.h>
#import <ThreemaFramework/Ballot.h>
#import <ThreemaFramework/BallotChoice.h>
#import <ThreemaFramework/BallotMessage.h>
#import <ThreemaFramework/BallotMessageDecoder.h>
#import <ThreemaFramework/BallotMessageEncoder.h>
#import <ThreemaFramework/BallotResult.h>
#import <ThreemaFramework/BaseMessage.h>
#import <ThreemaFramework/Old_BlobMessageSender.h>
#import <ThreemaFramework/Old_BlobUploadDelegate.h>
#import <ThreemaFramework/BoxAudioMessage.h>
#import <ThreemaFramework/BoxBallotCreateMessage.h>
#import <ThreemaFramework/BoxBallotVoteMessage.h>
#import <ThreemaFramework/BoxFileMessage.h>
#import <ThreemaFramework/BoxedMessage.h>
#import <ThreemaFramework/BoxImageMessage.h>
#import <ThreemaFramework/BoxLocationMessage.h>
#import <ThreemaFramework/BoxTextMessage.h>
#import <ThreemaFramework/BoxVideoMessage.h>
#import <ThreemaFramework/BoxVoIPCallAnswerMessage.h>
#import <ThreemaFramework/BoxVoIPCallHangupMessage.h>
#import <ThreemaFramework/BoxVoIPCallIceCandidatesMessage.h>
#import <ThreemaFramework/BoxVoIPCallOfferMessage.h>
#import <ThreemaFramework/BoxVoIPCallRingingMessage.h>
#import <ThreemaFramework/BundleUtil.h>
#import <ThreemaFramework/Constants.h>
#import <ThreemaFramework/ContactEntity.h>
#import <ThreemaFramework/ContactDeletePhotoMessage.h>
#import <ThreemaFramework/ContactNameLabel.h>
#import <ThreemaFramework/ContactPhotoSender.h>
#import <ThreemaFramework/ContactUtil.h>
#import <ThreemaFramework/ContactRequestPhotoMessage.h>
#import <ThreemaFramework/ContactSetPhotoMessage.h>
#import <ThreemaFramework/ContactStore.h>
#import <ThreemaFramework/ConnectionStateDelegate.h>
#import <ThreemaFramework/Conversation.h>
#import <ThreemaFramework/DatabaseContext.h>
#import <ThreemaFramework/DatabaseManager.h>
#import <ThreemaFramework/DeliveryReceiptMessage.h>
#import <ThreemaFramework/DeviceGroupKeys.h>
#import <ThreemaFramework/EntityCreator.h>
#import <ThreemaFramework/EntityFetcher.h>
#import <ThreemaFramework/ErrorHandler.h>
#import <ThreemaFramework/ExternalStorageInfo.h>
#import <ThreemaFramework/FileLoggerCustom.h>
#import <ThreemaFramework/FileMessageEntity.h>
#import <ThreemaFramework/Old_FileMessageSender.h>
#import <ThreemaFramework/MediaConverter.h>
#import <ThreemaFramework/UTIConverter.h>
#import <ThreemaFramework/FileMessageDecoder.h>
#import <ThreemaFramework/FileMessageEncoder.h>
#import <ThreemaFramework/GroupEntity.h>
#import <ThreemaFramework/GroupAudioMessage.h>
#import <ThreemaFramework/GroupBallotCreateMessage.h>
#import <ThreemaFramework/GroupBallotVoteMessage.h>
#import <ThreemaFramework/GroupCreateMessage.h>
#import <ThreemaFramework/GroupDeletePhotoMessage.h>
#import <ThreemaFramework/GroupDeliveryReceiptMessage.h>
#import <ThreemaFramework/GroupFileMessage.h>
#import <ThreemaFramework/GroupImageMessage.h>
#import <ThreemaFramework/GroupLeaveMessage.h>
#import <ThreemaFramework/GroupLocationMessage.h>
#import <ThreemaFramework/GroupMessageProcessor.h>
#import <ThreemaFramework/GroupRenameMessage.h>
#import <ThreemaFramework/GroupRequestSyncMessage.h>
#import <ThreemaFramework/GroupSetPhotoMessage.h>
#import <ThreemaFramework/GroupTextMessage.h>
#import <ThreemaFramework/GroupVideoMessage.h>
#import <ThreemaFramework/ImageMessageEntity.h>
#import <ThreemaFramework/LastGroupSyncRequest.h>
#import <ThreemaFramework/LastLoadedMessageIndex.h>
#import <ThreemaFramework/LicenseStore.h>
#import <ThreemaFramework/LocationMessage.h>
#import <ThreemaFramework/LogFormatterCustom.h>
#import <ThreemaFramework/LoggingDescriptionProtocol.h>
#import <ThreemaFramework/LogLevelCustom.h>
#import <ThreemaFramework/NaClCrypto.h>
#import <ThreemaFramework/Nonce.h>
#import <ThreemaFramework/NonceHasher.h>
#import <ThreemaFramework/NSData+ConvertUInt64.h>
#import <ThreemaFramework/MessageDecoder.h>
#import <ThreemaFramework/MessageListenerDelegate.h>
#import <ThreemaFramework/MessageProcessorDelegate.h>
#import <ThreemaFramework/MessageProcessor.h>
#import <ThreemaFramework/MDMSetup.h>
#import <ThreemaFramework/MyIdentityStore.h>
#import <ThreemaFramework/ProtocolDefines.h>
#import <ThreemaFramework/PushPayloadDecryptor.h>
#import <ThreemaFramework/QuotedMessageProtocol.h>
#import <ThreemaFramework/ReceiptType.h>
#import <ThreemaFramework/ServerAPIConnector.h>
#import <ThreemaFramework/UnknownTypeMessage.h>
#import <ThreemaFramework/UploadProgressDelegate.h>
#import <ThreemaFramework/URLSenderItem.h>
#import <ThreemaFramework/UserSettings.h>
#import <ThreemaFramework/ThreemaUtilityObjC.h>
#import <ThreemaFramework/RequestedConversation.h>
#import <ThreemaFramework/RequestedThumbnail.h>
#import <ThreemaFramework/ServerConnector.h>
#import <ThreemaFramework/SocketProtocolDelegate.h>
#import <ThreemaFramework/SSLCAHelper.h>
#import <ThreemaFramework/SystemMessage.h>
#import <ThreemaFramework/Tag.h>
#import <ThreemaFramework/TaskExecutionTransactionDelegate.h>
#import <ThreemaFramework/TextMessage.h>
#import <ThreemaFramework/TextStyleUtils.h>
#import <ThreemaFramework/TMAManagedObject.h>
#import <ThreemaFramework/TypingIndicatorMessage.h>
#import <ThreemaFramework/VideoMessageEntity.h>
#import <ThreemaFramework/ValidationLogger.h>
#import <ThreemaFramework/WebClientSession.h>
#import <ThreemaFramework/QuoteUtil.h>
#import <ThreemaFramework/ContactGroupPickerViewController.h>
#import <ThreemaFramework/KKPasscodeLock.h>
#import <ThreemaFramework/TouchIdAuthentication.h>
#import <ThreemaFramework/TextStyleUtils.h>
#import <ThreemaFramework/UIImage+ColoredImage.h>
#import <ThreemaFramework/JKLLockScreenViewController.h>
#import <ThreemaFramework/FLAnimatedImage.h>
#import <ThreemaFramework/FLAnimatedImageView.h>
#import <ThreemaFramework/GroupPhotoSender.h>
#import <ThreemaFramework/UITextField+Themed.h>
#import <ThreemaFramework/ParallaxPageViewController.h>
#import <ThreemaFramework/PageContentViewController.h>
#import <ThreemaFramework/PageView.h>
#import <ThreemaFramework/ThemedTableViewController.h>
#import <ThreemaFramework/CallEntity.h>
#import <ThreemaFramework/ThreemaError.h>
#import <ThreemaFramework/GroupCallEntity.h>
#import <ThreemaFramework/ObjcCspE2eFs_Version.h>

//! Project version number for ThreemaFramework.
FOUNDATION_EXPORT double ThreemaFrameworkVersionNumber;

//! Project version string for ThreemaFramework.
FOUNDATION_EXPORT const unsigned char ThreemaFrameworkVersionString[];
