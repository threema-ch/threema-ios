//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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
#import "ContactEntity.h"
#import "ProtocolDefines.h"
#import "AppDelegate.h"
#import "ServerAPIConnector.h"
#import "ErrorHandler.h"
#import "BundleUtil.h"
#import "ContactTableDataSource.h"
#import "GroupTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "DistributionListTableDataSource.h"
#import "ModalPresenter.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "ThemedTableViewController.h"
#import "ModalNavigationController.h"
#import "Threema-Swift.h"

typedef enum : NSUInteger {
    ModeContacts,
    ModeGroups,
    ModeDistributionLists,
    ModeWorkContacts
} Mode;

@interface ContactPickerViewController ()

@property Mode mode;
@property id<ContactGroupDataSource> currentDataSource;

@property (nonatomic) ContactTableDataSource *contactsDataSource;
@property (nonatomic) GroupTableDataSource *groupsDataSource;
@property (nonatomic) DistributionListTableDataSource *distributionListTableDataSource;
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
    
    UIImage *contactImage = [BundleUtil imageNamed:@"person.fill"];
    contactImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_contacts"];
    [self.segmentedControl setImage:contactImage forSegmentAtIndex:ModeContacts];

    UIImage *groupImage = [BundleUtil imageNamed:@"person.3.fill"];
    groupImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_groups"];
    [self.segmentedControl setImage:groupImage forSegmentAtIndex:ModeGroups];
   
    if ([ThreemaEnvironment distributionListsActive]) {
        [self.segmentedControl insertSegmentWithTitle:nil atIndex:ModeDistributionLists animated:NO];
        UIImage *distributionImage = [UIImage systemImageNamed:@"megaphone.fill"];
        distributionImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_distribution_list"];
        [self.segmentedControl setImage:distributionImage forSegmentAtIndex:ModeDistributionLists];
        
        if ([LicenseStore requiresLicenseKey]) {
            [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
            UIImage *workImage = [BundleUtil imageNamed:@"case.fill"];
            workImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
            [self.segmentedControl setImage:workImage forSegmentAtIndex:ModeWorkContacts];
            
        }
    }
    else {
        if ([LicenseStore requiresLicenseKey]) {
            [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
            UIImage *workImage = [BundleUtil imageNamed:@"case.fill"];
            workImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
            [self.segmentedControl setImage:workImage forSegmentAtIndex:ModeWorkContacts-1];
            
        }
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
    [self.tableView registerClass:DistributionListCell.self forCellReuseIdentifier:@"DistributionListCell"];
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
            cell.textLabel.textColor = UIColor.primary;
        } else {
            NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
            cell = [self tableView:tableView groupCellForIndexPath:convertedIndex];
        }
    }
    else if (_mode == ModeWorkContacts) {
        if ([[UserSettings sharedUserSettings] companyDirectory] == true) {
            if (indexPath.section == 0) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"CompanyDirectoryCell"];
                if (cell == nil) {
                    cell = [[CompanyDirectoryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CompanyDirectoryCell"];
                }
            } else {
                NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
                cell = [self tableView:tableView workContactCellForIndexPath:convertedIndex];
            }
        } else {
            NSIndexPath *convertedIndex = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
            cell = [self tableView:tableView workContactCellForIndexPath:convertedIndex];
        }
    }
    else if (_mode == ModeDistributionLists) {
        cell = [self tableView:tableView distributionListCellForIndexPath:indexPath];
    }
    else {
        cell = [self tableView:tableView contactCellForIndexPath:indexPath];
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView contactCellForIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    cell._contact = [self.contactsDataSource contactAtIndexPath:indexPath];;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView groupCellForIndexPath:(NSIndexPath *)indexPath {
    GroupCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupCell"];
    cell.group = [self.groupsDataSource groupAtIndexPath:indexPath];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView workContactCellForIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    cell._contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView distributionListCellForIndexPath:(NSIndexPath *)indexPath {
    DistributionListCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"DistributionListCell"];
    DistributionListEntity *distributionList = [self.distributionListTableDataSource distributionListAtIndexPath:indexPath];
    [cell updateDistributionList:distributionList];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UIViewController *presentingVC = self.presentingViewController;
    Group *group = nil;
    ContactEntity *contact = nil;
    DistributionListEntity *distributionList = nil;
    
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
    else if (_mode == ModeContacts) {
        contact = [((ContactTableDataSource *)_currentDataSource) contactAtIndexPath:indexPath];
    }
    else if (_mode == ModeDistributionLists) {
        distributionList = [((DistributionListTableDataSource *) _currentDataSource) distributionListAtIndexPath:indexPath];
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
        else if (_mode == ModeDistributionLists) {
            [self showConversationForDistributionList:distributionList];
        }
        else {
            [self showConversationForContact:contact];
        }
    }];
}

- (void)showConversationForGroup:(Group *)group {
    ConversationEntity *conversation = group.conversation;
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (void)showConversationForDistributionList:(DistributionListEntity *)distributionList {
    ConversationEntity *conversation = distributionList.conversation;
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (void)showConversationForContact:(ContactEntity *)contact {
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

- (DistributionListTableDataSource *)distributionListTableDataSource {
    if (_distributionListTableDataSource == nil) {
        _distributionListTableDataSource = [DistributionListTableDataSource distributionListDataSource];
        }
    
    return _distributionListTableDataSource;
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
   
    if (![ThreemaEnvironment distributionListsActive]) {
        if(self.segmentedControl.selectedSegmentIndex == ModeDistributionLists) {
            _mode = self.segmentedControl.selectedSegmentIndex + 1;
        }
        else {
            _mode = self.segmentedControl.selectedSegmentIndex;
        }
    } else {
        // Remove all lines above except for this when removing FF
        _mode = self.segmentedControl.selectedSegmentIndex;
    }
    
    switch (_mode) {
        case ModeContacts:
            _currentDataSource = [self contactsDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeGroups:
            _currentDataSource = [self groupsDataSource];
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            break;
            
        case ModeDistributionLists:
            _currentDataSource = [self distributionListTableDataSource];
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
