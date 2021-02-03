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

#import "RecentTableDataSource.h"
#import "EntityManager.h"
#import "ErrorHandler.h"
#import "PickerContactCell.h"
#import "PickerGroupCell.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface RecentTableDataSource ()

@property NSFetchedResultsController *fetchedResultsController;

@property NSMutableSet *selectedConversations;

@end

@implementation RecentTableDataSource

+ (instancetype)recentTableDataSource {
    return [[RecentTableDataSource alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initFetchedResultsController];
        _selectedConversations = [NSMutableSet set];
    }
    return self;
}

- (void)initFetchedResultsController
{
    EntityManager *entityManager = [[EntityManager alloc] init];
    _fetchedResultsController = [entityManager.entityFetcher fetchedResultsControllerForConversations];
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
    }
}

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
    Conversation *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    
    if (selected) {
        if (![_selectedConversations containsObject:conversation]) {
            [_selectedConversations addObject:conversation];
        }
    } else {
        if ([_selectedConversations containsObject:conversation]) {
            [_selectedConversations removeObject:conversation];
        }
    }
}

#pragma mark - ContactGroupDataSource

- (void)filterByWords:(NSArray *)words {
    ;// nope
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [_fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Conversation *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    if ([conversation isGroup]) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        PickerGroupCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PickerGroupCell"];
        cell.group = group;
        return cell;
    } else {
        PickerContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PickerContactCell"];
        cell.contact = conversation.contact;
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Conversation *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

@end
