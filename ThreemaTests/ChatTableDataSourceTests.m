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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <Expecta/Expecta.h>
#import <ThreemaFramework/AppGroup.h>
#import "Threema_Tests-Swift.h"
#import "Old_ChatTableDataSource.h"
#import "ChatTextMessageCell.h"
#import "TextMessage.h"

@interface ChatTableDataSourceTests : XCTestCase

@property UITableView *tableview;
@property NSDate *dateOffset;

@end

@implementation ChatTableDataSourceTests {
    ChatTableDataSourcePreparer *preparer;
}

- (void)setUp {
    // necessary for ValidationLogger
    [AppGroup setGroupId:@"group.ch.threema"]; //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

    self->preparer = [ChatTableDataSourcePreparer alloc];
    [self->preparer prepareDatabase];
    
    _tableview = [UITableView new];
    
    _dateOffset = [NSDate dateWithTimeIntervalSinceReferenceDate: 20 * 365 * 24 * 60 * 60 ];
}

- (void)testMessageOrder {
    Old_ChatTableDataSource *ctds = [[Old_ChatTableDataSource alloc] init];

    [self addMessagesTo:ctds count:2 timeOffset:60];

    [self check:ctds section:0 row:0 forText:@"test 0"];
//    [self check:ctds section:0 row:1 forText:@"test 1"];
//
//    [self getIncrementedDateBySeconds:24 * 60 * 60];
//    
//    [self addInbetweenMessageTo:ctds timeOffset:60 text:@"inbetween 0"];
//    [self addInbetweenMessageTo:ctds timeOffset:60 text:@"inbetween 1"];
//
//    [self getIncrementedDateBySeconds:24 * 60 * 60];
//
//    [self check:ctds section:0 row:1 forText:@"test 1"];
//    [self check:ctds section:1 row:0 forText:@"inbetween 0"];
//    [self check:ctds section:1 row:1 forText:@"inbetween 1"];
//
//    ChatTableDataSource *newCtds = [[ChatTableDataSource alloc] init];
//    [self addMessagesTo:newCtds count:2 timeOffset:60];
//    
//    [ctds addObjectsFrom:newCtds];
//    
//    [self check:ctds section:0 row:1 forText:@"test 1"];
//    [self check:ctds section:1 row:0 forText:@"inbetween 0"];
//    [self check:ctds section:1 row:1 forText:@"inbetween 1"];
//    [self check:ctds section:2 row:0 forText:@"test 0"];
//    [self check:ctds section:2 row:1 forText:@"test 1"];
}

- (NSDate *)getIncrementedDateBySeconds:(CGFloat)seconds {
    NSDate *newDate = [_dateOffset dateByAddingTimeInterval: seconds];
    _dateOffset = newDate;
    
    return newDate;
}

- (void)addInbetweenMessageTo:(Old_ChatTableDataSource *)ctds timeOffset:(NSInteger)timeOffset text:(NSString *)text {
    NSMutableIndexSet *newSections = [NSMutableIndexSet new];
    NSMutableArray *newRows = [NSMutableArray new];
    
    NSDate *messageDate = [self getIncrementedDateBySeconds:timeOffset];
    TextMessage *message = [self->preparer createTextMessageWithText:text date:messageDate];
    [ctds addMessage:message newSections:newSections newRows:newRows visible:NO];
}

- (void)addMessagesTo:(Old_ChatTableDataSource *)ctds count:(NSInteger)count timeOffset:(NSInteger)timeOffset {
    NSMutableIndexSet *newSections = [NSMutableIndexSet new];
    NSMutableArray *newRows = [NSMutableArray new];

    int index;
    for (index = 0; index < count; index = index + 1) {
        NSString *messageText = [NSString stringWithFormat:@"test %d", index];
        NSDate *messageDate = [self getIncrementedDateBySeconds:timeOffset];
        TextMessage *message = [self->preparer createTextMessageWithText:messageText date:messageDate];
        [ctds addMessage:message newSections:newSections newRows:newRows visible:NO];
    }
}

- (void)check:(Old_ChatTableDataSource *)ctds section:(NSInteger)section row:(NSInteger)row forText:(NSString *)text {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    ChatTextMessageCell *cell = (ChatTextMessageCell *)[ctds tableView:_tableview cellForRowAtIndexPath:indexPath];
    expect(((TextMessage *)cell.message).text).to.equal(text);
}

@end
