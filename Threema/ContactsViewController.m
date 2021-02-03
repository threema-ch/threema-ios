//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "ContactsViewController.h"
#import "ContactCell.h"
#import "GroupCell.h"
#import "Contact.h"
#import "ContactStore.h"
#import "UserSettings.h"
#import "DatabaseManager.h"
#import "EntityManager.h"
#import "GatewayAvatarMaker.h"
#import "ContactTableDataSource.h"
#import "GroupTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "GroupDetailsViewController.h"
#import "ContactDetailsViewController.h"
#import "DeleteConversationAction.h"
#import "DeleteContactAction.h"
#import "ModalPresenter.h"
#import "RectUtil.h"
#import "WorkDataFetcher.h"
#import "LicenseStore.h"
#import "BundleUtil.h"
#import "ModalNavigationController.h"
#import "AvatarMaker.h"
#import "MDMSetup.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

typedef enum : NSUInteger {
    ModeContacts,
    ModeGroups,
    ModeWorkContacts
} Mode;

@interface ContactsViewController () <UIViewControllerPreviewingDelegate, GroupDetailsViewControllerDelegate, ContactDetailsViewControllerDelegate, UINavigationControllerDelegate>

@property Mode mode;

@property (nonatomic) id<ContactGroupDataSource> currentDataSource;

@property EntityManager *entityManager;
@property (nonatomic) ContactTableDataSource *contactsDataSource;
@property (nonatomic) GroupTableDataSource *groupsDataSource;
@property (nonatomic) WorkContactTableDataSource *workContactsDataSource;

@property id<UINavigationControllerDelegate> prevNavigationControllerDelegate;
@property (copy) GroupDetailsCompletionBlock groupCompletionBlock;
@property (copy) void (^contactCompletionBlock)(ContactDetailsViewController *contactDetailsViewController);


@property (strong, nonatomic) UIView *statusBarView;

@property NSIndexPath *deletionIndexPath;
@property id deleteAction;

@property (nonatomic) BOOL isMultipleEditing;

@property (nonatomic, strong) UIRefreshControl *rfControl;

@end

@implementation ContactsViewController {
    Contact *contactForDetails;
    GroupProxy *groupForDetails;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        /* listen for blacklist change (to refresh contact labels with blocked icon) */
        [[UserSettings sharedUserSettings] addObserver:self forKeyPath:@"blacklist" options:0 context:nil];

        /* listen for stale contacts setting */
        [[UserSettings sharedUserSettings] addObserver:self forKeyPath:@"hideStaleContacts" options:0 context:nil];
        
        _entityManager = [[EntityManager alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _currentDataSource = [self currentDataSource];
    
    // iOS 10 and 12 have different subviews sorting, so we have to check it with name and replace it at the end with the image
    
    UIImage *contactImage = [BundleUtil imageNamed:@"Contact"];
    contactImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_contacts"];
    UIImage *groupImage = [BundleUtil imageNamed:@"Group"];
    groupImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_groups"];
    UIImage *workImage = [BundleUtil imageNamed:@"Case"];
    workImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
    
    [self.segmentedControl setTitle:@"contacts" forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setTitle:@"groups" forSegmentAtIndex:ModeGroups];
    if ([LicenseStore requiresLicenseKey]) {
        [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
        if ([[self workContactsDataSource] numberOfSectionsInTableView:self.tableView] > 0) {
            // No regular contacts, so show Work contacts by default
            _mode = ModeWorkContacts;
            [self.segmentedControl setSelectedSegmentIndex:ModeWorkContacts];
            _currentDataSource = [self workContactsDataSource];
            if (@available(iOS 11.0, *)) {
                self.tableView.tableHeaderView = [UserSettings sharedUserSettings].companyDirectory == true ? _companyDirectoryCell : nil;
            }
        }
    }
    
    for (int i = 0; i < self.segmentedControl.numberOfSegments; i++) {
        UIView *segment = self.segmentedControl.subviews[i];
        for (id subview in segment.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if ([label.text isEqualToString:@"contacts"]) {
                    segment.accessibilityLabel = NSLocalizedString(@"segmentcontrol_contacts", @"");
                }
                else if ([label.text isEqualToString:@"groups"]) {
                    segment.accessibilityLabel = NSLocalizedString(@"segmentcontrol_groups", @"");
                }
                else if ([label.text isEqualToString:@"work"]) {
                    segment.accessibilityLabel = NSLocalizedString(@"segmentcontrol_work_contacts", @"");
                }
            }
        }
    }
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeGroups];
    [self.segmentedControl setImage:contactImage forSegmentAtIndex:ModeContacts];
    [self.segmentedControl setImage:groupImage forSegmentAtIndex:ModeGroups];
    
    if ([LicenseStore requiresLicenseKey]) {
        [self.segmentedControl setTitle:nil forSegmentAtIndex:ModeWorkContacts];
        [self.segmentedControl setImage:workImage forSegmentAtIndex:ModeWorkContacts];
    }
        
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showProfilePictureChanged:) name:kNotificationShowProfilePictureChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshWorkContactTableView:) name:kNotificationRefreshWorkContactTableView object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContactSortIndices:) name:kNotificationRefreshContactSortIndices object:nil];
    
    [self setRefreshControlTitle:NO];

    [self registerForPreviewingWithDelegate:self sourceView:self.view];
    
    [self setupColors];
    
    self.isMultipleEditing = NO;
    
    [self updateNoContactsView];
    
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
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = _searchController;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        self.statusBarView = [[UIView alloc] initWithFrame:[[UIApplication sharedApplication] statusBarFrame]];
    }
    
    UITapGestureRecognizer *companyDirectoryRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(companyDirectoryTapped:)];
    [_companyDirectoryCell addGestureRecognizer:companyDirectoryRecognizer];
}

- (void)refresh {
    [self setupColors];
    [Colors updateNavigationBar:self.navigationController.navigationBar];
    _companyDirectoryCell.titleLabel.text = [MyIdentityStore sharedMyIdentityStore].companyName;
    [self.tableView reloadData];
}

- (BOOL)isWorkActive {
    return _mode == ModeWorkContacts;
}

- (void)setupColors {
    [self.navigationController.view setBackgroundColor:[Colors background]];
    
    [_statusBarView setBackgroundColor:[Colors searchBarStatusBar]];
    
    _noContactsTitleLabel.textColor = [Colors fontNormal];
    _noContactsMessageLabel.textColor = [Colors fontLight];
    
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
        if (!self.searchController.isActive) {
            self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
        }
        self.navigationItem.largeTitleDisplayMode = [UserSettings sharedUserSettings].largeTitleDisplayMode;
    } else {
        [_statusBarView setBackgroundColor:[Colors searchBarStatusBar]];
    }

    if (!self.rfControl) {
        self.rfControl = [UIRefreshControl new];
        [_rfControl addTarget:self action:@selector(pulledForRefresh:) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = _rfControl;
        self.tableView.refreshControl = _rfControl;
    }
    _rfControl.backgroundColor = [UIColor clearColor];
    [self setRefreshControlTitle:NO];
    
    _companyDirectoryCell.backgroundColor = [Colors background];
    _companyDirectoryCell.selectedBackgroundView = [[UIView alloc] initWithFrame:_companyDirectoryCell.frame];
    _companyDirectoryCell.selectedBackgroundView.backgroundColor = [Colors backgroundDark];
    
    _companyDirectoryCell.titleLabel.textColor = [Colors fontNormal];
    _companyDirectoryCell.descriptionLabel.textColor = [Colors fontLight];
    _companyDirectoryCell.companyAvatar.image = [[AvatarMaker sharedAvatarMaker] companyImage];
    [_companyDirectoryCell setTintColor:[Colors main]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (SYSTEM_IS_IPAD == NO) {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    } else {
        if (contactForDetails && _mode == ModeContacts) {
            NSIndexPath *indexPath = [self.contactsDataSource indexPathForObject:contactForDetails];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } else if (groupForDetails && _mode == ModeGroups) {
            NSIndexPath *indexPath = [self.groupsDataSource indexPathForObject:groupForDetails];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } else if (contactForDetails && _mode == ModeWorkContacts) {
            NSIndexPath *indexPath = [self.workContactsDataSource indexPathForObject:contactForDetails];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
        self.tableView.backgroundView = nil;
    }
    
    [self updateNoContactsView];
    
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
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

- (void)dealloc {
    [[UserSettings sharedUserSettings] removeObserver:self forKeyPath:@"blacklist"];
    [[UserSettings sharedUserSettings] removeObserver:self forKeyPath:@"hideStaleContacts"];
}

- (void)updateNoContactsView {    
    if ([self hasData]) {
        if (_mode == ModeContacts) {
            [self setFooterView:YES];
        }
        else if (_mode == ModeWorkContacts) {
            [self setFooterView:YES];
        }
        else {
            [self setFooterView:NO];
        }
    } else {
        [self setFooterView:NO];

        NSString *messageKey;
        NSString *titleKey;
        if (_mode == ModeContacts) {
            titleKey = @"no_contacts";
            messageKey = [UserSettings sharedUserSettings].syncContacts ? @"no_contacts_syncon" : @"no_contacts_syncoff";
        }
        else if (_mode == ModeWorkContacts) {
            titleKey = @"no_work_contacts";
            messageKey = @"no_work_contacts_message";
        }
        else {
            titleKey = @"no_groups";
            messageKey = @"no_groups_message";
        }
        
        _noContactsTitleLabel.text = NSLocalizedString(titleKey, nil);
        _noContactsMessageLabel.text = NSLocalizedString(messageKey, nil);
        
        self.tableView.tableFooterView = _noContactsView;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"blacklist"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resetData];
        });
    } else if ([keyPath isEqualToString:@"hideStaleContacts"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self resetData];
        });
    }
}

- (void)resetData {
    _currentDataSource = nil;
    _contactsDataSource = nil;
    _groupsDataSource = nil;
    _workContactsDataSource = nil;
    [self.tableView reloadData];
}



- (void)setSelectionForContact:(Contact *)contact {
    if (_segmentedControl.selectedSegmentIndex != ModeContacts) {
        _segmentedControl.selectedSegmentIndex = ModeContacts;
        [self segmentedControlChanged:self];
    }

    /* fix highlighted cell in our view */
    NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
    NSIndexPath *indexPath = [self.contactsDataSource indexPathForObject:contact];

    [self changeSelectedRow:selectedRow to:indexPath];
    
    contactForDetails = contact;
}

- (void)setSelectionForGroup:(GroupProxy *)group {
    if (_segmentedControl.selectedSegmentIndex != ModeGroups) {
        _segmentedControl.selectedSegmentIndex = ModeGroups;
        [self segmentedControlChanged:self];
    }

    /* fix highlighted cell in our view */
    NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
    NSIndexPath *newRow = [self.groupsDataSource indexPathForObject:group];
    
    [self changeSelectedRow:selectedRow to:newRow];
    
    groupForDetails = group;
}

- (void)setSelectionForWorkContact:(Contact *)contact {
    if (_segmentedControl.selectedSegmentIndex != ModeWorkContacts) {
        _segmentedControl.selectedSegmentIndex = ModeWorkContacts;
        [self segmentedControlChanged:self];
    }
    
    /* fix highlighted cell in our view */
    NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
    NSIndexPath *indexPath = [self.workContactsDataSource indexPathForObject:contact];
    
    [self changeSelectedRow:selectedRow to:indexPath];
    
    contactForDetails = contact;
}

- (void)changeSelectedRow:(NSIndexPath *)selectedRow to:(NSIndexPath *)newRow {
    DDLogInfo(@"selectedRow: %@, newRow: %@", selectedRow, newRow);
    
    if (![selectedRow isEqual:newRow]) {
        if (selectedRow != nil)
            [self.tableView deselectRowAtIndexPath:selectedRow animated:NO];
        if (newRow != nil)
            [self.tableView selectRowAtIndexPath:newRow animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)showDetailsForContact:(Contact*)contact {
    [self setSelectionForContact:contact];
    
    [self displayContact];
}

- (void)showDetailsForGroup:(GroupProxy*)group {
    [self setSelectionForGroup:group];
    
    [self displayGroup];
}

- (void)showDetailsForWorkContact:(Contact*)contact {
    [self setSelectionForWorkContact:contact];
    
    [self displayContact];
}

- (BOOL)isEditing {
    return self.tableView.editing;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    self.isMultipleEditing = editing;
}

- (BOOL)showFirstEntryForCurrentMode {
    if (_mode == ModeContacts) {
        Contact *contact = [self getFirstContact];
        if (contact) {
            [self showDetailsForContact:contact];
            return YES;
        }
    }
    
    if (_mode == ModeWorkContacts) {
        Contact *contact = [self getFirstWorkContact];
        if (contact) {
            [self showDetailsForWorkContact:contact];
            return YES;
        }
    }
    
    if (_mode == ModeGroups) {
        GroupProxy *group = [self getFirstGroup];
        if (group) {
            [self showDetailsForGroup:group];
            return YES;
        }
    }
    
    return NO;
}

- (Contact *)getFirstContact {
    if ([self hasContactData]) {
        if ([self.contactsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.contactsDataSource contactAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (GroupProxy *)getFirstGroup {
    if ([self hasGroupData]) {
        if ([self.groupsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.groupsDataSource groupAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (Contact *)getFirstWorkContact {
    if ([self hasWorkContactData]) {
        if ([self.workContactsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.workContactsDataSource workContactAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (void)displayContact {
    if (SYSTEM_IS_IPAD == NO) {
        [self performSegueWithIdentifier:@"ShowContact" sender:self];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:[NSDictionary dictionaryWithObject:contactForDetails forKey:kKeyContact]];
    }
}

- (void)displayGroup {
    if (SYSTEM_IS_IPAD == NO) {
        GroupDetailsViewController *detailsViewController = [self groupDetailsViewControllerForGroup:groupForDetails];
        
        [self.navigationController pushViewController:detailsViewController animated:YES];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowGroup object:nil userInfo:[NSDictionary dictionaryWithObject:groupForDetails forKey:kKeyGroup]];
    }
}

- (GroupDetailsViewController *)groupDetailsViewControllerForGroup:(GroupProxy *)group {
    GroupDetailsViewController *detailsViewController = (GroupDetailsViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"groupDetailsViewController"];
    detailsViewController.group = group;
    
    return detailsViewController;
}

- (ContactDetailsViewController *)contactDetailsViewControllerForContact:(Contact *)contact {
    ContactDetailsViewController *detailsViewController = (ContactDetailsViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"contactDetailsViewController"];
    detailsViewController.contact = contact;
    
    return detailsViewController;
}

- (BOOL)hasContactData {
    if ([self.contactsDataSource numberOfSectionsInTableView:self.tableView] > 0) {
        NSInteger count = [self.contactsDataSource tableView:self.tableView numberOfRowsInSection:0];
        if (count > 0) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)hasGroupData {
    if ([self.groupsDataSource numberOfSectionsInTableView:self.tableView] > 0) {
        NSInteger count = [self.groupsDataSource tableView:self.tableView numberOfRowsInSection:0];
        if (count > 0) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)hasWorkContactData {
    if ([self.workContactsDataSource numberOfSectionsInTableView:self.tableView] > 0) {
        NSInteger count = [self.workContactsDataSource tableView:self.tableView numberOfRowsInSection:0];
        if (count > 0) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)hasData {    
    if (_mode == ModeContacts) {
        return [self.contactsDataSource numberOfSectionsInTableView:self.tableView] > 0;
    }
    else if (_mode == ModeWorkContacts) {
        return [self.workContactsDataSource numberOfSectionsInTableView:self.tableView] > 0;
    }
    else {
        return [self.groupsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0;
    }
}

- (ContactTableDataSource *)contactsDataSource {
    if (_contactsDataSource == nil) {
        _contactsDataSource = [ContactTableDataSource contactTableDataSourceWithFetchedResultsControllerDelegate:self members:nil];
        
        // make sure sort indices are up to date
        [_contactsDataSource refreshContactSortIndices];
    }
    
    return _contactsDataSource;
}

- (GroupTableDataSource *)groupsDataSource {
    if (_groupsDataSource == nil) {
        _groupsDataSource = [GroupTableDataSource groupTableDataSourceWithFetchedResultsControllerDelegate:self];
    }
    
    return _groupsDataSource;
}

- (WorkContactTableDataSource *)workContactsDataSource {
    if (_workContactsDataSource == nil) {
        _workContactsDataSource = [WorkContactTableDataSource workContactTableDataSourceWithFetchedResultsControllerDelegate:self members:nil];
        
        // make sure sort indices are up to date
        [_workContactsDataSource refreshWorkContactSortIndices];
    }
    
    return _workContactsDataSource;
}

- (id<ContactGroupDataSource>)currentDataSource {
    if (_currentDataSource == nil) {
        if (_mode == ModeContacts) {
            _contactsDataSource = [self contactsDataSource];
            _currentDataSource = _contactsDataSource;
        }
        else if (_mode == ModeWorkContacts) {
            _workContactsDataSource = [self workContactsDataSource];
            _currentDataSource = _workContactsDataSource;
        }
        else {
            _groupsDataSource = [self groupsDataSource];
            _currentDataSource = _groupsDataSource;
        }
    }
    
    return _currentDataSource;
}

- (void)setFooterView:(BOOL)show {
    if (_mode == ModeGroups) {
        self.tableView.tableFooterView = nil;
    } else {
        if (show) {
            NSUInteger contactsCount;
            if (_mode == ModeContacts) {
                contactsCount = [((ContactTableDataSource *)self.currentDataSource) countOfContacts];
            }
            else {
                contactsCount = [((WorkContactTableDataSource *)self.currentDataSource) countOfWorkContacts];
            }
            _countContactsFooterLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)contactsCount, [BundleUtil localizedStringForKey:@"contacts"]];
            self.tableView.tableFooterView = _countContactsFooterView;
        } else {
            self.tableView.tableFooterView = nil;
        }
    }
}

- (void)setRefreshControlTitle:(BOOL)active {
    NSString *refreshText = nil;
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    if (active) {
        refreshText = NSLocalizedString(@"synchronizing", nil);
    } else {
        refreshText = NSLocalizedString(@"pull_to_sync", nil);
    }
    NSMutableAttributedString *attributedRefreshText = [[NSMutableAttributedString alloc] initWithString:refreshText attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: [Colors fontLight], NSBackgroundColorAttributeName: [UIColor clearColor]}];
    _rfControl.attributedTitle = attributedRefreshText;
}

#pragma mark - Table view

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(nonnull UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView*)view;
    [headerView.textLabel setTextColor:[Colors fontNormal]];
    headerView.backgroundView = [[UIView alloc] initWithFrame:headerView.bounds];
    headerView.backgroundView.backgroundColor = [Colors backgroundDark];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[ContactCell class]]) {
        ContactCell *contactCell = (ContactCell *)cell;
        [contactCell.identityLabel setTextColor:[Colors fontLight]];
        [contactCell.nicknameLabel setTextColor:[Colors fontLight]];
    } else if ([cell isKindOfClass:[GroupCell class]]) {
        GroupCell *groupCell = (GroupCell *)cell;
        [groupCell.groupNameLabel setTextColor:[Colors fontNormal]];
        [groupCell.countMemberLabel setTextColor:[Colors fontLight]];
        [groupCell.creatorLabel setTextColor:[Colors fontLight]];
    } else {
        [Colors updateTableViewCell:cell];
    }

    [Colors updateTableViewCellBackground:cell];
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    [super setEditing:YES animated:YES];
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    [super setEditing:NO animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (@available(iOS 11.0, *)) {
        return [self.currentDataSource numberOfSectionsInTableView:tableView];
    } else {
        NSInteger section = [self.currentDataSource numberOfSectionsInTableView:tableView];
        if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
            section++;
        }
        return section;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (@available(iOS 11.0, *)) {
        return [self.currentDataSource tableView:tableView numberOfRowsInSection:section];
    } else {
        if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true && section == 0) {
            return 1;
        }
        if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
            return [self.currentDataSource tableView:tableView numberOfRowsInSection:section - 1];
        }
        return [self.currentDataSource tableView:tableView numberOfRowsInSection:section];
    }
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [self.currentDataSource sectionIndexTitlesForTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [self.currentDataSource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (@available(iOS 11.0, *)) {
        return [self.currentDataSource tableView:tableView titleForHeaderInSection:section];
    } else {
        if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true && section == 0) {
            return nil;
        } else if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
            return [self.currentDataSource tableView:tableView titleForHeaderInSection:section - 1];
        } else {
            return [self.currentDataSource tableView:tableView titleForHeaderInSection:section];
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
        UITableViewCell *cell;
        
        if (_mode == ModeContacts) {
            cell = [self tableView:tableView contactCellForIndexPath:indexPath];
        }
        else if (_mode == ModeWorkContacts) {
            cell = [self tableView:tableView workContactCellForIndexPath:indexPath];
        }
        else {
            cell = [self tableView:tableView groupCellForIndexPath:indexPath];
        }
        
        if (_searchController.isActive) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    
        if (@available(iOS 11.0, *)) {
            // do nothing
        } else {
            if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true && indexPath.section == 0) {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
        
        return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView contactCellForIndexPath:(NSIndexPath *)indexPath {

    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    
    Contact *contact = [self.contactsDataSource contactAtIndexPath:indexPath];
    cell.contact = contact;
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView groupCellForIndexPath:(NSIndexPath *)indexPath {

    GroupCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupCell"];
    
    GroupProxy *group = [self.groupsDataSource groupAtIndexPath:indexPath];
    cell.group = group;
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView workContactCellForIndexPath:(NSIndexPath *)indexPath {
    
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    Contact *contact = nil;
    if (@available(iOS 11.0, *)) {
        contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
    } else {
        if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true && indexPath.section == 0) {
            return _companyDirectoryCell;
        }
        else if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
            NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
            contact = [self.workContactsDataSource workContactAtIndexPath:newIndexPath];
        } else {
            contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
        }
    }
    
    cell.contact = contact;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        _deletionIndexPath = indexPath;
        
        if (_mode == ModeGroups) {
            GroupProxy *group = [self.groupsDataSource groupAtIndexPath:indexPath];
            [self deleteGroup:group];
            [self updateNoContactsView];
        }
        else if (_mode == ModeWorkContacts) {
            Contact *contact = nil;
            if (@available(iOS 11.0, *)) {
                contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
            } else {
                if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
                    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
                    contact = [self.workContactsDataSource workContactAtIndexPath:newIndexPath];
                } else {
                    contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
                }
            }
            [self deleteContact:contact];
            [self updateNoContactsView];
        }
        else {
            Contact *contact = [self.contactsDataSource contactAtIndexPath:indexPath];
            [self deleteContact:contact];
            [self updateNoContactsView];
        }
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    UITableViewCell *contextCell = [tableView cellForRowAtIndexPath:indexPath];
    if ([contextCell isKindOfClass:[ContactCell class]]) {
        ContactCell *contactCell = (ContactCell *)contextCell;
        ContactDetailsViewController *contactVc = [self contactDetailsViewControllerForContact:contactCell.contact];
        contactVc.hideActionButtons = YES;
        contactVc.delegate = self;
        
        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
            return contactVc;
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            NSMutableArray *actionArray = [NSMutableArray new];
            
            NSString *sendMessageActionTitle = [BundleUtil localizedStringForKey:@"send_message"];
            UIImage *sendMessageImage = [[BundleUtil imageNamed:@"SendMessage"] imageWithTintColor:[Colors fontNormal]];
            UIAction *sendMessageAction = [UIAction actionWithTitle:sendMessageActionTitle image:sendMessageImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                contactForDetails = contactCell.contact;
                [contactVc sendMessageAction];
            }];
            [actionArray addObject:sendMessageAction];

            if ([ScanIdentityController canScan]) {
                NSString *scanQrCodeActionTitle = [BundleUtil localizedStringForKey:@"scan_qr"];
                UIImage *scanQrCodeActionImage = [[BundleUtil imageNamed:@"QRScan"] imageWithTintColor:[Colors fontNormal]];
                UIAction *scanQrCodeAction = [UIAction actionWithTitle:scanQrCodeActionTitle image:scanQrCodeActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    contactForDetails = contactCell.contact;
                    [self presentWithContactDetailsViewController:contactVc onCompletion:^(ContactDetailsViewController * contactDetailsVc) {
                        [contactDetailsVc scanIdentityAction];
                    }];
                }];
                [actionArray addObject:scanQrCodeAction];
            }
            
            if ([[UserSettings sharedUserSettings] enableThreemaCall] && is64Bit == 1) {
                NSString *threemaCallActionTitle = [BundleUtil localizedStringForKey:@"call_threema_title"];
                UIImage *threemaCallActionImage = [[BundleUtil imageNamed:@"ThreemaPhone"] imageWithTintColor:[Colors fontNormal]];
                UIAction *threemaCallAction = [UIAction actionWithTitle:threemaCallActionTitle image:threemaCallActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    contactForDetails = contactCell.contact;
                    [self presentWithContactDetailsViewController:contactVc onCompletion:^(ContactDetailsViewController * contactDetailsVc) {
                        [contactDetailsVc startThreemaCallAction:false];
                    }];
                }];
                [actionArray addObject:threemaCallAction];
            }
                                    
            return [UIMenu menuWithTitle:contactVc.contact.displayName image:nil identifier:nil options:UIMenuOptionsDisplayInline children:actionArray];
        }];
        return conf;
    }
    else if ([contextCell isKindOfClass:[GroupCell class]]) {
        GroupCell *groupCell = (GroupCell *)contextCell;
        GroupDetailsViewController *groupVc = [self groupDetailsViewControllerForGroup:groupCell.group];
        groupVc.hideActionButtons = YES;
        groupVc.delegate = self;
        
        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
            return groupVc;
        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            NSMutableArray *actionArray = [NSMutableArray new];
            
            NSString *sendMessageActionTitle = [BundleUtil localizedStringForKey:@"send_message"];
            UIImage *sendMessageImage = [[BundleUtil imageNamed:@"TabBar-Chats"] imageWithTintColor:[Colors fontNormal]];
            UIAction *sendMessageAction = [UIAction actionWithTitle:sendMessageActionTitle image:sendMessageImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                groupForDetails = groupCell.group;
                [groupVc sendMessageAction];
            }];
            [actionArray addObject:sendMessageAction];
            
            if ([groupVc.group isOwnGroup]) {
                NSString *syncActionTitle = [BundleUtil localizedStringForKey:@"sync_group"];
                UIImage *syncActionImage = [[BundleUtil imageNamed:@"Sync"] imageWithTintColor:[Colors fontNormal]];
                UIAction *syncAction = [UIAction actionWithTitle:syncActionTitle image:syncActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    groupForDetails = groupCell.group;
                    [self presentGroupDetails:groupVc onCompletion:^(GroupDetailsViewController *groupDetailsViewController) {
                        [groupDetailsViewController syncMembers];
                    }];
                }];
                [actionArray addObject:syncAction];
            }
                                        
            if (![groupVc.group didLeaveGroup]) {
                NSString *leaveActionTitle = [BundleUtil localizedStringForKey:@"leave_group"];
                UIImage *leaveActionImage = [UIImage systemImageNamed:@"minus.circle.fill" compatibleWithTraitCollection:self.traitCollection];
                UIAction *leaveAction = [UIAction actionWithTitle:leaveActionTitle image:leaveActionImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    groupForDetails = groupCell.group;
                    [self presentGroupDetails:groupVc onCompletion:^(GroupDetailsViewController *groupDetailsViewController) {
                        [groupDetailsViewController leaveGroup];
                    }];
                }];
                leaveAction.attributes = UIMenuElementAttributesDestructive;
                [actionArray addObject:leaveAction];
            }
                                        
            return [UIMenu menuWithTitle:groupVc.group.name image:nil identifier:nil options:UIMenuOptionsDisplayInline children:actionArray];
        }];
        return conf;
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    UIViewController *previewVc = animator.previewViewController;
    if ([previewVc isKindOfClass:[ContactDetailsViewController class]]) {
        contactForDetails = ((ContactDetailsViewController *)previewVc).contact;
        [animator addCompletion:^{
            [self displayContact];
        }];
    } else if ([previewVc isKindOfClass:[GroupDetailsViewController class]]) {
        groupForDetails = ((GroupDetailsViewController *)previewVc).group;
        [animator addCompletion:^{
            [self displayGroup];
        }];
    }
}

- (void)updateTableViewAfterDeletion:(BOOL)succeeded {
    if (succeeded) {
        if ([_currentDataSource isFiltered]) {
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:_deletionIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } // else FRC kicks in
    } else {
        if ([_currentDataSource isFiltered]) {
            [self.tableView setEditing:NO animated:YES];
             [super setEditing:NO animated:YES];
        } else {
            [self.tableView setEditing:NO animated:YES];
            [super setEditing:NO animated:YES];
        }
    }
    
    if (!_isMultipleEditing) {
        [super setEditing:NO animated:YES];
    }
}

- (void)deleteGroup:(GroupProxy *)group {
    Conversation *conversation = group.conversation;
    DeleteConversationAction *deleteAction = [DeleteConversationAction deleteActionForConversation:conversation];
    deleteAction.presentingViewController = self;
    
    _deleteAction = deleteAction;
    [deleteAction executeOnCompletion:^(BOOL succeeded) {
        [self updateTableViewAfterDeletion:succeeded];
    }];
}

- (void)deleteContact:(Contact *) contact {
    DeleteContactAction *deleteAction = [DeleteContactAction deleteActionForContact:contact];
    deleteAction.presentingViewController = self;
    
    _deleteAction = deleteAction;
    [deleteAction executeOnCompletion:^(BOOL succeeded) {
        [self updateTableViewAfterDeletion:succeeded];
    }];
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ShowContact"]) {
        [[segue destinationViewController] setContact:contactForDetails];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_mode == ModeGroups) {
        groupForDetails = [self.groupsDataSource groupAtIndexPath:indexPath];
        [self displayGroup];
    }
    else if (_mode == ModeWorkContacts) {
        if (@available(iOS 11.0, *)) {
            contactForDetails = [self.workContactsDataSource workContactAtIndexPath:indexPath];
        } else {
            if (_mode == ModeWorkContacts && [UserSettings sharedUserSettings].companyDirectory == true) {
                NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
                contactForDetails = [self.workContactsDataSource workContactAtIndexPath:newIndexPath];
            } else {
                contactForDetails = [self.workContactsDataSource workContactAtIndexPath:indexPath];
            }
        }
        
        [self displayContact];
    }
    else {
        contactForDetails = [self.contactsDataSource contactAtIndexPath:indexPath];
        [self displayContact];
    }
}

#pragma mark - Fetched results controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    //nop
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    //nop
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    //nop
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self updateNoContactsView];
    
    [self.tableView reloadData];
}

#pragma mark - Search controller delegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    if (@available(iOS 11.0, *)) {
        self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 0.0);
    } else {
        [self.searchController.view addSubview:_statusBarView];
    }
    [self setFooterView:NO];
    _rfControl = self.refreshControl;
    self.refreshControl = nil;
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    if (@available(iOS 11.0, *)) {
        self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
    } else {
        [_statusBarView removeFromSuperview];
    }
    
    self.refreshControl = _rfControl;
    [self updateNoContactsView];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController{
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
            self.navigationItem.title = NSLocalizedString(@"segmentcontrol_contacts", nil);
            self.refreshControl = _rfControl;
            _currentDataSource = [self contactsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:NO];
            [_workContactsDataSource setIgnoreFRCUpdates:YES];
            [_groupsDataSource setIgnoreFRCUpdates:YES];

            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];

            [self updateNoContactsView];
            if (@available(iOS 11.0, *)) {
                self.tableView.tableHeaderView = nil;
            }
            break;
            
        case ModeWorkContacts:
            self.navigationItem.title = NSLocalizedString(@"segmentcontrol_work_contacts", nil);
            self.refreshControl = _rfControl;
            _currentDataSource = [self workContactsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:YES];
            [_workContactsDataSource setIgnoreFRCUpdates:NO];
            [_groupsDataSource setIgnoreFRCUpdates:YES];
            
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            if (@available(iOS 11.0, *)) {
                self.tableView.tableHeaderView = [UserSettings sharedUserSettings].companyDirectory == true ? _companyDirectoryCell : nil;
            }
            
            [self updateNoContactsView];
            break;
            
        case ModeGroups:
            self.navigationItem.title = NSLocalizedString(@"segmentcontrol_groups", nil);
            _rfControl = self.refreshControl;
            self.refreshControl = nil;
            _currentDataSource = [self groupsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:YES];
            [_workContactsDataSource setIgnoreFRCUpdates:YES];
            [_groupsDataSource setIgnoreFRCUpdates:NO];

            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            if (@available(iOS 11.0, *)) {
                self.tableView.tableHeaderView = nil;
            }
            self.tableView.tableFooterView = nil;
            break;
            
        default:
            break;
    }
    
    [self.tableView reloadData];
        
    if ([self hasData]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (IBAction)addAction:(id)sender {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    if (_mode == ModeContacts || _mode == ModeWorkContacts) {
        if ([mdmSetup disableAddContact]) {
            [UIAlertTemplate showAlertWithOwner:self title:@"" message:NSLocalizedString(@"disabled_by_device_policy", nil) actionOk:nil];
            return;
        }
        UIStoryboard *storyboard = self.storyboard;
        UINavigationController *navVC = [storyboard instantiateViewControllerWithIdentifier:@"AddContactNavigationController"];
        
        [self presentViewController:navVC animated:YES completion:nil];
    } else {
        if ([mdmSetup disableCreateGroup]) {
            [UIAlertTemplate showAlertWithOwner:self title:@"" message:NSLocalizedString(@"disabled_by_device_policy", nil) actionOk:nil];
            return;
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
        UINavigationController *navVC = [storyboard instantiateInitialViewController];
        
        [self presentViewController:navVC animated:YES completion:nil];
    }
}

- (IBAction)pulledForRefresh:(UIRefreshControl *)sender {
    _mode = self.segmentedControl.selectedSegmentIndex;
    
    if ((_mode == ModeContacts || _mode == ModeWorkContacts) && !self.searchController.active) {
        [self setRefreshControlTitle:YES];
        _segmentedControl.userInteractionEnabled = NO;
        
        [[GatewayAvatarMaker gatewayAvatarMaker] refreshForced];
        if ([UserSettings sharedUserSettings].syncContacts) {
            [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES ignoreMinimumInterval:YES onCompletion:^(BOOL addressBookAccessGranted) {
                [self updateWorkDataAndEndRefreshing:sender];
                if (!addressBookAccessGranted) {
                    [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"no_contacts_permission_title", nil) message:NSLocalizedString(@"no_contacts_permission_message", nil) actionOk:nil];
                }
            } onError:^(NSError *error) {
                [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:^(UIAlertAction * _Nonnull okAction) {
                    [self updateWorkDataAndEndRefreshing:sender];
                }];
            }];
        } else {
            [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES ignoreMinimumInterval:YES onCompletion:^(BOOL addressBookAccessGranted) {
                [self updateWorkDataAndEndRefreshing:sender];
            } onError:^(NSError *error) {
                [self updateWorkDataAndEndRefreshing:sender];
            }];
        }
    } else {
        self.segmentedControl.userInteractionEnabled = YES;
        [sender endRefreshing];
        [self.rfControl endRefreshing];
    }
}

- (void)updateWorkDataAndEndRefreshing:(UIRefreshControl*)rfSender {
    [WorkDataFetcher checkUpdateWorkDataForce:YES onCompletion:^{
        [self endRefreshingAndScrollUp:rfSender];
    } onError:^(NSError *error) {
        [self endRefreshingAndScrollUp:rfSender];
        
        [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }];
}

- (void)endRefreshingAndScrollUp:(UIRefreshControl*)rfSender {
    [self setRefreshControlTitle:NO];
    self.segmentedControl.userInteractionEnabled = YES;
    [rfSender endRefreshing];
    [self.rfControl endRefreshing];
    
    if ([self.tableView numberOfSections] > 0 && [self.tableView numberOfRowsInSection:0] > 0)
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (void)companyDirectoryTapped:(UITapGestureRecognizer *)recognizer {
    ThemedTableViewController *companyDirectoryViewController = (ThemedTableViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"CompanyDirectoryViewController"];
    
    ModalNavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:companyDirectoryViewController];
    nav.showDoneButton = true;
    nav.showFullScreenOnIPad = false;
    
    [self presentViewController:nav animated:YES completion:nil];

}

#pragma mark - UIViewControllerPreviewingDelegate

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    if ([viewControllerToCommit isKindOfClass:[ContactDetailsViewController class]]) {
        contactForDetails = ((ContactDetailsViewController *)viewControllerToCommit).contact;
        [self displayContact];
    } else if ([viewControllerToCommit isKindOfClass:[GroupDetailsViewController class]]) {
        groupForDetails = ((GroupDetailsViewController *)viewControllerToCommit).group;
        [self displayGroup];
    }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    
    UIView *view = [self.view hitTest:location withEvent:nil];
    
    if ([view.superview isKindOfClass:[ContactCell class]]) {
        ContactCell *contactCell = (ContactCell *)view.superview;
        ContactDetailsViewController *contactVc = [self contactDetailsViewControllerForContact:contactCell.contact];
        contactVc.hideActionButtons = YES;
        contactVc.delegate = self;

        return contactVc;
    } else if ([view.superview isKindOfClass:[GroupCell class]]) {
        GroupCell *groupCell = (GroupCell *)view.superview;
        GroupDetailsViewController *groupVc = [self groupDetailsViewControllerForGroup:groupCell.group];
        groupVc.hideActionButtons = YES;
        groupVc.delegate = self;
        
        return groupVc;
    }

    return nil;
}

#pragma mark - GroupDetailsViewControllerDelegate

- (void)presentGroupDetails:(GroupDetailsViewController *)groupDetailsViewController onCompletion:(void (^)(GroupDetailsViewController *))onCompletion {
    groupForDetails = groupDetailsViewController.group;
    
    _prevNavigationControllerDelegate = self.navigationController.delegate;
    self.navigationController.delegate = self;
    
    [self displayGroup];
    
    _groupCompletionBlock = onCompletion;
}

#pragma mark - ContactDetailsViewControllerDelegate

- (void)presentWithContactDetailsViewController:(ContactDetailsViewController *)contactDetailsViewController onCompletion:(void (^)(ContactDetailsViewController * _Nonnull))onCompletion {
    contactForDetails = contactDetailsViewController.contact;
    
    _prevNavigationControllerDelegate = self.navigationController.delegate;
    self.navigationController.delegate = self;
    
    [self displayContact];
    
    _contactCompletionBlock = onCompletion;
}


#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    if (_groupCompletionBlock) {
        if ([viewController isKindOfClass:[GroupDetailsViewController class]]) {
            _groupCompletionBlock((GroupDetailsViewController *)viewController);
        }

        _groupCompletionBlock = nil;
    }

    if (_contactCompletionBlock) {
        if ([viewController isKindOfClass:[ContactDetailsViewController class]]) {
            _contactCompletionBlock((ContactDetailsViewController *)viewController);
        }
        
        _contactCompletionBlock = nil;
    }

    self.navigationController.delegate = _prevNavigationControllerDelegate;
}

#pragma mark - Notifications

- (void)showProfilePictureChanged:(NSNotification *)notification {
    [self refresh];
}

- (void)refreshWorkContactTableView:(NSNotification *)notification {
    if (@available(iOS 11.0, *)) {
        [self refresh];
        self.tableView.tableHeaderView = [UserSettings sharedUserSettings].companyDirectory == true ? _companyDirectoryCell : nil;
    } else {
        [self refresh];
    }
}

- (void)refreshContactSortIndices:(NSNotification *)notification {
    if (_contactsDataSource != nil) {
        [_contactsDataSource refreshContactSortIndices];
    }
    if (_workContactsDataSource != nil) {
        [_workContactsDataSource refreshWorkContactSortIndices];
    }
}

@end
