//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#import "ThreemaFramework.h"
#import "PickGroupMembersViewController.h"
#import "ContactTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "Old_ContactCell.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "GroupPhotoSender.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

typedef enum : NSUInteger {
    ModeContact,
    ModeWorkContact
} SelectionMode;

@interface PickGroupMembersViewController ()

@property SelectionMode mode;

@property id<ContactGroupDataSource> currentDataSource;
@property NSMutableSet *selectedMembers;

@end

@implementation PickGroupMembersViewController {
    GroupManager *groupManager;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self->groupManager = [[BusinessInjector new] groupManagerObjC];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _mode = ModeContact;

    self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
    self.searchController.delegate = self;
    self.searchController.searchBar.showsScopeBar = NO;
    self.searchController.searchBar.scopeButtonTitles = nil;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.searchController.searchBar sizeToFit];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.definesPresentationContext = YES;

    self.searchController.hidesNavigationBarDuringPresentation = false;

    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = false;

    [self updateColors];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deletedContact:) name:kNotificationDeletedContact object:nil];
}

- (void)updateColors {
    [super updateColors];
    
    self.searchController.searchBar.barTintColor = [UIColor clearColor];
    self.searchController.searchBar.backgroundColor = [UIColor clearColor];
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (navigationBar) {
        navigationBar.barTintColor = Colors.backgroundNavigationController;
    }
    
    [Colors updateWithSearchBar:_searchController.searchBar];
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
    self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
}

-(void)viewWillAppear:(BOOL)animated {

    if ([LicenseStore requiresLicenseKey]) {
        self.navigationItem.titleView = self.segmentControl;
    } else {
        self.title = [BundleUtil localizedStringForKey:@"members"];
    }
    
    self.segmentControl.selectedSegmentIndex = _mode;
    [self segmentedControlChanged:nil];
    
    _searchController.searchBar.placeholder = [BundleUtil localizedStringForKey:@"search"];
    
    if (_selectedMembers == nil) {
        _selectedMembers = [NSMutableSet set];
    }
    
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 0.0);

    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_delegate group:_group updatedMembers:_selectedMembers];
}

- (void)deletedContact:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
        [self.tableView reloadData];
    });
}

- (void)setGroup:(Group *)group {
    _group = group;

    // Get ContactEntity for each Contact for selected members
    _selectedMembers = [NSMutableSet<ContactEntity *> set];
    if (_group.members) {
        EntityManager *em = [EntityManager new];
        [em performBlockAndWait:^{
            for (Contact *contact in _group.members) {
                ContactEntity *member = [em.entityFetcher contactForId:contact.identity];
                if (member) {
                    [_selectedMembers addObject:member];
                }
            }
        }];
    }
}

- (void)setMembers:(NSSet *)set {
    _selectedMembers = [NSMutableSet setWithSet: set];
}

- (NSSet *)getMembers {
    return [NSSet setWithSet:_selectedMembers];
}

- (void)refresh {
    [self updateColors];
    
    [super refresh];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_currentDataSource numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_currentDataSource tableView:tableView numberOfRowsInSection:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [_currentDataSource sectionIndexTitlesForTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [_currentDataSource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_currentDataSource tableView:tableView titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Old_ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Old_GroupContactCell"];
    
    ContactEntity *contact;
    if (_mode == ModeWorkContact) {
        contact = [((WorkContactTableDataSource *) _currentDataSource) workContactAtIndexPath:indexPath];
    } else {
        contact = [((ContactTableDataSource *) _currentDataSource) contactAtIndexPath:indexPath];
    }
    
    cell.contact = contact;
    
    if ([_selectedMembers containsObject:cell.contact]) {
        cell.checkmarkView.image = [StyleKit check];
        cell.accessibilityTraits = UIAccessibilityTraitSelected;
    } else {
        cell.checkmarkView.image = [StyleKit uncheck];
        cell.accessibilityTraits = 0;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactEntity *contact;
    
    if (_mode == ModeWorkContact) {
        contact = [((WorkContactTableDataSource *) _currentDataSource) workContactAtIndexPath:indexPath];
    } else {
        contact = [((ContactTableDataSource *) _currentDataSource) contactAtIndexPath:indexPath];
    }
    
    if ([_selectedMembers containsObject:contact]) {
        [_selectedMembers removeObject:contact];
    } else {
        int maxGroupMembers = [[BundleUtil objectForInfoDictionaryKey:@"ThreemaMaxGroupMembers"] intValue];
        if (_selectedMembers.count < maxGroupMembers) {
            [_selectedMembers addObject:contact];
        } else {
            [UIAlertTemplate showAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"too_many_members_title"] message:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"too_many_members_message"], maxGroupMembers] actionOk:nil];
        }
    }
    
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Search controller delegate

- (void)willPresentSearchController:(UISearchController *)searchController {
}

- (void)willDismissSearchController:(UISearchController *)searchController {
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
    [self.tableView reloadData];
}

- (NSArray *)searchWordsForText:(NSString *)text {
    NSArray *searchWords = nil;
    if (text && [text length] > 0) {
        searchWords = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    
    return searchWords;
}


#pragma mark - Actions

- (IBAction)saveAction:(id)sender {
    self.navigationItem.leftBarButtonItem.enabled = false;
    self.navigationItem.rightBarButtonItem.enabled = false;
    [_searchController setActive:false];
    
    // Update group members
    NSMutableSet *groupMemberIdentities = [[NSMutableSet alloc] init];
    for (ContactEntity *contact in _selectedMembers) {
        if (contact.willBeDeleted) {
            continue;
        }

        [groupMemberIdentities  addObject:contact.identity];
    }
    
    // This is an insane hack to inject a custom completion handler. Used with distribution lists.
    if (_didSelect != nil) {
        self.didSelect(_selectedMembers);
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self dismissViewControllerAnimated:YES completion:^{
        [groupManager createOrUpdateObjcWithGroupID:_group.groupID creator:[[MyIdentityStore sharedMyIdentityStore] identity] members:groupMemberIdentities systemMessageDate:[NSDate date] completionHandler:^(Group * _Nullable grp, NSSet<NSString *> * _Nullable newMembers, NSError * _Nullable error) {

            if (error) {
                DDLogError(@"Could not update group members: %@", error.localizedDescription);
                return;
            }

            // Sync only new members
            // This is logic that should move to the GroupManager in the future
            if (grp != nil && newMembers != nil) {
                [groupManager syncObjcWithGroup:grp to:newMembers withoutCreateMessage:YES completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        DDLogError(@"Error syncing group: %@", error.localizedDescription);
                    }
                }];
            }
        }];
    }];
}

- (IBAction)cancelAction:(id)sender {
    self.navigationItem.leftBarButtonItem.enabled = false;
    self.navigationItem.rightBarButtonItem.enabled = false;
    [_searchController setActive:false];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)segmentedControlChanged:(id)sender {
    _mode = self.segmentControl.selectedSegmentIndex;
    switch (_mode) {
        case ModeContact:
            _currentDataSource = [ContactTableDataSource contactTableDataSourceWithMembers:_selectedMembers];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeWorkContact:
            _currentDataSource = [WorkContactTableDataSource workContactTableDataSourceWithMembers:_selectedMembers];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        default:
            break;
    }
        
    [self.tableView reloadData];
}

@end
