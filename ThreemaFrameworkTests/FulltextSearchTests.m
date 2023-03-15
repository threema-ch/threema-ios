//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

#import <XCTest/XCTest.h>
#import <Expecta/Expecta.h>
#import <ThreemaFramework/AppGroup.h>
#import "ThreemaFrameworkTests-Swift.h"

@interface FulltextSearchTests : XCTestCase

@end

@implementation FulltextSearchTests {
    FulltextSearchPreparer *preparer;
}

NSInteger count = 10000;

- (void)setUp {
    // necessary for ValidationLogger
    [AppGroup setGroupId:@"group.ch.threema"]; //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

    self->preparer = [FulltextSearchPreparer alloc];
    [self->preparer prepareDatabase];
}

/// Should find text
/* TODO: Test fails when running all tests!?!?
- (void)testFindText {
    DatabaseContext *dbCnx = [[DatabaseContext alloc] initWithPersistentCoordinator:[self->preparer persistentStoreCoordinator] forBackgroundProcess:NO];
    EntityManager *em = [[EntityManager alloc] initWithDatabaseContext:dbCnx];
    
    ContactEntity *contact = [[em entityFetcher] contactForId:@"ECHOECHO"];
    Conversation *conversation = [[em entityFetcher] conversationForContact:contact];
    
    NSArray *result = [em.entityFetcher textMessagesContaining:@"gibts nicht" inConversation:conversation fetchLimit:0];
    expect([result count]).to.equal(0);

    result = [em.entityFetcher textMessagesContaining:@"yz" inConversation:conversation fetchLimit:0];
    expect([result count]).to.equal(count);

    result = [em.entityFetcher textMessagesContaining:@"z 99" inConversation:conversation fetchLimit:0];
    expect([result count]).to.equal(count / 10000 + count / 1000 + count / 100);

    result = [em.entityFetcher textMessagesContaining:@"z 9" inConversation:conversation fetchLimit:0];
    expect([result count]).to.equal(count / 10000 + count / 1000 + count / 100 + count / 10);
}
*/

/// Should be fast
- (void)testFindFast {
    DatabaseContext *dbCnx = [[DatabaseContext alloc] initWithPersistentCoordinator:[self->preparer persistentStoreCoordinator]];
    EntityManager *em = [[EntityManager alloc] initWithDatabaseContext:dbCnx];
    
    ContactEntity *contact = [[em entityFetcher] contactForId:@"ECHOECHO"];
    Conversation *conversation = [[em entityFetcher] conversationForContact:contact];
    
    CFTimeInterval startTime = CACurrentMediaTime();
    [em.entityFetcher textMessagesContaining:@"gibts nicht" inConversation:conversation fetchLimit:0];
    CFTimeInterval duration = CACurrentMediaTime() - startTime;
    expect(duration).to.beLessThan(0.1);

    startTime = CACurrentMediaTime();
    [em.entityFetcher textMessagesContaining:@"yz" inConversation:conversation fetchLimit:0];
    duration = CACurrentMediaTime() - startTime;
    expect(duration).to.beLessThan(0.1);
}

@end
