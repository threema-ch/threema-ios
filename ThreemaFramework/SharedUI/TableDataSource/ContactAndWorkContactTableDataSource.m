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

#import "ContactAndWorkContactTableDataSource.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ErrorHandler.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface ContactAndWorkContactTableDataSource () <NSFetchedResultsControllerDelegate>

@property NSArray *filteredContacts;
@property NSFetchedResultsController *fetchedResultsController;
@property NSFetchedResultsController *gatewayFetchedResultsController;

@property (nonatomic)  NSMutableSet *selectedContacts;

@property EntityManager *entityManager;
@property id<NSFetchedResultsControllerDelegate> fetchedResultsControllerDelegate;

@property BOOL ignoreUpdates;

@end

@implementation ContactAndWorkContactTableDataSource

+ (instancetype)contactAndWorkContactTableDataSource {
    return [[ContactAndWorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:nil];
}

+ (instancetype)contactAndWorkContactTableDataSourceWithMembers:(NSMutableSet *)members {
    return [[ContactAndWorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:members];
}

+ (instancetype)contactAndWorkContactTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members {
    return [[ContactAndWorkContactTableDataSource alloc] initWithFetchedResultsControllerDelegate:delegate members:members];
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
            _selectedContacts = members;
        } else {
            _selectedContacts = [NSMutableSet set];
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
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoGatewayNoEchoecho list:ContactListContactsAndWork members:_selectedContacts];
        fetchedResultsController.delegate = _fetchedResultsController.delegate;
        _fetchedResultsController = fetchedResultsController;
        
        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
            [ErrorHandler abortWithError: error];
        }
    } else if (_excludeEchoEcho) {
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoEchoEcho list:ContactListContactsAndWork members:_selectedContacts];
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
        NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsGatewayOnly list:ContactListContactsAndWork members:nil];
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
    
    NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForContactTypes:ContactsNoGateway list:ContactListContacts members:_selectedContacts];
    fetchedResultsController.delegate = delegate;
    _fetchedResultsController = fetchedResultsController;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
    }
}

- (ContactEntity *)contactAtIndexPath:(NSIndexPath *)indexPath {
    if (_filteredContacts) {
        return [_filteredContacts objectAtIndex:indexPath.row];
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

- (NSSet *)getSelectedContacts {
    return [NSSet setWithSet:_selectedContacts];
}

- (void)updateSelectedContacts:(NSSet *)contacts {
    _selectedContacts = [NSMutableSet setWithSet:contacts];
}

- (void)refreshContactSortIndices {
    for (ContactEntity *contact in _fetchedResultsController.fetchedObjects) {
        [contact updateSortInitial];
    }
    for (ContactEntity *contact in _gatewayFetchedResultsController.fetchedObjects) {
        [contact updateSortInitial];
    }
}

- (NSUInteger)countOfContacts {
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
            
        _filteredContacts = [_entityManager.entityFetcher contactsFilteredByWords:words forContactTypes:type list:ContactListContactsAndWork members:_selectedContacts];
    } else {
        _filteredContacts = nil;
    }
}

- (NSSet *)selectedConversations {
    NSMutableSet *conversations = [NSMutableSet setWithCapacity:[_selectedContacts count]];
    for (ContactEntity *contact in _selectedContacts) {
        __block ConversationEntity *conversation = [_entityManager.entityFetcher conversationEntityForContact:contact];
        if (conversation == nil) {
            // create & immediately save
            [_entityManager performSyncBlockAndSafe:^{
                conversation = [_entityManager.entityCreator conversationEntity: YES];
                conversation.contact = contact;
            }];
        }
        [conversations addObject:conversation];
    }
    return conversations;
}

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
    ContactEntity *contact = [self contactAtIndexPath:indexPath];
    
    if (selected) {
        if (![_selectedContacts containsObject:contact]) {
            [_selectedContacts addObject:contact];
        }
    } else {
        if ([_selectedContacts containsObject:contact]) {
            [_selectedContacts removeObject:contact];
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
    return (_filteredContacts != nil);
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_filteredContacts) {
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
    if (_filteredContacts) {
        return _filteredContacts.count;
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
    if (_filteredContacts) {
        return nil;
    }
    
    NSMutableArray *sectionTitles = [NSMutableArray arrayWithArray:[[UILocalizedIndexedCollation currentCollation] sectionIndexTitles]];
    [sectionTitles addObject:@"*"];
    
    return sectionTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (_filteredContacts) {
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
    
    if (_filteredContacts) {
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
    ContactEntity *contact = [self contactAtIndexPath:indexPath];
    
    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    cell._contact = contact;
    
    return cell;
}


#pragma mark - Fetched results controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (_ignoreUpdates || _filteredContacts != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerWillChangeContent:controller];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (_ignoreUpdates || _filteredContacts != nil) {
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
    if (_ignoreUpdates || _filteredContacts != nil) {
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
    if (_ignoreUpdates || _filteredContacts != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerDidChangeContent:controller];
}

@end
