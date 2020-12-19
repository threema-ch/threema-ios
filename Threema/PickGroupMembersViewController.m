//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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
#import "ContactCell.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "LicenseStore.h"

typedef enum : NSUInteger {
    ModeContact,
    ModeWorkContact
} SelectionMode;

@interface PickGroupMembersViewController ()

@property SelectionMode mode;

@property id<ContactGroupDataSource> currentDataSource;
@property NSMutableSet *selectedMembers;

@end

@implementation PickGroupMembersViewController

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
    self.searchController.searchBar.barStyle = UISearchBarStyleMinimal;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.definesPresentationContext = YES;
    
    if (@available(iOS 13.0, *)) {
        // iOS 13 and 13.1 have a bug. When searchbar is active, the navigationitem is not available
        // Bug should be fixed in 13.2
        self.searchController.hidesNavigationBarDuringPresentation = true;
        self.navigationController.view.backgroundColor = [Colors backgroundBaseColor];
        [self setModalInPresentation:true];
    } else {
        self.searchController.hidesNavigationBarDuringPresentation = false;
    }
        
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = _searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = false;
    } else {
        self.definesPresentationContext = NO;
        [self.view addSubview:self.searchController.searchBar];
    }
    
    [self setupColors];
}

- (void)setupColors {
    [Colors updateTableView:self.tableView];
    if (@available(iOS 11.0, *)) {
        self.searchController.searchBar.barTintColor = [UIColor clearColor];
        self.searchController.searchBar.backgroundColor = [UIColor clearColor];
        
        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        if (navigationBar) {
            navigationBar.barTintColor = [Colors backgroundBaseColor];
        }
    } else {
        self.searchController.searchBar.backgroundColor = [Colors backgroundBaseColor];
        
        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        if (navigationBar) {
            navigationBar.barTintColor = [Colors backgroundBaseColor];
        }
    }
    
    [Colors updateSearchBar:_searchController.searchBar];
    if (@available(iOS 11.0, *)) {
        self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
        self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
    } else {
    }
}

-(void)viewWillAppear:(BOOL)animated {

    if ([LicenseStore requiresLicenseKey]) {
        self.navigationItem.titleView = self.segmentControl;
    } else {
        self.title = NSLocalizedString(@"members", nil);
    }
    
    if ([LicenseStore requiresLicenseKey] && [[WorkContactTableDataSource workContactTableDataSource] numberOfSectionsInTableView:self.tableView] > 0) {
        _mode = ModeWorkContact;
    }
    
    self.segmentControl.selectedSegmentIndex = _mode;
    [self segmentedControlChanged:nil];
    
    _searchController.searchBar.placeholder = NSLocalizedString(@"search", nil);
    
    if (_selectedMembers == nil) {
        _selectedMembers = [NSMutableSet set];
    }
    
    if (@available(iOS 11.0, *)) {
        self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 0.0);
    } else {
        self.tableView.contentInset = UIEdgeInsetsMake(_searchController.searchBar.frame.size.height, 0, 0, 0);
    }
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_delegate group:_group updatedMembers:_selectedMembers];
}

- (void)setGroup:(GroupProxy *)group {
    _group = group;
    
    _selectedMembers = [NSMutableSet setWithSet: _group.members];
}

- (void)setMembers:(NSSet *)set {
    _selectedMembers = [NSMutableSet setWithSet: set];
}

- (NSSet *)getMembers {
    return [NSSet setWithSet:_selectedMembers];
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
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupContactCell"];
    
    Contact *contact;
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [Colors updateTableViewCell:cell];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Contact *contact;
    
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
            [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"too_many_members_title", nil) message:[NSString stringWithFormat:NSLocalizedString(@"too_many_members_message", nil), maxGroupMembers] actionOk:nil];
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
    NSSet *newMembers = _selectedMembers;
    NSSet *existingMembers = [NSSet setWithSet:_group.members];
    
    [self dismissViewControllerAnimated:YES completion:^{
        for (Contact *member in existingMembers) {
            if ([newMembers containsObject:member] == NO) {
                [_group adminRemoveMember:member];
            }
        }
        
        for (Contact *member in newMembers) {
            if ([_group.members containsObject:member] == NO) {
                [_group adminAddMember:member];
            }
        }
    }];
}

- (IBAction)cancelAction:(id)sender {
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
