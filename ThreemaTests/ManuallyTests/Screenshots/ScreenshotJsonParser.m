//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "ScreenshotJsonParser.h"
#import "MyIdentityStore.h"
#import "ContactEntity.h"
#import "Conversation.h"
#import "NSString+Hex.h"
#import "MediaConverter.h"
#import "ProtocolDefines.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "NaClCrypto.h"
#import <ThreemaFramework/ThreemaFramework-Swift.h>
#import <ThreemaFramework/BaseMessage.h>
#import <ThreemaFramework/BallotChoice.h>
#import <ThreemaFramework/ServerConnector.h>
#import <ThreemaFramework/EntityCreator.h>
#import <ThreemaFramework/EntityFetcher.h>
#import <ThreemaFramework/FileMessageEncoder.h>
#import <ThreemaFramework/QuoteUtil.h>
#import <CommonCrypto/CommonDigest.h>

#import <UIKit/UIImage.h>

#import <UIKit/UIImage.h>

@interface ScreenshotJsonParser ()

@property NSString *myIdentity;
@property NSBundle *bundle;
@property EntityManager *entityManager;

@end

@implementation ScreenshotJsonParser

#define JSON_FILE_KEY_METADATA @"x"
#define JSON_FILE_KEY_METADATA_HEIGHT @"h"
#define JSON_FILE_KEY_METADATA_WIDTH @"w"


- (instancetype)init
{
    self = [super init];
    if (self) {
        _entityManager = [[EntityManager alloc] init];
    }
    return self;
}

- (void)clearAll {
    [[ServerConnector sharedServerConnector] disconnect:ConnectionInitiatorApp];
    
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    [myIdentityStore destroy];
    
    [_entityManager performSyncBlockAndSafe:^{
        NSArray *conversations = [_entityManager.entityFetcher allConversations];
        for (Conversation* conversation in conversations) {
            [[_entityManager entityDestroyer] deleteObjectWithObject:conversation];
        }

        NSArray *contacts = [_entityManager.entityFetcher allContacts];
        for (ContactEntity* contact in contacts) {
            [[_entityManager entityDestroyer] deleteObjectWithObject:contact];
        }
    }];
}

- (void)loadDataFromDirectory:(NSString*)directory {
    _bundle = [NSBundle bundleWithPath:directory];
    ThreemaApp currentApp = [ThreemaAppObjc current];
    if (currentApp == ThreemaAppWork || currentApp == ThreemaAppOnPrem) {
        NSString *loginPath = [_bundle pathForResource:@"login" ofType:@"json"];
        NSData *loginJsonData = [NSData dataWithContentsOfFile:loginPath];
        NSError *error;
        NSDictionary *loginJson = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:loginJsonData options:0 error:&error];
        if (loginJson == nil) {
            NSLog(@"Error parsing login json data %@, %@", error, [error userInfo]);
            return;
        }
        [[LicenseStore sharedLicenseStore] setLicenseUsername:loginJson[@"username"]];
        [[LicenseStore sharedLicenseStore] setLicensePassword:loginJson[@"password"]];
        
        if (currentApp == ThreemaAppOnPrem) {
            [[LicenseStore sharedLicenseStore] setOnPremConfigUrl:loginJson[@"server"]];
        }
    }
    
    NSString *path = [_bundle pathForResource:@"data" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        NSLog(@"Error parsing data json data %@, %@", error, [error userInfo]);
        return;
    }

    NSString *idBackup = [json objectForKey:@"identity"];
    [self handleIdBackup:idBackup];
    _myIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
        
    NSMutableDictionary *profile = [NSMutableDictionary new];
    [profile setValue:[self fileDataFromFileNamed:@"me.jpg"] forKey:@"ProfilePicture"];
    [profile removeObjectForKey:@"LastUpload"];
    [[MyIdentityStore sharedMyIdentityStore] setProfilePicture:profile];
    
    if ([LicenseStore requiresLicenseKey]) {
        [[MyIdentityStore sharedMyIdentityStore] setPushFromName:@"Julia S."];
        [[MyIdentityStore sharedMyIdentityStore] setLinkedEmail:@"***@***"];
        [[MyIdentityStore sharedMyIdentityStore] setLinkedMobileNo:@"1234567890"];
        
        [[MyIdentityStore sharedMyIdentityStore] setLinkEmailPending:false];
        [[MyIdentityStore sharedMyIdentityStore] setLinkMobileNoPending:false];
    } else {
        [[MyIdentityStore sharedMyIdentityStore] setPushFromName:@"Eva Anonymous"];
    }
    
    [_entityManager performSyncBlockAndSafe:^{
        NSDictionary *contactData = [json objectForKey:@"contacts"];
        [self handleContacts:contactData];
    }];
    
    [_entityManager performSyncBlockAndSafe:^{
        NSDictionary *groupData = [json objectForKey:@"groups"];
        [self handleGroups:groupData];
    }];
}

- (void)handleIdBackup:(NSString *)idBackup {
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [myIdentityStore restoreFromBackup:idBackup withPassword:@"12345678" onCompletion:^{
            myIdentityStore.serverGroup = @"ae";
            [myIdentityStore storeInKeychain];
            
            dispatch_semaphore_signal(sema);
        } onError:^(NSError *error) {
            [self fail:error.localizedDescription];
            dispatch_semaphore_signal(sema);
        }];
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}

- (void)fail:(NSString *)reason {
    NSLog(@"failed: %@", reason);
    NSAssert(FALSE, reason);
}

- (void)handleContacts:(NSDictionary *)contactData {
    NSEnumerator *enumerator = [contactData keyEnumerator];
    id identity;
    
    while ((identity = [enumerator nextObject])) {
        NSDictionary *data = [contactData objectForKey:identity];
        if (![identity isEqualToString:@"ECHOECHO"]) {
            [self handleContact:identity data:data];
        }
    }
}

- (void)handleContact:(NSString *)identity data:(NSDictionary *)data {
    ContactEntity *contact = [_entityManager.entityCreator contact];
    contact.identity = identity;
    contact.imageData = [self localizedFileForKey:@"avatar" in:data];
    contact.verifiedEmail = [self localizedStringForKey:@"mail" in:data];
    
    NSNumber *verificationLevel = [data objectForKey:@"verification"];
    contact.verificationLevel = [NSNumber numberWithInt: verificationLevel.intValue - 1];
    BOOL isWork = [[data objectForKey:@"isWork"] boolValue];
    if (isWork) {
        contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
        if ([LicenseStore requiresLicenseKey]) {
            contact.workContact = [NSNumber numberWithBool:YES];
        }
        
        NSMutableOrderedSet *workIdentities = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].workIdentities];
        [workIdentities addObject:contact.identity];
        [UserSettings sharedUserSettings].workIdentities = workIdentities;
    }
    
    NSString *publicKey = [data objectForKey:@"pk"];
    contact.publicKey = [publicKey decodeHex];
    
    NSArray *names = [self localizedArrayForKey:@"name" in:data];
    if (names.count == 2) {
        contact.firstName = names[0];
        contact.lastName = names[1];
    }
    
    NSArray *conversationData = [data objectForKey:@"conversation"];
    if (conversationData) {
        Conversation *conversation = [_entityManager.entityCreator conversation];
        conversation.contact = contact;
        
        [self handleConversation:conversation data:conversationData];
        
        MessageFetcher *messageFetcher = [[MessageFetcher alloc] initFor:conversation with:_entityManager];
        conversation.lastMessage = [messageFetcher lastMessage];
    }
}

- (void)handleConversation:(Conversation *)conversation data:(NSArray *)data {
    for (NSDictionary *messageData in data) {
        NSString *type = [messageData objectForKey:@"type"];
        
        BaseMessage *message;
        if ([type isEqualToString:@"TEXT"]) {
            message = [self handleTextMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"IMAGE"]) {
            message = [self handleImageMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"AUDIO"]) {
            message = [self handleAudioMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"BALLOT"]) {
            message = [self handleBallotMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"FILE"]) {
            message = [self handleFileMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"VOIP_STATUS"]) {
            message = [self handleCallMessage:messageData inConversation:conversation];
        } else if ([type isEqualToString:@"LOCATION"]) {
            message = [self handleLocationMessage:messageData inConversation:conversation];
        }
        
        NSNumber *dateOffsetMin = [messageData objectForKey:@"date"];
        NSInteger dateOffsetS = dateOffsetMin.integerValue * 60;
        message.date = [NSDate dateWithTimeInterval:dateOffsetS sinceDate:_referenceDate];
        conversation.lastUpdate = message.date;
        
        BOOL outgoing = ((NSNumber *)[messageData objectForKey:@"out"]).boolValue;
        message.isOwn = [NSNumber numberWithBool:outgoing];
        if (outgoing == NO) {
            message.sender = conversation.contact;
        }
        
        message.sent = [NSNumber numberWithBool:YES];
        message.remoteSentDate = message.date;
        message.delivered = [NSNumber numberWithBool:YES];
        
        NSNumber *read = ((NSNumber *)[messageData objectForKey:@"read"]);
        if (!read) {
            message.read = [NSNumber numberWithBool:YES];
            message.readDate = message.date;
        } else {
            message.read = read;
            int unreadMessageCount = conversation.unreadMessageCount.intValue;
            unreadMessageCount++;
            conversation.unreadMessageCount = [NSNumber numberWithInt:unreadMessageCount];
        }
        
        NSString *state = [messageData objectForKey:@"state"];
        if ([state isEqualToString:@"USERACK"]) {
            message.userackDate = message.date;
            message.userack = [NSNumber numberWithBool:YES];
        }
        
        // groups only
        NSString *identity = [messageData objectForKey:@"identity"];
        if ([identity isEqualToString:@"$"] == NO) {
            message.sender = [_entityManager.entityFetcher contactForId:identity];
        }
    }
}

- (Conversation *)createGroupConversationFromData:(NSDictionary *)groupData {
    GroupEntity *groupEntity = [_entityManager.entityCreator groupEntity];
    Conversation *conversation = [_entityManager.entityCreator conversation];
    
    NSString *groupId = [groupData objectForKey:@"id"];
    conversation.groupId = [groupId decodeHex];
    groupEntity.groupId = [groupId decodeHex];
    
    NSString *creator = [groupData objectForKey:@"creator"];
    if ([creator isEqualToString:_myIdentity] == NO) {
        ContactEntity *creatorContact = [_entityManager.entityFetcher contactForId:creator];
        conversation.contact = creatorContact;
        groupEntity.groupCreator = creator;
    }
    groupEntity.state = [[NSNumber alloc] initWithInt:GroupStateActive];
    
    NSData *avatar = [self localizedFileForKey:@"avatar" in:groupData];
    if (avatar) {
        ImageData *dbImage = [_entityManager.entityCreator imageData];
        dbImage.data = avatar;
        conversation.groupImage = dbImage;
    }
    
    conversation.groupName = [self localizedStringForKey:@"name" in:groupData];
    conversation.groupMyIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
    
    NSArray *memberNames = [groupData objectForKey:@"members"];
    NSSet *members = [self groupMembersFrom:memberNames];
    [conversation addMembers:members];

    return conversation;
}

- (NSSet *)groupMembersFrom:(NSArray *)memberNames {
    NSMutableSet *members = [NSMutableSet setWithCapacity:memberNames.count];
    
    for (NSString *name in memberNames) {
        ContactEntity *contact = [_entityManager.entityFetcher contactForId:name];
        [members addObject:contact];
    }
    
    return members;
}

- (void)handleGroups:(NSDictionary *)groupsData {
    for (NSDictionary *groupData in groupsData) {
        Conversation *conversation = [self createGroupConversationFromData:groupData];
        
        NSArray *conversationData = [groupData objectForKey:@"conversation"];
        if (conversationData) {
            [self handleConversation:conversation data:conversationData];
        }
    }
}


/// Handle text and parse QuoteV1 into QuoteV2
- (BaseMessage *)handleTextMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    BaseMessage *lastMessage = conversation.lastMessage;
    TextMessage *message = [_entityManager.entityCreator textMessageForConversation:conversation];
    message.text = [self localizedStringForKey:@"content" in:messageData];
    if ([message.text containsString:@"> "]) {
        message.quotedMessageId = lastMessage.id;
        NSString *quotedIdentity = nil;
        NSString *remainingBody = nil;
        NSString *quotedText = [QuoteUtil parseQuoteFromMessage:message.text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
        message.text = remainingBody;
    }
    
    return message;
}

- (BaseMessage *)handleImageMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    FileMessageEntity *message = [_entityManager.entityCreator fileMessageEntityForConversation:conversation];

    NSDictionary *captions = messageData[@"caption"];
    NSString *caption = nil;
    if (captions) {
        caption = [captions objectForKey:_languageCode];
        if (caption == nil) {
            caption = [captions objectForKey:@"default"];
        }
    }
    
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    message.encryptionKey = [NSData dataWithBytes:digest length:16];
    message.fileName = [self localizedStringForKey:@"content" in:messageData];
    message.fileSize = [NSNumber numberWithInt:2308565];
    message.type = @1;
    message.mimeType = @"image/jpeg";
    message.mimeTypeThumbnail = @"image/jpeg";

    FileData *fileData = [_entityManager.entityCreator fileData];
    NSData *data = [self localizedFileForKey:@"content" in:messageData];
    if (data) {
        fileData.data = data;

        UIImage *image = [UIImage imageWithData:data];
        message.width = [NSNumber numberWithInt:image.size.width];
        message.height = [NSNumber numberWithInt:image.size.height];
        UIImage *thumbnail = [MediaConverter getThumbnailForImage:image];
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQualityLow);
        ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
        dbThumbnail.data = thumbnailData;
        dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
        dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
        message.thumbnail = dbThumbnail;

    } else {
        fileData.data = [NSData data];
    }
    message.data = fileData;
    message.caption = caption;
    
    message.json = [FileMessageEncoder jsonStringForFileMessageEntity:message];
    
    message.blobId = [[NaClCrypto sharedCrypto] randomBytes:kBlobIdLen];
        
    return message;
}

- (BaseMessage *)handleAudioMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    AudioMessageEntity *message = [_entityManager.entityCreator audioMessageEntityForConversation:conversation];
    
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    message.encryptionKey = [NSData dataWithBytes:digest length:16];
    message.duration = [NSNumber numberWithInt:42];
    message.audioSize = [NSNumber numberWithInt:2308565];
    message.audioBlobId = [NSData dataWithBytes:digest length:16];

    NSData *data = [self localizedFileForKey:@"content" in:messageData];
    if (data) {
        AudioData *audioData = [_entityManager.entityCreator audioData];
        audioData.data = data;
        message.audio = audioData;
    }
    
    return message;
}

- (BaseMessage *)handleLocationMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    LocationMessage *message = [_entityManager.entityCreator locationMessageForConversation:conversation];
    NSArray *location = [self localizedArrayForKey:@"content" in:messageData];
    if (location.count == 4) {
        message.latitude = location[0];
        message.longitude = location[1];
        message.accuracy = location[2];
        message.poiName = location[3];
    }
    
    return message;
}

- (BaseMessage *)handleFileMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    FileMessageEntity *message = [_entityManager.entityCreator fileMessageEntityForConversation:conversation];
    message.fileName = [self localizedStringForKey:@"content" in:messageData];
    message.fileSize = [NSNumber numberWithInt:2308565];
    message.mimeType = [messageData objectForKey:@"mime-type"];
    
    // Add some random data
    FileData *fileData = [_entityManager.entityCreator fileData];
    fileData.data = [[NaClCrypto sharedCrypto] randomBytes:10];
    [message setData:fileData];

    return message;
}

- (BaseMessage *)handleCallMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    SystemMessage *message = [_entityManager.entityCreator systemMessageForConversation:conversation];
    
    BOOL outgoing = ((NSNumber *)[messageData objectForKey:@"out"]).boolValue;
    NSDictionary *callData = [messageData objectForKey:@"content"];
    
    NSString *type = [callData objectForKey:@"type"];
    if ([type isEqualToString:@"answered"]) {
        int duration = ((NSNumber *)[callData objectForKey:@"duration"]).intValue;
        NSString *durationString = [self timeFormatted:duration];
        NSDictionary *argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallTime": durationString, @"CallInitiator": [NSNumber numberWithBool:outgoing]};
        
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
        message.arg = data;
        message.type = [NSNumber numberWithInteger:kSystemMessageCallEnded];
        conversation.lastMessage = message;
    }
    
    return message;
}

- (BaseMessage *)handleBallotMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    BallotMessage *message = [_entityManager.entityCreator ballotMessageForConversation:conversation];
    
    NSDictionary *ballotData = [messageData objectForKey:@"content"];

    Ballot *ballot = [_entityManager.entityCreator ballot];
    NSData *idData = [NSData data];
    ballot.id = idData;
    ballot.title = [self localizedStringForKey:@"question" in:ballotData];
    ballot.conversation = conversation;
    
    if ([[ballotData objectForKey:@"state"] isEqualToString:@"closed"]) {
        [ballot setClosed];
    }
    
    NSArray *choices = [ballotData objectForKey:@"choices"];
    [self handleBallot:ballot choices:choices];
    
    
    message.ballot = ballot;
    
    return message;
}

- (void)handleBallot:(Ballot *)ballot choices:(NSArray *)choices {
    NSInteger count = 0;
    for (NSDictionary *choiceData in choices) {
        BallotChoice *ballotChoice = [_entityManager.entityCreator ballotChoice];
        ballotChoice.name = [self localizedStringForKey:@"choice" in:choiceData];
        ballotChoice.id = [NSNumber numberWithInteger:count];
        ballotChoice.orderPosition = [NSNumber numberWithInteger:count];
        
        NSDictionary *votes = [choiceData objectForKey:@"votes"];
        [self handleBallotChoice:ballotChoice voteData:votes];

        [ballot addChoicesObject:ballotChoice];
        
        ++count;
    }
}

- (void)handleBallotChoice:(BallotChoice *)choice voteData:(NSDictionary *)voteData {
    NSEnumerator *enumerator = [voteData keyEnumerator];
    NSString *identity;
    
    while ((identity = [enumerator nextObject])) {
        BallotResult *ballotResult = [_entityManager.entityCreator ballotResult];
        ballotResult.value = [voteData objectForKey:identity];

        if ([identity isEqualToString:@"$"]) {
            ballotResult.participantId = _myIdentity;
        } else {
            ballotResult.participantId = identity;
        }
        
        [choice addResultObject:ballotResult];
    }
}

- (id)localizedObjectForKey:(NSString *)key in:(NSDictionary *)dictionary {
    NSDictionary *localizations = [dictionary objectForKey:key];
    
    id result = [localizations objectForKey:_languageCode];
    if (result == nil) {
        result = [localizations objectForKey:@"default"];
    }
    
    return result;
}

- (NSString *)localizedStringForKey:(NSString *)key in:(NSDictionary *)dictionary {
    return (NSString *)[self localizedObjectForKey:key in:dictionary];
}

- (NSData *)localizedFileForKey:(NSString *)key in:(NSDictionary *)dictionary {
    NSString *fileName = [self localizedObjectForKey:key in:dictionary];
    
    return [self fileDataFromFileNamed:fileName];
}

- (NSArray *)localizedArrayForKey:(NSString *)key in:(NSDictionary *)dictionary {
    return (NSArray *)[self localizedObjectForKey:key in:dictionary];
}

- (NSData *)fileDataFromFileNamed:(NSString *)imageName {
    NSString *path = [_bundle pathForResource:imageName ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:path];

    return data;
}

- (NSString *)timeFormatted:(int)totalSeconds {
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60);
    return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}

@end
