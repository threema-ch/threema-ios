//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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
#import "ErrorHandler.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "EntityFetcher.h"
#import "MyIdentityStore.h"
#import "ContactStore.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface RecentTableDataSource ()

@property NSFetchedResultsController *fetchedResultsController;
@property MessagePermission *messagePermission;

@property NSMutableSet *selectedConversations;

@end

@implementation RecentTableDataSource {
    GroupManager *groupManager;
}

+ (instancetype)recentTableDataSource {
    return [[RecentTableDataSource alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        BusinessInjector *businessInjector = [[BusinessInjector alloc] init];
        self->groupManager = businessInjector.groupManagerObjC;
        [self initFetchedResultsController:businessInjector];
        _selectedConversations = [NSMutableSet set];
    }
    return self;
}

- (void)initFetchedResultsController:(BusinessInjector *)businessInjector
{
    _messagePermission = [[MessagePermission alloc] initWithMyIdentityStore:businessInjector.myIdentityStore userSettings:businessInjector.userSettings groupManager:businessInjector.groupManagerObjC entityManager:businessInjector.entityManager];
    _fetchedResultsController = [businessInjector.entityManager.entityFetcher fetchedResultsControllerForConversations];
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
    }
}

- (BOOL)canSelectCellAtIndexPath:(NSIndexPath *)indexPath {
    ConversationEntity *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    
    if (!conversation.isGroup && conversation.contact != nil) {
        NSString *reason = nil;
        if ([_messagePermission canSendTo:conversation.contact.identity reason:&reason]) {
            return true;
        }
        
        [[NotificationPresenterWrapper shared] presentErrorWithErrorText:reason];
        return false;
    }
    
    return true;
}

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
    ConversationEntity *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    
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

- (void)insertSelectedConversation:(ConversationEntity *) conversation {
    [_selectedConversations addObject:conversation];
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
    ConversationEntity *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    if ([conversation isGroup]) {
        Group *group = [groupManager getGroupWithConversation:conversation];
        GroupCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GroupCell"];
        cell.group = group;
        return cell;
    } 
    else if( conversation.distributionList != nil) {
        DistributionListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DistributionListCell"];
        [cell updateDistributionList:[[DistributionList alloc] initWithDistributionListEntity:conversation.distributionList]];
        return cell;
    }
    else {
        ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
        cell._contact = conversation.contact;
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ConversationEntity *conversation = [_fetchedResultsController objectAtIndexPath:indexPath];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

@end
