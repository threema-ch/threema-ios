//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

#import "DistributionListTableDataSource.h"
#import <CoreData/CoreData.h>
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface DistributionListTableDataSource () <NSFetchedResultsControllerDelegate>

@property NSArray *filteredDistributionLists;

@property NSFetchedResultsController *fetchedResultsController;
@property (nonatomic)  NSMutableSet *selectedDistributionLists;

@property id<NSFetchedResultsControllerDelegate> fetchedResultsControllerDelegate;
@property EntityManager *entityManager;

@property BOOL ignoreUpdates;

@end


@implementation DistributionListTableDataSource

+ (instancetype)distributionListDataSource {
    return [[DistributionListTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:nil];
}

+ (instancetype)contactTableDataSourceWithMembers:(NSMutableSet *)members {
    return [[DistributionListTableDataSource alloc] initWithFetchedResultsControllerDelegate:nil members:members];
}

+ (instancetype)distributionListTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members {
    return [[DistributionListTableDataSource alloc] initWithFetchedResultsControllerDelegate:delegate members:members];
}

- (void)dealloc {
    _fetchedResultsController.delegate = nil;
}

- (instancetype)initWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members {
    self = [super init];
    if (self) {
        
        _entityManager = [[EntityManager alloc] init];
        
        if (members != nil) {
            _selectedDistributionLists = members;
        } else {
            _selectedDistributionLists = [NSMutableSet set];
        }
        
        if (delegate) {
            _fetchedResultsControllerDelegate = delegate;
            delegate = self;
        }
        
         [self setupFetchedResultsControllerWithDelegate:delegate];
    }
    
    return self;
}

- (void)setupFetchedResultsControllerWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate {
    
    NSFetchedResultsController *fetchedResultsController = [_entityManager.entityFetcher fetchedResultsControllerForDistributionLists];
    fetchedResultsController.delegate = delegate;
    _fetchedResultsController = fetchedResultsController;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [ErrorHandler abortWithError: error];
    }
}


- (DistributionListEntity *)distributionListAtIndexPath:(NSIndexPath *)indexPath {
    if (_filteredDistributionLists) {
        return [_filteredDistributionLists objectAtIndex:indexPath.row];
    } else {
        return [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
}

- (NSIndexPath *)indexPathForObject:(id)object {
    return [_fetchedResultsController indexPathForObject:object];
}

- (NSSet *)getSelectedDistributionLists{
    return [NSSet setWithSet:_selectedDistributionLists];
}

- (void)updateSelectedDistributionLists:(NSSet *)distributionLists {
    _selectedDistributionLists = [NSMutableSet setWithSet:distributionLists];
}

- (NSUInteger)countOfDistributionLists {
    return _fetchedResultsController.fetchedObjects.count;
}

-(void)filterByWords:(NSArray *)words {
    if (words) {
        _filteredDistributionLists = [_entityManager.entityFetcher distributionListsFilteredByWords:words];
    } else {
        _filteredDistributionLists= nil;
    }
}

- (NSSet *)selectedConversations {
    NSMutableSet *distributionLists = [NSMutableSet setWithCapacity:[_selectedDistributionLists count]];
    for (DistributionListEntity *dist in _selectedDistributionLists) {
        [distributionLists addObject:dist.conversation];
    }
    return distributionLists;
}

- (void)setIgnoreFRCUpdates:(BOOL)ignoreFRCUpdates {
    _ignoreUpdates = ignoreFRCUpdates;
}

- (BOOL)ignoreFRCUpdates {
    return _ignoreUpdates;
}

- (BOOL)isFiltered {
    return (_filteredDistributionLists != nil);
}


#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_filteredDistributionLists) {
        return 1;
    }
    
    NSInteger count = [[self.fetchedResultsController sections] count];
    
    return  count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_filteredDistributionLists) {
        return _filteredDistributionLists.count;
    }
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}


- (NSString *)tableView:(UITableView *)tableView sectionIndexTitlesForTableView:(NSInteger)section {
    return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return nil;
}

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected {
    DistributionListEntity *distributionList = [self distributionListAtIndexPath:indexPath];
    
    if (selected && distributionList) {
        if (![_selectedDistributionLists containsObject:distributionList]) {
            [_selectedDistributionLists addObject:distributionList];
        }
    } else {
        [_selectedDistributionLists enumerateObjectsUsingBlock:^(DistributionListEntity *tmpDistributionList, BOOL * _Nonnull stop) {
            if ([distributionList.distributionListId isEqualToNumber:tmpDistributionList.distributionListId]) {
                [_selectedDistributionLists removeObject:tmpDistributionList];
                *stop = YES;
            }
        }];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DistributionListEntity *dl = [self distributionListAtIndexPath:indexPath];
    
    DistributionListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DistributionListCell"];
    cell.distributionList = dl;
    
    return cell;
}

#pragma mark - Fetched results controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (_ignoreUpdates || _filteredDistributionLists != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerWillChangeContent:controller];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (_ignoreUpdates || _filteredDistributionLists != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controller:controller didChangeSection:sectionInfo atIndex:sectionIndex forChangeType:type];
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (_ignoreUpdates || _filteredDistributionLists != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controller:controller didChangeObject:anObject atIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
    
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (_ignoreUpdates || _filteredDistributionLists != nil) {
        return;
    }
    
    [_fetchedResultsControllerDelegate controllerDidChangeContent:controller];
}

@end
