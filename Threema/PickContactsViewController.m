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
#import "PickContactsViewController.h"
#import "ContactAndWorkContactTableDataSource.h"
#import "ContactCell.h"
#import "BundleUtil.h"
#import "UserSettings.h"

@interface PickContactsViewController ()

@property ContactAndWorkContactTableDataSource *contactsDatasource;
@property ContactAndWorkContactTableDataSource *searchDatasource;
@property NSMutableSet *selectedContacts;
@property (strong, nonatomic) UIView *statusBarView;

@end

@implementation PickContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _contactsDatasource = [ContactAndWorkContactTableDataSource contactAndWorkContactTableDataSource];
    _contactsDatasource.excludeGatewayContacts = YES;
    _contactsDatasource.excludeEchoEcho = YES;
    _searchDatasource = [ContactAndWorkContactTableDataSource contactAndWorkContactTableDataSource];
    _searchDatasource.excludeGatewayContacts = YES;
    _searchDatasource.excludeEchoEcho = YES;
    
    self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
    self.searchController.delegate = self;
    self.searchController.searchBar.showsScopeBar = NO;
    self.searchController.searchBar.scopeButtonTitles = nil;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchResultsUpdater = self;
    
    self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.searchController.searchBar sizeToFit];
    self.searchController.searchBar.barStyle = UISearchBarStyleMinimal;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.definesPresentationContext = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = _searchController;
    } else {
        [self.view addSubview:self.searchController.searchBar];
        self.statusBarView = [[UIView alloc] initWithFrame:[[UIApplication sharedApplication] statusBarFrame]];
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    
    [self setupColors];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    if (@available(iOS 11.0, *)) {
        self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    } else {
        self.tableView.estimatedRowHeight = 44.0;
    }
}

- (void)setupColors {
    [self.view setBackgroundColor:[Colors backgroundLight]];
    
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
    } else {
        [_statusBarView setBackgroundColor:[Colors searchBarStatusBar]];
    }
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = NSLocalizedString(@"send_profileimage_contacts", nil);
    
    _searchController.searchBar.placeholder = NSLocalizedString(@"search", nil);
    
    NSArray *contactIdentities = [UserSettings sharedUserSettings].profilePictureContactList;
    if (contactIdentities.count) {
        _selectedContacts = [NSMutableSet setWithArray:contactIdentities];
    } else {
        _selectedContacts = [NSMutableSet set];
    }
    
    if (@available(iOS 11.0, *)) {
    } else {
        self.tableView.contentInset = UIEdgeInsetsMake(44.0, 0.0, 0.0, 0.0);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_searchController.isActive) {
        return [_searchDatasource numberOfSectionsInTableView:tableView];
    }
    return [_contactsDatasource numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_searchController.isActive) {
        return [_searchDatasource tableView:tableView numberOfRowsInSection:section];
    }
    return [_contactsDatasource tableView:tableView numberOfRowsInSection:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (_searchController.isActive) {
        return [_searchDatasource sectionIndexTitlesForTableView:tableView];
    }
    return [_contactsDatasource sectionIndexTitlesForTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (_searchController.isActive) {
        return [_searchDatasource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
    }
    return [_contactsDatasource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_searchController.isActive) {
        return [_searchDatasource tableView:tableView titleForHeaderInSection:section];
    }
    return [_contactsDatasource tableView:tableView titleForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    
    Contact *contact;
    if (_searchController.isActive) {
        contact = [_searchDatasource contactAtIndexPath:indexPath];
    } else {
        contact = [_contactsDatasource contactAtIndexPath:indexPath];
    }
    
    cell.contact = contact;
    
    if ([_selectedContacts containsObject:cell.contact.identity]) {
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
    if (_searchController.isActive) {
        contact = [_searchDatasource contactAtIndexPath:indexPath];
    } else {
        contact = [_contactsDatasource contactAtIndexPath:indexPath];
    }
    
    if ([_selectedContacts containsObject:contact.identity]) {
        [_selectedContacts removeObject:contact.identity];
    } else {
        [_selectedContacts addObject:contact.identity];
    }
    
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Search controller delegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    if (@available(iOS 11.0, *)) {
    } else {
        self.tableView.contentInset = UIEdgeInsetsMake(64.0, 0.0, 0.0, 0.0);
        [self.view addSubview:_statusBarView];
    }
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    if (@available(iOS 11.0, *)) {
    } else {
        self.tableView.contentInset = UIEdgeInsetsMake(44.0, 0.0, 0.0, 0.0);
        [_statusBarView removeFromSuperview];
    }
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSArray *searchWords = [self searchWordsForText:searchController.searchBar.text];
    [_searchDatasource filterByWords: searchWords];
    
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

    [self dismissViewControllerAnimated:YES completion:^{
        [[UserSettings sharedUserSettings] setProfilePictureContactList:_selectedContacts.allObjects];
    }];
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
