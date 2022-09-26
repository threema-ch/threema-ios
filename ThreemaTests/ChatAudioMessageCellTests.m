//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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
#import "Threema_Tests-Swift.h"
#import "ChatAudioMessageCell.h"
#import "AudioMessageEntity.h"


@interface ChatAudioMessageCellTestsOld : XCTestCase

@end

@implementation ChatAudioMessageCellTestsOld {
    ChatAudioMessageCellPreparer *preparer;
}

- (void)setUp {
    // necessary for ValidationLogger
    [AppGroup setGroupId:@"group.ch.threema"]; //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

    self->preparer = [ChatAudioMessageCellPreparer alloc];
    [self->preparer prepareDatabase];
}

- (void)testInitialState {
    AudioMessageEntity *message = [self->preparer createAudioMessageEntity];
    
    ChatAudioMessageCell *cell = [[ChatAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"testAudioCell" transparent:NO];
    cell.message = message;
    
    expect(cell.activityIndicator).to.beNil;
    expect(cell.progressBar).to.beNil;
}

- (void)testSending {
    AudioMessageEntity *message = [self->preparer createAudioMessageEntity];
    message.audio = [self->preparer createAudioData];
    message.audioSize = [NSNumber numberWithFloat:1.0];
    message.isOwn = [NSNumber numberWithBool:YES];

    ChatAudioMessageCell *cell = [[ChatAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"testAudioCell" transparent:NO];
    cell.message = message;

    [cell updateProgress];
    
    expect(cell.resendButton.hidden).to.beNil;
    expect(cell.activityIndicator.hidden).to.equal(NO);
    expect(cell.progressBar).to.beNil;
}

- (void)testSent {
    AudioMessageEntity *message = [self->preparer createAudioMessageEntity];
    message.audio = [self->preparer createAudioData];
    message.audioSize = [NSNumber numberWithFloat:1.0];
    message.isOwn = [NSNumber numberWithBool:YES];
    message.progress = nil;
    message.sent = [NSNumber numberWithBool:YES];

    ChatAudioMessageCell *cell = [[ChatAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"testAudioCell" transparent:NO];
    cell.message = message;

    [cell updateProgress];
    
    expect(cell.resendButton.hidden).to.beNil;
    expect(cell.activityIndicator.hidden).to.equal(YES);
    expect(cell.progressBar).to.beNil;
}

- (void)testSendFailed {
    AudioMessageEntity *message = [self->preparer createAudioMessageEntity];
    message.audio = [self->preparer createAudioData];
    message.audioSize = [NSNumber numberWithFloat:1.0];
    message.isOwn = [NSNumber numberWithBool:YES];
    message.progress = nil;
    message.sent = [NSNumber numberWithBool:NO];
    message.sendFailed = [NSNumber numberWithBool:YES];
    
    ChatAudioMessageCell *cell = [[ChatAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"testAudioCell" transparent:NO];
    cell.message = message;

    [cell updateProgress];
    
    expect(cell.resendButton.hidden).to.equal(NO);
    expect(cell.activityIndicator.hidden).to.equal(YES);
    expect(cell.progressBar).to.beNil;
}

@end
