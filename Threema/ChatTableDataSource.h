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

#import <Foundation/Foundation.h>
#import "ChatViewController.h"

@interface ChatTableDataSource : NSObject <UITableViewDataSource, UITableViewDelegate>

@property UIColor *backgroundColor;
@property CGFloat rotationOverrideTableWidth;

@property (weak) ChatViewController *chatVC;

@property BOOL searching;
@property NSString *searchPattern;

@property BOOL forceShowSections;

@property BOOL openTableView;

- (BOOL)hasData;

- (NSIndexPath *)indexPathForLastCell;
- (NSIndexPath *)indexPathForMessage:(BaseMessage *)message;

- (void)addObjectsFrom:(ChatTableDataSource *)otherDataSource;

- (id)objectForIndexPath:(NSIndexPath *)indexPath;

- (void)addMessage:(BaseMessage *)message newSections:(NSMutableIndexSet *)newSections newRows:(NSMutableArray *)newRows visible:(BOOL)visible;

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;

- (void)removeObjectFromCellHeightCache:(NSIndexPath *)indexPath;

- (void)refreshSectionHeadersInTableView:(UITableView *)tableView;

- (NSInteger)numberOfLoadedMessages;

- (NSIndexPath *)getUnreadLineIndexPath;
- (BOOL)removeUnreadLine;
- (void)cleanCellHeightCache;

@end
