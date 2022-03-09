//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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
#import "EntityManager.h"
#import "Contact.h"
#import "Conversation.h"
#import "GroupProxy.h"
#import "NSString+Hex.h"
#import "MediaConverter.h"
#import "ProtocolDefines.h"
#import "ServerConnector.h"
#import "UserSettings.h"
#import "LicenseStore.h"

#import <UIKit/UIImage.h>

@interface ScreenshotJsonParser ()

@property NSString *myIdentity;
@property NSBundle *bundle;
@property EntityManager *entityManager;

@end

@implementation ScreenshotJsonParser

- (instancetype)init
{
    self = [super init];
    if (self) {
        _entityManager = [[EntityManager alloc] initForBackgroundProcess:NO];
    }
    return self;
}

- (void)clearAll {
    [[ServerConnector sharedServerConnector] disconnect];
    
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    [myIdentityStore destroy];
    
    [_entityManager performSyncBlockAndSafe:^{
        NSArray *conversations = [_entityManager.entityFetcher allConversations];
        for (Conversation* conversation in conversations) {
            [[_entityManager entityDestroyer] deleteObjectWithObject:conversation];
        }

        NSArray *contacts = [_entityManager.entityFetcher allContacts];
        for (Contact* contact in contacts) {
            [[_entityManager entityDestroyer] deleteObjectWithObject:contact];
        }
    }];
}

- (void)loadDataFromDirectory:(NSString*)directory {
    _bundle = [NSBundle bundleWithPath:directory];
    
    NSString *path = [_bundle pathForResource:@"data" ofType:@"json"];

    NSData *jsonData = [NSData dataWithContentsOfFile:path];
    
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        NSLog(@"Error parsing ballot json data %@, %@", error, [error userInfo]);
        return;
    }

    NSString *idBackup = [json objectForKey:@"identity"];
    [self handleIdBackup:idBackup];
    _myIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
        
    NSMutableDictionary *profile = [NSMutableDictionary new];
    [profile setValue:[self imageDataFromFileNamed:@"me.jpg"] forKey:@"ProfilePicture"];
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
        [self handleContact:identity data:data];
    }
}

- (void)handleContact:(NSString *)identity data:(NSDictionary *)data {
    Contact *contact = [_entityManager.entityCreator contact];
    contact.identity = identity;
    contact.imageData = [self localizedImageForKey:@"avatar" in:data];
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
        
        BOOL outgoing = ((NSNumber *)[messageData objectForKey:@"out"]).boolValue;
        message.isOwn = [NSNumber numberWithBool:outgoing];
        if (outgoing == NO) {
            message.sender = conversation.contact;
        } else {
            message.readDate = message.date;
        }
        
        message.sent = [NSNumber numberWithBool:YES];
        message.delivered = [NSNumber numberWithBool:YES];
        
        NSNumber *read = ((NSNumber *)[messageData objectForKey:@"read"]);
        if (!read) {
            message.read = [NSNumber numberWithBool:YES];
        } else {
            message.read = read;
            int unreadMessageCount = conversation.unreadMessageCount.intValue;
            unreadMessageCount++;
            conversation.unreadMessageCount = [NSNumber numberWithInt:unreadMessageCount];
        }
        
        NSString *state = [messageData objectForKey:@"state"];
        if ([state isEqualToString:@"USERACK"]) {
            message.userackDate = [NSDate date];
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
    Conversation *conversation = [_entityManager.entityCreator conversation];
    
    NSString *groupId = [groupData objectForKey:@"id"];
    conversation.groupId = [groupId decodeHex];
    
    NSString *creator = [groupData objectForKey:@"creator"];
    if ([creator isEqualToString:_myIdentity] == NO) {
        Contact *creatorContact = [_entityManager.entityFetcher contactForId:creator];
        conversation.contact = creatorContact;
    }
    
    NSData *avatar = [self localizedImageForKey:@"avatar" in:groupData];
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
        Contact *contact = [_entityManager.entityFetcher contactForId:name];
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

- (BaseMessage *)handleTextMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    TextMessage *message = [_entityManager.entityCreator textMessageForConversation:conversation];
    message.text = [self localizedStringForKey:@"content" in:messageData];
    
    return message;
}

- (BaseMessage *)handleImageMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    ImageMessage *message = [_entityManager.entityCreator imageMessageForConversation:conversation];
    
    ImageData *imageData = [_entityManager.entityCreator imageData];
    NSDictionary *captions = messageData[@"caption"];
    NSString *caption = nil;
    if (captions) {
        caption = [captions objectForKey:_languageCode];
        if (caption == nil) {
            caption = [captions objectForKey:@"default"];
        }
    }
    [imageData setCaption:caption];
    
    NSData *data = [self localizedImageForKey:@"content" in:messageData];
    if (data) {
        imageData.data = data;
        [imageData setCaption:caption];
        
        UIImage *image = [UIImage imageWithData:data];
        UIImage *thumbnail = [MediaConverter getThumbnailForImage:image];
        NSData *thumbnailData = UIImageJPEGRepresentation(thumbnail, kJPEGCompressionQualityLow);
        
        ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
        dbThumbnail.data = thumbnailData;
        dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
        dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
        [imageData setCaption:caption];
        message.thumbnail = dbThumbnail;
    } else {
        imageData.data = [NSData data];
    }
    
    message.image = imageData;
    

    return message;
}

- (BaseMessage *)handleAudioMessage:(NSDictionary *)messageData inConversation:(Conversation *)conversation {
    AudioMessage *message = [_entityManager.entityCreator audioMessageForConversation:conversation];
    message.duration = [NSNumber numberWithInt:42];
    
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
    FileMessage *message = [_entityManager.entityCreator fileMessageForConversation:conversation];
    message.fileName = [self localizedStringForKey:@"content" in:messageData];
    message.fileSize = [NSNumber numberWithInt:2308565];

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

- (NSData *)localizedImageForKey:(NSString *)key in:(NSDictionary *)dictionary {
    NSString *imageName = [self localizedObjectForKey:key in:dictionary];
    
    return [self imageDataFromFileNamed:imageName];
}

- (NSArray *)localizedArrayForKey:(NSString *)key in:(NSDictionary *)dictionary {
    return (NSArray *)[self localizedObjectForKey:key in:dictionary];
}

- (NSData *)imageDataFromFileNamed:(NSString *)imageName {
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
