//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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
#import "Old_ContactCell.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "Threema-Swift.h"

@interface PickContactsViewController ()

@property ContactAndWorkContactTableDataSource *contactsDatasource;
@property ContactAndWorkContactTableDataSource *searchDatasource;
@property NSMutableSet *selectedContacts;

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
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.definesPresentationContext = YES;
    
    self.navigationItem.searchController = _searchController;
    
    [self updateColors];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
}

- (void)updateColors {
    [self.view setBackgroundColor:Colors.backgroundView];
    
    [Colors updateWithTableView:self.tableView];
    
    self.searchController.searchBar.barTintColor = [UIColor clearColor];
    self.searchController.searchBar.backgroundColor = [UIColor clearColor];
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (navigationBar) {
        navigationBar.barTintColor = Colors.backgroundNavigationController;
    }
    
    [Colors updateWithSearchBar:_searchController.searchBar];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = [BundleUtil localizedStringForKey:@"send_profileimage_contacts"];
    
    _searchController.searchBar.placeholder = [BundleUtil localizedStringForKey:@"search"];
    
    NSArray *contactIdentities = _editProfileVC.shareWith;
    if (contactIdentities.count) {
        _selectedContacts = [NSMutableSet setWithArray:contactIdentities];
    } else {
        _selectedContacts = [NSMutableSet set];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)refresh {
    [super refresh];
    
    [self updateColors];
    [self.tableView reloadData];
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
    Old_ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Old_ContactCell"];
    
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
    [Colors updateWithCell:cell setBackgroundColor:true];
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
        _editProfileVC.shareWith = _selectedContacts.allObjects;
    }];
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
