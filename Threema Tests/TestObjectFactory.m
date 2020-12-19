//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

#import "TestObjectFactory.h"
#import "MyIdentityStore.h"
#import "NaClCrypto.h"
#import "ProtocolDefines.h"

@interface TestObjectFactory ()


@end

@implementation TestObjectFactory

+ (instancetype)testObjectFactory {
    TestObjectFactory *factory = [[TestObjectFactory alloc] init];
    
    return factory;
}

+ (instancetype)testObjectFactoryTemporaryContext {
    TestObjectFactory *factory = [[TestObjectFactory alloc] init];
    
    return factory;
}

- (NSData *) groupIdForString:(NSString *)groupIdString {
    return [[groupIdString dataUsingEncoding:NSASCIIStringEncoding] subdataWithRange:NSMakeRange(0, kGroupIdLen)];
}

- (Conversation *)groupConversationWithId:(NSString *)groupId {
    NSData *groupIdData = [self groupIdForString: groupId];
    
    Conversation *conversation = [_entityManager.entityFetcher conversationForGroupId:groupIdData];
    if (conversation == nil) {
        conversation = [_entityManager.entityCreator conversation];
        conversation.groupId = groupIdData;
        conversation.groupMyIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
    }

    return conversation;
}

- (Contact *)contactWithIdentity:(NSString *)identity publicKey:(NSData *)publicKey {
    
    Contact *contact = [_entityManager.entityFetcher contactForId: identity];
    if (contact == nil) {
        contact = [_entityManager.entityCreator contact];
        contact.identity = identity;
        contact.publicKey = publicKey;
        contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelUnverified];
    }
    
    return contact;
}

- (Conversation *)conversationWithEchoEcho {
    Contact *contact = [self contactWithIdentity:@"ECHOECHO" publicKey:[[NSData alloc] initWithBase64EncodedString:@"4a6a1b34 dcef15d4 3cb74de2 fd36091b e99fbbaf 126d099d 47d83d91 9712c72b" options:NSDataBase64DecodingIgnoreUnknownCharacters]];
    
    Conversation *conversation = [_entityManager conversationForContact:contact createIfNotExisting:YES];
    
    return conversation;
}

@end
