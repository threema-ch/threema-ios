//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "ContactPickerViewController.h"
#import "Contact.h"
#import "ProtocolDefines.h"
#import "AppDelegate.h"
#import "ServerAPIConnector.h"
#import "ErrorHandler.h"
#import "BundleUtil.h"
#import "ContactTableDataSource.h"
#import "GroupTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "ModalPresenter.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "ThemedTableViewController.h"
#import "ModalNavigationController.h"
#import "Threema-Swift.h"

typedef enum : NSUInteger {
    ModeContacts,
    ModeGroups,
    ModeWorkContacts
} Mode;

@interface ContactPickerViewController ()

@property Mode mode;
@property id<ContactGroupDataSource> currentDataSource;

@property (nonatomic) ContactTableDataSource *contactsDataSource;
@property (nonatomic) GroupTableDataSource *groupsDataSource;
@property (nonatomic) WorkContactTableDataSource *workContactsDataSource;

@end

@implementation ContactPickerViewController {
    NSMutableSet *groupContacts;
    BOOL groupMode;
    NSArray *filteredContacts;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        groupContacts = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _mode = ModeContacts;
    _currentDataSource = [self contactsDataSource];
    
    [self.segmentedControl setTitle:@"contacts" forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setTitle:@"groups" forSegmentAtIndex:ModeGroups];
    if ([LicenseStore requiresLicenseKey]) {
        [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
        if ([[self workContactsDataSource] numberOfSectionsInTableView:self.tableView] > 0) {
            // No regular contacts, so show Work contacts by default
            _mode = ModeWorkContacts;
            [self.segmentedControl setSelectedSegmentIndex:ModeWorkContacts];
            _currentDataSource = [self workContactsDataSource];
        }
    }
    
    for (int i = 0; i < self.segmentedControl.numberOfSegments; i++) {
        UIView *segment = self.segmentedControl.subviews[i];
        for (id subview in segment.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"contacts"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_contacts"];
                }
                else if ([label.text isEqualToString:@"groups"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_groups"];
                }
                else if ([label.text isEqualToString:@"work"]) {
                    segment.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
                }
            }
        }
    }
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeGroups];
    [self.segmentedControl setImage:[BundleUtil imageNamed:@"Contact"] forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setImage:[BundleUtil imageNamed:@"Group"] forSegmentAtIndex:ModeGroups];
    
    if ([LicenseStore requiresLicenseKey]) {
        [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeWorkContacts];
        [self.segmentedControl setImage:[BundleUtil imageNamed:@"Case"] forSegmentAtIndex:ModeWorkContacts];
    }
    
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
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    
    self.navigationItem.searchController = _searchController;
    
    [self updateColors];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    
    [self.tableView registerClass:ContactCell.self forCellReuseIdentifier:@"ContactCell"];
    [self.tableView registerClass:GroupCell.self forCellReuseIdentifier:@"GroupCell"];
}

- (void)refresh {
    [self updateColors];
    [self.tableView reloadData];
}

- (void)updateColors {
    [self.view setBackgroundColor:Colors.backgroundNavigationController];
    [self.navigationController.view setBackgroundColor:Colors.backgroundNavigationController];
    
    [Colors updateWithTableView:self.tableView];
    
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

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}


#pragma mark - Table view

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!([cell isKindOfClass:GroupCell.class] || [cell isKindOfClass:ContactCell.class] || [cell isKindOfClass:CompanyDirectoryCell.class])) {
        [Colors updateWithCell:cell setBackgroundColor:true];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_mode == ModeGroups) {
        return [self.currentDataSource numberOfSectionsInTableView:tableView] + 1;
    }
    if (_mode == ModeWorkContacts && [[UserSettings sharedUserSettings] companyDirectory] == true) {
        return [self.currentDataSource numberOfSectionsInTableView:tableView] + 1;
    }
    return [self.currentDataSource numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_mode == ModeGroups) {
        if (section == 0) {
            if (_searchController.searchBar.isFirstResponder) {
                return 0;
            }
            
            return 1;
        }
        
        return [self.currentDataSource tableView:tableView numberOfRowsInSection:section - 1];
    }
    if (_mode == ModeWorkContacts && [[UserSettings sharedUserSettings] companyDirectory] == true) {
        if (section == 0) {
            return 1;
        }
        
        return [self.currentDataSource tableView:tableView numberOfRowsInSection:section - 1];
    }
    
    return [self.currentDataSource tableView:tableView numberOfRowsInSection:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [self.currentDataSource sectionIndexTitlesForTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [self.currentDataSource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_mode == ModeGroups) {
        if (section == 1 && _searchController.searchBar.isFirstResponder == NO) {
            return [BundleUtil localizedStringForKey:@"existing groups"];
        }
        
        return nil;
    }
    if (_mode == ModeWorkContacts && [[UserSettings sharedUserSettings] companyDirectory] == true) {
        return nil;
    }
    
    return [self.currentDataSource tableView:tableView titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (_mode == ModeGroups) {
        if (indexPath.section == 0) {
            cell = [self.tableView dequeueReusableCellWithIdentifier:@"CreateGroupCell"];
            cell.textLabel.text = [BundleUtil localizedStringForKey:@"create_new_group"];
        } else {
            NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
            cell = [self tableView:tableView groupCellForIndexPath:convertedIndex];
        }
    }
    else if (_mode == ModeWorkContacts) {
        if ([[UserSettings sharedUserSettings] companyDirectory] == true) {
            if (indexPath.section == 0) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"CompanyDirectoryCell"];
                [((CompanyDirectoryCell *)cell) updateColors];
            } else {
                NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
                cell = [self tableView:tableView workContactCellForIndexPath:convertedIndex];
            }
        } else {
            NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
            cell = [self tableView:tableView workContactCellForIndexPath:convertedIndex];
        }
    }
    else {
        cell = [self tableView:tableView contactCellForIndexPath:indexPath];
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView contactCellForIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    
    Contact *contact = [self.contactsDataSource contactAtIndexPath:indexPath];
    cell._contact = contact;
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView groupCellForIndexPath:(NSIndexPath *)indexPath {
    GroupCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupCell"];
    cell.group = [self.groupsDataSource groupAtIndexPath:indexPath];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView workContactCellForIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    
    Contact *contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
    cell._contact = contact;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UIViewController *presentingVC = self.presentingViewController;
    Group *group = nil;
    Contact *contact = nil;
    
    if (_mode == ModeGroups) {
        if (indexPath.section != 0) {
            NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
            group = [((GroupTableDataSource *)_currentDataSource) groupAtIndexPath:convertedIndex];
        }
    }
    else if (_mode == ModeWorkContacts) {
        if ([[UserSettings sharedUserSettings] companyDirectory] == true) {
            if (indexPath.section != 0) {
                NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
                contact = [((WorkContactTableDataSource *)_currentDataSource) workContactAtIndexPath:convertedIndex];
            }
        } else {
            contact = [((WorkContactTableDataSource *)_currentDataSource) workContactAtIndexPath:indexPath];
        }
    }
    else {
        contact = [((ContactTableDataSource *)_currentDataSource) contactAtIndexPath:indexPath];
    }
    
    [_searchController setActive:NO];
    
    [self dismissViewControllerAnimated:YES completion:^{
        if (_mode == ModeGroups) {
            if (indexPath.section == 0) {
                MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
                if ([mdmSetup disableCreateGroup]) {
                    [UIAlertTemplate showAlertWithOwner:presentingVC title:@"" message:[BundleUtil localizedStringForKey:@"disabled_by_device_policy"] actionOk:nil];
                } else {
                    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
                    UINavigationController *navVC = [storyboard instantiateInitialViewController];
                                        
                    [presentingVC presentViewController:navVC animated:YES completion:nil];
                }
            } else {
               [self showConversationForGroup:group];
            }
        }
        else if (_mode == ModeWorkContacts && [[UserSettings sharedUserSettings] companyDirectory] == true) {
            if (indexPath.section == 0) {
                CompanyDirectoryViewController *companyDirectoryViewController = (CompanyDirectoryViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"CompanyDirectoryViewController"];
                companyDirectoryViewController.addContactActive = false;
                ModalNavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:companyDirectoryViewController];
                nav.showDoneButton = true;
                nav.showFullScreenOnIPad = false;
                
                [presentingVC presentViewController:nav animated:YES completion:nil];
                
                
                
            } else {
                [self showConversationForContact:contact];
            }
        }
        else {
            [self showConversationForContact:contact];
        }
    }];
}

- (void)showConversationForGroup:(Group *)group {
    Conversation *conversation = group.conversation;
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (void)showConversationForContact:(Contact *)contact {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          contact, kKeyContact,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (ContactTableDataSource *)contactsDataSource {
    if (_contactsDataSource == nil) {
        _contactsDataSource = [ContactTableDataSource contactTableDataSource];
    }
    
    return _contactsDataSource;
}

- (GroupTableDataSource *)groupsDataSource {
    if (_groupsDataSource == nil) {
        _groupsDataSource = [GroupTableDataSource groupTableDataSource];
    }
    
    return _groupsDataSource;
}

- (WorkContactTableDataSource *)workContactsDataSource {
    if (_workContactsDataSource == nil) {
        _workContactsDataSource = [WorkContactTableDataSource workContactTableDataSource];
    }
    
    return _workContactsDataSource;
}

#pragma mark - Search controller delegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 0.0);
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
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

- (IBAction)segmentedControlChanged:(id)sender {
    _mode = self.segmentedControl.selectedSegmentIndex;
    
    switch (_mode) {
        case ModeContacts:
            _currentDataSource = [self contactsDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeGroups:
            _currentDataSource = [self groupsDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeWorkContacts:
            _currentDataSource = [self workContactsDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        default:
            break;
    }
    
    [self.tableView reloadData];
}

@end
