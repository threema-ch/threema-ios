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

#import "WorkContactTableDataSource.h"
#import <CoreData/CoreData.h>
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ErrorHandler.h"
#import "Old_PickerContactCell.h"
#import "UserSettings.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface WorkContactTableDataSource () <NSFetchedResultsControllerDelegate>

@property NSArray *filteredWorkContacts;
@property NSFetchedResultsController *fetchedResultsController;
@property NSFetchedResultsController *gatewayFetchedResultsController;

@property (nonatomic)  NSMutableSet *selectedWorkContacts;

@property EntityManager *entityManager;
@property id<NSFetchedResultsControllerDelegate> fetchedResultsControllerDelegate;

@property BOOL ignoreUpdates;

@end

@implementation WorkContactTableDataSource

+ (instancetype)workContactTableDataSource {
    return [[WorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:nil];
}

+ (instancetype)workContactTableDataSourceWithMembers:(NSMutableSet *)members {
    return [[WorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:members];
}

+ (instancetype)workContactTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members {
    return [[WorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:delegate members:members];
}

- (void)dealloc {
    _fetchedResultsController.delegate = nil;
    _gatewayFetchedResultsController.delegate = nil;
}

- (instancetype)initWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members {
    self = [super init];
    if (self) {
        _entityManager = [[EntityManager alloc] init];
        if (members != nil) {
            _selectedWorkContacts = members;
        } else {
            _selectedWorkContacts = [NSMutableSet set];
        }
        
        if (delegate) {
            _fetchedResultsControllerDelegate = delegate;
            delegate = self;
        }
        
        [self setupFetchedResultsControllerWithDelegate:delegate];
        
        // include gateway contacts by default
        [self loadGatewayContacts];
    }
    
    return self;
}

- (void)setExcludeGatewayContacts:(BOOL)excludeGatewayContacts {
    _excludeGatewayContacts = excludeGatewayContacts;
    
    [self loadGatewayContacts];
}

- (void)setExcludeEchoEcho:(BOOL)excludeEchoEcho {
    _excludeEchoEcho = excludeEchoEcho;
    
    if (_excludeEchoEcho && _excludeGatewayContacts) {
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoGatewayNoEchoecho list:ContactListWork members:_selectedWorkContacts];
        fetchedResultsController.delegate = _fetchedResultsController.delegate;
        _fetchedResultsController = fetchedResultsController;
        
        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
            [ErrorHandler abortWithError: error];
        }
    } else if (_excludeEchoEcho) {
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoEchoEcho list:ContactListWork members:_selectedWorkContacts];
        fetchedResultsController.delegate = _fetchedResultsController.delegate;
        _fetchedResultsController = fetchedResultsController;
        
        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
            [ErrorHandler abortWithError: error];
        }
    }
}

- (void)loadGatewayContacts {
    if (_excludeGatewayContacts == NO) {
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsGatewayOnly list:ContactListWork members:nil];
        fetchedResultsController.delegate = self;
        _gatewayFetchedResultsController = fetchedResultsController;
        
        NSError *error = nil;
        if (![_gatewayFetchedResultsController performFetch:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
            [ErrorHandler abortWithError: error];
        }
    } else {
        _gatewayFetchedResultsController.delegate = nil;
        _gatewayFetchedResultsController = nil;
    }
}

- (void)setupFetchedResultsControllerWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate {
    
    NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoGateway list:ContactListWork members:_selectedWorkContacts];
    fetchedResultsController.delegate = delegate;
    _fetchedResultsController = fetchedResultsController;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
    }
}

- (ContactEntity *)workContactAtIndexPath:(NSIndexPath *)indexPath {
    if (_filteredWorkContacts) {
        return [_filteredWorkContacts objectAtIndex:indexPath.row];
    }
    
    if (indexPath.section == self.fetchedResultsController.sections.count) {
        NSIndexPath *gatewayIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
        return [_gatewayFetchedResultsController objectAtIndexPath:gatewayIndexPath];
    }
    
    return [self.fetchedResultsController objectAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForObject:(id)object {
    return [_fetchedResultsController indexPathForObject:object];
}

- (NSSet *)getSelectedWorkContacts {
    return [NSSet setWithSet:_selectedWorkContacts];
}

- (void)updateSelectedWorkContacts:(NSSet *)contacts {
    _selectedWorkContacts = [NSMutableSet setWithSet:contacts];
}

- (void)refreshWorkContactSortIndices {
    for (ContactEntity *contact in _fetchedResultsController.fetchedObjects) {
        [contact updateSortInitial];
    }
    for (ContactEntity *contact in _gatewayFetchedResultsController.fetchedObjects) {
        [contact updateSortInitial];
    }
}

- (NSUInteger)countOfWorkContacts {
    if (_excludeGatewayContacts) {
        return _fetchedResultsController.fetchedObjects.count;
    }
    return _fetchedResultsController.fetchedObjects.count + _gatewayFetchedResultsController.fetchedObjects.count;
}

#pragma mark - ContactGroupDataSource

-(void)filterByWords:(NSArray *)words {
    if (words) {
        ContactTypes type = ContactsAll;
        if (_excludeEchoEcho && _excludeGatewayContacts) {
            type = ContactsNoGatewayNoEchoecho;
        }
        else if (_excludeGatewayContacts) {
            type = ContactsNoGateway;
        }
        else if (_excludeEchoEcho) {
            type = ContactsNoEchoEcho;
        }
        
        _filteredWorkContacts = [_entityManager.entityFetcher contactsFilteredByWords:words forContactTypes:type list:ContactListWork members:_selectedWorkContacts];
    } else {
        _filteredWorkContacts = nil;
    }
}

- (NSSet *)selectedConversations {
    NSMutableSet *conversations = [NSMutableSet setWithCapacity:[_selectedWorkContacts count]];
    for (ContactEntity *contact in _selectedWorkContacts) {
        __block Conversation *conversation = [_entityManager.entityFetcher conversationForContact:contact];
        if (conversation == nil) {
            // create & immediately save
            [_entityManager performSyncBlockAndSafe:^{
                conversation = [_entityManager.entityCreator conversation];
                conversation.contact = contact;
            }];
        }
        [conversations addObject:conversation];
    }
    return conversations;
}

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
    ContactEntity *contact = [self workContactAtIndexPath:indexPath];
    
    if (selected) {
        if (![_selectedWorkContacts containsObject:contact]) {
            [_selectedWorkContacts addObject:contact];
        }
    } else {
        if ([_selectedWorkContacts containsObject:contact]) {
            [_selectedWorkContacts removeObject:contact];
        }
    }
}

- (void)setIgnoreFRCUpdates:(BOOL)ignoreFRCUpdates {
    _ignoreUpdates = ignoreFRCUpdates;
}

- (BOOL)ignoreFRCUpdates {
    return _ignoreUpdates;
}

- (BOOL)isFiltered {
    return (_filteredWorkContacts != nil);
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_filteredWorkContacts) {
        return 1;
    }
    
    NSInteger count = [[self.fetchedResultsController sections] count];
    
    if (_gatewayFetchedResultsController.sections.count > 0) {
        count++;
    }
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_filteredWorkContacts) {
        return _filteredWorkContacts.count;
    }
    
    NSArray *frcSections = [self.fetchedResultsController sections];
    if (section >= frcSections.count) {
        NSArray *gatewaySections = [_gatewayFetchedResultsController sections];
        if (gatewaySections.count > 0) {
            id <NSFetchedResultsSectionInfo> sectionInfo = gatewaySections[0];
            return [sectionInfo numberOfObjects];
        } else {
            return 0;
        }
    }
    
    id <NSFetchedResultsSectionInfo> sectionInfo = frcSections[section];
    return [sectionInfo numberOfObjects];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (_filteredWorkContacts) {
        return nil;
    }
    
    NSMutableArray *sectionTitles = [NSMutableArray arrayWithArray:[[UILocalizedIndexedCollation currentCollation] sectionIndexTitles]];
    [sectionTitles addObject:@"*"];
    
    return sectionTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (_filteredWorkContacts) {
        return 0;
    }
    
    if ([title isEqualToString:@"*"]) {
        return self.fetchedResultsController.sections.count;
    }
    
    int frcIndex = 0;
    for (id<NSFetchedResultsSectionInfo> section in self.fetchedResultsController.sections) {
        if ([section.name intValue] <= index) {
            frcIndex++;
        } else {
            break;
        }
    }
    
    frcIndex--;
    if (frcIndex < 0) {
        frcIndex = 0;
    }
    
    return frcIndex;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (_filteredWorkContacts) {
        return nil;
    }
    
    if (section == self.fetchedResultsController.sections.count) {
        return @"*";
    }
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    /* the section "name" of the FRC is actually an index into the UILocalizedIndexedCollation sectionIndexTitles */
    int sitIdx = [[sectionInfo name] intValue];
    NSArray *sectionIndexTitles = [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    if (sitIdx >= 0 && sitIdx < [sectionIndexTitles count]) {
        return [sectionIndexTitles objectAtIndex:sitIdx];
    } else {
        return @" ";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactEntity *contact = [self workContactAtIndexPath:indexPath];
    
    Old_PickerContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Old_PickerContactCell"];
    cell.contact = contact;
    
    return cell;
}

#pragma mark - Fetched results controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (_ignoreUpdates || _filteredWorkContacts != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerWillChangeContent:controller];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (_ignoreUpdates || _filteredWorkContacts != nil) {
        return;
    }
    
    if (controller == _fetchedResultsController) {
        [_fetchedResultsControllerDelegate controller:controller didChangeSection:sectionInfo atIndex:sectionIndex forChangeType:type];
    } else {
        ;//ignore
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (_ignoreUpdates || _filteredWorkContacts != nil) {
        return;
    }
    
    if (controller == _fetchedResultsController) {
        [_fetchedResultsControllerDelegate controller:controller didChangeObject:anObject atIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
    } else {
        ;//ignore
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (_ignoreUpdates || _filteredWorkContacts != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerDidChangeContent:controller];
}

@end

