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

#import "ContactsViewController.h"
#import "ContactStore.h"
#import "UserSettings.h"
#import "DatabaseManager.h"
#import "GatewayAvatarMaker.h"
#import "ContactTableDataSource.h"
#import "GroupTableDataSource.h"
#import "WorkContactTableDataSource.h"
#import "DistributionListTableDataSource.h"
#import "DeleteConversationAction.h"
#import "ModalPresenter.h"
#import "RectUtil.h"
#import "WorkDataFetcher.h"
#import "LicenseStore.h"
#import "BundleUtil.h"
#import "ModalNavigationController.h"
#import "MDMSetup.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

typedef enum : NSUInteger {
    ModeContacts,
    ModeGroups,
    ModeDistributionLists,
    ModeWorkContacts
} Mode;


@interface ContactsViewController () <UIViewControllerPreviewingDelegate>

@property Mode mode;

@property (nonatomic) id<ContactGroupDataSource> currentDataSource;

@property EntityManager *entityManager;
@property (nonatomic) ContactTableDataSource *contactsDataSource;
@property (nonatomic) GroupTableDataSource *groupsDataSource;
@property (nonatomic) DistributionListTableDataSource *distributionListTableDataSource;
@property (nonatomic) WorkContactTableDataSource *workContactsDataSource;

@property NSIndexPath *deletionIndexPath;
@property id deleteAction;

@property (nonatomic) BOOL isMultipleEditing;

@property (nonatomic, strong) UIRefreshControl *rfControl;

@end

@implementation ContactsViewController {
    ContactEntity *contactForDetails;
    Group *groupForDetails;
    DistributionListEntity *distributionListForDetails;
    NSTimer *updateContactsTimer;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        /* listen for blacklist change (to refresh contact labels with blocked icon) */
        [[UserSettings sharedUserSettings] addObserver:self forKeyPath:@"blacklist" options:0 context:nil];

        /* listen for stale contacts setting */
        [[UserSettings sharedUserSettings] addObserver:self forKeyPath:@"hideStaleContacts" options:0 context:nil];
        
        _entityManager = [[EntityManager alloc] init];
        
        if (TargetManagerObjc.isBusinessApp) {
            _companyDirectoryCellView = [[CompanyDirectoryCellView alloc] init];
        }
    }
    self.navigationController.title = [BundleUtil localizedStringForKey:@"contacts"];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _currentDataSource = [self currentDataSource];
        
    UIImage *contactImage = [UIImage systemImageNamed:@"person.fill"];
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
        
        if (TargetManagerObjc.isBusinessApp) {
            [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
            UIImage *workImage = [BundleUtil imageNamed:@"case.fill"];
            workImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
            [self.segmentedControl setImage:workImage forSegmentAtIndex:ModeWorkContacts];
            
        }
    }
    else {
        if (TargetManagerObjc.isBusinessApp) {
            [self.segmentedControl insertSegmentWithTitle:@"work" atIndex:ModeWorkContacts animated:NO];
            UIImage *workImage = [BundleUtil imageNamed:@"case.fill"];
            workImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
            [self.segmentedControl setImage:workImage forSegmentAtIndex:ModeWorkContacts-1];
            
        }
    }
        
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshWorkContactTableView:) name:kNotificationRefreshWorkContactTableView object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContactSortIndices:) name:kNotificationRefreshContactSortIndices object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDirtyObjects:) name:kNotificationDBRefreshedDirtyObject object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadingWorkContacts:) name:kNotificationLoadWorkContacts object:nil];

    [self setRefreshControlTitle:NO];
    
    [self updateColors];
    _noContactsTitleLabel.textColor = UIColor.labelColor;
    _noContactsMessageLabel.textColor = UIColor.secondaryLabelColor;
    _countContactsFooterLabel.textColor = UIColor.tertiaryLabelColor;
    
    self.isMultipleEditing = NO;
    
    [self updateNoContactsView];
    
    self.searchController = [[UISearchController alloc]initWithSearchResultsController:nil];
    self.searchController.delegate = self;
    self.searchController.searchBar.showsScopeBar = NO;
    self.searchController.searchBar.scopeButtonTitles = nil;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.searchController.searchBar sizeToFit];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.definesPresentationContext = YES;
    self.searchController.hidesNavigationBarDuringPresentation = YES;
    
    self.navigationItem.searchController = _searchController;
    
    UITapGestureRecognizer *companyDirectoryRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(companyDirectoryTapped:)];
    [_companyDirectoryCellView addGestureRecognizer:companyDirectoryRecognizer];
    
    [self.tableView registerClass:ContactCell.class forCellReuseIdentifier:@"ContactCell"];
    [self.tableView registerClass:GroupCell.class forCellReuseIdentifier:@"GroupCell"];
    [self.tableView registerClass:DistributionListCell.class forCellReuseIdentifier:@"DistributionListCell"];
    self.title = [BundleUtil localizedStringForKey:@"contacts"];
}

- (void)refresh {
    [self updateColors];
    [_companyDirectoryCellView refresh];
    [self.tableView reloadData];
}

- (BOOL)isWorkActive {
    return _mode == ModeWorkContacts;
}

- (void)updateColors {
    [super updateColors];
    [self.navigationController.view setBackgroundColor:Colors.backgroundNavigationController];
        
    [Colors updateWithTableView:self.tableView];
    [Colors updateWithSearchBar:self.searchController.searchBar];
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (navigationBar) {
        navigationBar.barTintColor = Colors.backgroundNavigationController;
    }
    
    if (!self.rfControl) {
        self.rfControl = [UIRefreshControl new];
        [_rfControl addTarget:self action:@selector(pulledForRefresh:) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = _rfControl;
        self.tableView.refreshControl = _rfControl;
    }
    _rfControl.backgroundColor = [UIColor clearColor];
    [self setRefreshControlTitle:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (SYSTEM_IS_IPAD == NO) {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    } else {
        if (contactForDetails && _mode == ModeContacts) {
            if (contactForDetails.willBeDeleted) {
                ContactEntity *contact = [self getFirstContact];
                if (contact) {
                    [self showDetailsForContact:contact];
                    [self setSelectionForContact:contact];
                }
            } else {
                NSIndexPath *indexPath = [self.contactsDataSource indexPathForObject:contactForDetails];
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        } else if (groupForDetails && _mode == ModeGroups) {
            if (groupForDetails.conversation.willBeDeleted) {
                Group *group = [self getFirstGroup];
                if (group) {
                    [self showDetailsForGroup:group];
                    [self setSelectionForGroup:group];
                }
            } else {
                NSIndexPath *indexPath = [self.groupsDataSource indexPathForObject:groupForDetails];
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }

        } else if (distributionListForDetails && _mode == ModeDistributionLists) {
            if (distributionListForDetails.conversation.willBeDeleted) {
                DistributionListEntity *distributionList = [self getFirstDistributionList];
                if (distributionList) {
                    [self showDetailsForDistributionList:distributionList];
                    [self setSelectionForDistributionList:distributionList];
                }
            } else {
                NSIndexPath *indexPath = [self.distributionListTableDataSource indexPathForObject:distributionListForDetails];
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
            
        } else if (contactForDetails && _mode == ModeWorkContacts) {
            if (contactForDetails.willBeDeleted) {
                ContactEntity *contact = [self getFirstWorkContact];
                if (contact) {
                    [self showDetailsForWorkContact:contact];
                    [self setSelectionForWorkContact:contact];
                }
            } else {
                NSIndexPath *indexPath = [self.workContactsDataSource indexPathForObject:contactForDetails];
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
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
        
        if (_mode == ModeContacts) {
            [self updateNoDataForContacts];
        }
        else if (_mode == ModeGroups){
            _noContactsTitleLabel.text = [BundleUtil localizedStringForKey:@"no_groups"];
            _noContactsMessageLabel.text = [BundleUtil localizedStringForKey:@"no_groups_message"];
            [self shouldShowNoContactIndicatorView:NO];
        }
        
        else if (_mode == ModeDistributionLists) {
            _noContactsTitleLabel.text = [BundleUtil localizedStringForKey:@"no_distribution_list"];
            _noContactsMessageLabel.text = [BundleUtil localizedStringForKey:@"no_distribution_list_message"];
            [self shouldShowNoContactIndicatorView:NO];
        }
        else if (_mode == ModeWorkContacts) {
            [self updateNoDataForWorkContacts];
        }
        else {
            _noContactsTitleLabel.text = nil;
            _noContactsMessageLabel.text = nil;
            [self shouldShowNoContactIndicatorView:NO];
        }
        
        self.tableView.tableFooterView = _noContactsView;
    }
}

- (void)updateNoDataForContacts {
    if ([AppDelegate sharedAppDelegate].isWorkContactsLoading && TargetManagerObjc.isBusinessApp) {
        _noContactsTitleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_work_contacts"], TargetManagerObjc.appName];
        _noContactsMessageLabel.text = [BundleUtil localizedStringForKey:@"no_contacts_loading"];
        
        [self shouldShowNoContactIndicatorView:YES];
    }
    else {
        _noContactsTitleLabel.text = [BundleUtil localizedStringForKey:@"no_contacts"];
        if (TargetManagerObjc.isOnPrem) {
            _noContactsMessageLabel.text = @"";
        } else {
            NSString *stringSyncON = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_contacts_syncon"], TargetManagerObjc.appName];
            NSString *stringSyncOFF = [BundleUtil localizedStringForKey:@"no_contacts_syncoff"];
            _noContactsMessageLabel.text = [UserSettings sharedUserSettings].syncContacts ? stringSyncON : stringSyncOFF;
        }
        [self shouldShowNoContactIndicatorView:NO];
    }
}

- (void)updateNoDataForWorkContacts {
    if ([AppDelegate sharedAppDelegate].isWorkContactsLoading) {
        _noContactsTitleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_work_contacts"], TargetManagerObjc.appName];
        _noContactsMessageLabel.text = [BundleUtil localizedStringForKey:@"no_contacts_loading"];
        [self shouldShowNoContactIndicatorView:YES];
    }
    else {
        _noContactsTitleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_work_contacts"], TargetManagerObjc.appName];
        _noContactsMessageLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"no_work_contacts_message"], TargetManagerObjc.appName];
        [self shouldShowNoContactIndicatorView:NO];
    }
}

- (void)shouldShowNoContactIndicatorView:(BOOL)show {
    if (show) {
        [_loadingWorkContactsIndicatorView startAnimating];
        _loadingWorkContactsIndicatorView.hidden = false;
    }
    else {
        [_loadingWorkContactsIndicatorView stopAnimating];
        _loadingWorkContactsIndicatorView.hidden = true;
        
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
    _distributionListTableDataSource = nil;
    _workContactsDataSource = nil;
    [self.tableView reloadData];
}



- (void)setSelectionForContact:(ContactEntity *)contact {
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

- (void)setSelectionForGroup:(Group *)group {
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

- (void)setSelectionForDistributionList:(DistributionListEntity *)distributionList {
    if (_segmentedControl.selectedSegmentIndex != ModeDistributionLists) {
        _segmentedControl.selectedSegmentIndex = ModeDistributionLists;
        [self segmentedControlChanged:self];
    }
    
    /* fix highlighted cell in our view */
    NSIndexPath *selectedRow = [self.tableView indexPathForSelectedRow];
    NSIndexPath *indexPath = [self.distributionListTableDataSource indexPathForObject:distributionList];
    
    [self changeSelectedRow:selectedRow to:indexPath];
    
    distributionListForDetails = distributionList;
}

- (void)setSelectionForWorkContact:(ContactEntity *)contact {
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

- (void)showDetailsForContact:(ContactEntity*)contact {
    [self setSelectionForContact:contact];
    
    [self displayContact];
}

- (void)showDetailsForGroup:(Group*)group {
    [self setSelectionForGroup:group];
    
    [self displayGroup];
}

- (void)showDetailsForDistributionList:(DistributionListEntity*)distributionList {
    [self setSelectionForDistributionList:distributionList];
    
    [self displayDistributionList];
    return;
}

- (void)showDetailsForWorkContact:(ContactEntity*)contact {
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
        ContactEntity *contact = [self getFirstContact];
        if (contact) {
            [self showDetailsForContact:contact];
            return YES;
        }
    }  else if (_mode == ModeGroups) {
        Group *group = [self getFirstGroup];
        if (group) {
            [self showDetailsForGroup:group];
            return YES;
        }
    } else if (_mode == ModeDistributionLists) {
        DistributionListEntity *distributionList = [self getFirstDistributionList];
        if (distributionList) {
            [self showDetailsForDistributionList:distributionList];
            return YES;
        }
    } else if (_mode == ModeWorkContacts) {
        ContactEntity *contact = [self getFirstWorkContact];
        if (contact) {
            [self showDetailsForWorkContact:contact];
            return YES;
        }
    }
    
    return NO;
}

- (ContactEntity *)getFirstContact {
    if ([self hasContactData]) {
        if ([self.contactsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.contactsDataSource contactAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (Group *)getFirstGroup {
    if ([self hasGroupData]) {
        if ([self.groupsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.groupsDataSource groupAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (DistributionListEntity *)getFirstDistributionList {
    if ([self hasDistributionListData]) {
        if ([self.distributionListTableDataSource tableView:self.tableView numberOfRowsInSection:0] > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            
            return [self.distributionListTableDataSource distributionListAtIndexPath:indexPath];
        }
    }
    
    return nil;
}

- (ContactEntity *)getFirstWorkContact {
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
        Contact *contact = [[Contact alloc] initWithContactEntity:contactForDetails];
        SingleDetailsViewController *singleDetailsViewController = [[SingleDetailsViewController alloc] initFor:contact displayStyle:DetailsDisplayStyleDefault];
        [self showViewController:singleDetailsViewController sender:self];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:[NSDictionary dictionaryWithObject:contactForDetails forKey:kKeyContact]];
    }
}

- (void)displayGroup {
    if (SYSTEM_IS_IPAD == NO) {
        GroupDetailsViewController *groupDetailsViewController = [[GroupDetailsViewController alloc] initFor:groupForDetails displayMode:GroupDetailsDisplayModeDefault displayStyle:DetailsDisplayStyleDefault delegate:nil];
        [self showViewController:groupDetailsViewController sender:self];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowGroup object:nil userInfo:[NSDictionary dictionaryWithObject:groupForDetails forKey:kKeyGroup]];
    }
}

- (void)displayDistributionList{
    if (SYSTEM_IS_IPAD == NO) {
        DistributionListDetailsViewController *groupDetailsViewController = [[DistributionListDetailsViewController alloc] initFor:distributionListForDetails displayMode:DistributionListDetailsDisplayModeDefault displayStyle:DetailsDisplayStyleDefault delegate:nil];
        [self showViewController:groupDetailsViewController sender:self];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowDistributionList object:nil userInfo:[NSDictionary dictionaryWithObject:distributionListForDetails forKey:kKeyDistributionList]];
    }
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

- (BOOL)hasDistributionListData {
    if ([self.distributionListTableDataSource numberOfSectionsInTableView:self.tableView] > 0) {
        NSInteger count = [self.distributionListTableDataSource tableView:self.tableView numberOfRowsInSection:0];
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
    else if (_mode == ModeGroups) {
        return [self.groupsDataSource tableView:self.tableView numberOfRowsInSection:0] > 0;
    }
    else if (_mode == ModeDistributionLists) {
        return [self.distributionListTableDataSource tableView:self.tableView numberOfRowsInSection:0] > 0;
    }
    else if (_mode == ModeWorkContacts) {
        return [self.workContactsDataSource numberOfSectionsInTableView:self.tableView] > 0;
    }
    return FALSE;
}

- (ContactTableDataSource *)contactsDataSource {
    if (_contactsDataSource == nil) {
        _contactsDataSource = [ContactTableDataSource contactTableDataSourceWithFetchedResultsControllerDelegate:self members:nil];
        
        // Make sure sort indices are up to date
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

- (DistributionListTableDataSource *)distributionListTableDataSource {
    if (_distributionListTableDataSource == nil) {
        _distributionListTableDataSource = [DistributionListTableDataSource distributionListTableDataSourceWithFetchedResultsControllerDelegate:self members:nil];
        }
    
    return _distributionListTableDataSource;
}

- (WorkContactTableDataSource *)workContactsDataSource {
    if (_workContactsDataSource == nil) {
        _workContactsDataSource = [WorkContactTableDataSource workContactTableDataSourceWithFetchedResultsControllerDelegate:self members:nil];
        
        // Make sure sort indices are up to date
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
        else if (_mode == ModeGroups) {
            _groupsDataSource = [self groupsDataSource];
            _currentDataSource = _groupsDataSource;
        }
        else if (_mode == ModeDistributionLists) {
            _distributionListTableDataSource = [self distributionListTableDataSource];
            _currentDataSource = _distributionListTableDataSource;
        }
        else if (_mode == ModeWorkContacts) {
            _workContactsDataSource = [self workContactsDataSource];
            _currentDataSource = _workContactsDataSource;
        }
    }
    
    return _currentDataSource;
}

- (void)setFooterView:(BOOL)show {
    [self shouldShowNoContactIndicatorView:NO];

    if (_mode == ModeGroups) {
        _countContactsFooterLabel.text = @"";
        self.tableView.tableFooterView = _countContactsFooterView;
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
            _countContactsFooterLabel.text = @"";
            self.tableView.tableFooterView = _countContactsFooterView;
        }
    }
}

- (void)setRefreshControlTitle:(BOOL)active {
    NSString *refreshText = nil;
    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    if (active) {
        refreshText = [BundleUtil localizedStringForKey:@"synchronizing"];
    } else {
        refreshText = [BundleUtil localizedStringForKey:@"pull_to_sync"];
    }
    NSMutableAttributedString *attributedRefreshText = [[NSMutableAttributedString alloc] initWithString:refreshText attributes:@{ NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.secondaryLabelColor, NSBackgroundColorAttributeName: [UIColor clearColor]}];
    _rfControl.attributedTitle = attributedRefreshText;
}

#pragma mark - Table view

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    [super setEditing:YES animated:YES];
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    [super setEditing:NO animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.currentDataSource numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.currentDataSource tableView:tableView numberOfRowsInSection:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [self.currentDataSource sectionIndexTitlesForTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [self.currentDataSource tableView:tableView sectionForSectionIndexTitle:title atIndex:index];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.currentDataSource tableView:tableView titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
        UITableViewCell *cell;
        
        if (_mode == ModeContacts) {
            cell = [self tableView:tableView contactCellForIndexPath:indexPath];
        }
        else if (_mode == ModeGroups) {
            cell = [self tableView:tableView groupCellForIndexPath:indexPath];
        }
        else if (_mode == ModeDistributionLists){
            cell = [self tableView:tableView distributionListCellForIndexPath:indexPath];
        }
        else if (_mode == ModeWorkContacts) {
            cell = [self tableView:tableView workContactCellForIndexPath:indexPath];
        }
        
        if (_searchController.isActive) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView contactCellForIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ContactCell"];
    cell._contact = [self.contactsDataSource contactAtIndexPath:indexPath];
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
    cell.distributionList = [self.distributionListTableDataSource distributionListAtIndexPath:indexPath];
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
        
        if (_mode == ModeContacts) {
            ContactEntity *contact = [self.contactsDataSource contactAtIndexPath:indexPath];
            [self deleteContact:contact atIndexPath:indexPath];
            [self updateNoContactsView];
        }
        else if (_mode == ModeGroups) {
            Group *group = [self.groupsDataSource groupAtIndexPath:indexPath];
            [self deleteGroup:group atIndexPath:indexPath];
            [self updateNoContactsView];
        }
        else if (_mode == ModeWorkContacts) {
            ContactEntity *contact = [self.workContactsDataSource workContactAtIndexPath:indexPath];
            [self deleteContact:contact atIndexPath:indexPath];
            [self updateNoContactsView];
        }
        else if (_mode == ModeDistributionLists) {
            DistributionListEntity *distributionList = [self.distributionListTableDataSource distributionListAtIndexPath:indexPath];
            [self deleteDistributionList:distributionList atIndexPath:indexPath];
            [self updateNoContactsView];
        }
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    
    UITableViewCell *contextCell = [tableView cellForRowAtIndexPath:indexPath];
    
    if ([contextCell isKindOfClass:[ContactCell class]]) {
        
        // Load contact
        ContactEntity *contact = [self contactAtIndexPath:indexPath];
        if (contact == nil) {
            return nil;
        }
        
        // Load contact details
        Contact *businessContact = [[Contact alloc] initWithContactEntity:contact];
        SingleDetailsViewController *singleDetailsViewController = [[SingleDetailsViewController alloc] initFor:businessContact displayStyle:DetailsDisplayStylePreview];
        
        // Compose actions
        
        NSMutableArray *actionArray = [[NSMutableArray alloc] initWithArray:[singleDetailsViewController uiActionsIn:self]];
        
        NSString *localizedDeleteActionTitle = [BundleUtil localizedStringForKey:@"delete"];
        UIImage *deleteActionImage = [UIImage systemImageNamed:@"trash"];
        UIAction *deleteAction = [UIAction actionWithTitle:localizedDeleteActionTitle image:deleteActionImage identifier:nil handler:^(__unused UIAction * _Nonnull action) {
            [self deleteContact:contact atIndexPath:indexPath];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        [actionArray addObject:deleteAction];
        
        // Create menu
        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable {
            return singleDetailsViewController;
        } actionProvider:^UIMenu * _Nullable (NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            return [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:actionArray];
        }];
        
        return conf;
    }
    else if ([contextCell isKindOfClass:[GroupCell class]]) {
        
        // Load group
        Group *group = [self groupAtIndexPath:indexPath];
        if (group == nil) {
            return nil;
        }
        
        // Load group details
        GroupDetailsViewController *groupDetailsViewController = [[GroupDetailsViewController alloc] initFor:group displayMode:GroupDetailsDisplayModeDefault displayStyle:DetailsDisplayStylePreview delegate:nil];
        
        // Compose actions
        
        NSMutableArray *actionArray = [[NSMutableArray alloc] initWithArray:[groupDetailsViewController uiActionsIn:self]];
        
        NSString *localizedDeleteActionTitle = [BundleUtil localizedStringForKey:@"delete"];
        UIImage *deleteActionImage = [UIImage systemImageNamed:@"trash"];
        UIAction *deleteAction = [UIAction actionWithTitle:localizedDeleteActionTitle image:deleteActionImage identifier:nil handler:^(__unused UIAction * _Nonnull action) {
            [self deleteGroup:group atIndexPath:indexPath];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        [actionArray addObject:deleteAction];
        
        // Create menu
        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable {
            return groupDetailsViewController;
        } actionProvider:^UIMenu * _Nullable (NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
            return [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:actionArray];
        }];
        
        return conf;
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    UIViewController *previewVc = animator.previewViewController;
    if ([previewVc isKindOfClass:[SingleDetailsViewController class]]) {
        contactForDetails = ((SingleDetailsViewController *)previewVc)._contact;
        [animator addCompletion:^{
            [self displayContact];
        }];
    } else if ([previewVc isKindOfClass:[GroupDetailsViewController class]]) {
        groupForDetails = ((GroupDetailsViewController *)previewVc)._group;
        [animator addCompletion:^{
            [self displayGroup];
        }];
    }
    else if ([previewVc isKindOfClass:[DistributionListDetailsViewController class]]) {
        distributionListForDetails = ((DistributionListDetailsViewController *)previewVc)._distributionList;
        [animator addCompletion:^{
            [self displayDistributionList];
        }];
    }
}

- (nullable ContactEntity *)contactAtIndexPath:(NSIndexPath *)indexPath {
    if (_mode == ModeContacts) {
        return [self.contactsDataSource contactAtIndexPath:indexPath];
    } else if (_mode == ModeWorkContacts) {
        return [self.workContactsDataSource workContactAtIndexPath:indexPath];
    }
    
    return nil;
}

- (nullable Group *)groupAtIndexPath:(NSIndexPath *)indexPath {
    if (_mode == ModeGroups) {
        return [self.groupsDataSource groupAtIndexPath:indexPath];
    }
    
    return nil;
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

- (void)deleteGroup:(Group *)group atIndexPath:(nonnull NSIndexPath *)indexPath {
    ConversationEntity *conversation = group.conversation;
    DeleteConversationAction *deleteAction = [DeleteConversationAction deleteActionForConversation:conversation];
    
    UIView *groupCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (groupCell == nil) {
        groupCell = self.view;
    }
    
    deleteAction.presentingViewController = self;
    deleteAction.presentingRect = [groupCell convertRect:groupCell.bounds toView:self.tableView];
    _deleteAction = deleteAction;
    [deleteAction executeOnCompletion:^(BOOL succeeded) {
        [self updateTableViewAfterDeletion:succeeded];
    }];
}

- (void)deleteContact:(nonnull ContactEntity *)contact atIndexPath:(nonnull NSIndexPath *)indexPath {
    DeleteContactAction *deleteContactAction = [[DeleteContactAction alloc] initFor:contact];
    _deleteAction = deleteContactAction;
    
    UIView *contactCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (contactCell == nil) {
        contactCell = self.view;
    }
    
    [deleteContactAction executeIn:contactCell of:self completion:^(BOOL succeeded) {
        [self updateTableViewAfterDeletion:succeeded];
    }];
}

- (void)deleteDistributionList:(nonnull DistributionListEntity *)distributionList atIndexPath:(nonnull NSIndexPath *)indexPath {
    
    NSString *title = [BundleUtil localizedStringForKey:@"distribution_list_delete_sheet_title"];
    NSString *destructiveTitle = [BundleUtil localizedStringForKey:@"Delete"];
    NSString *cancelTitle = [BundleUtil localizedStringForKey:@"cancel"];
    
    [UIAlertTemplate showDestructiveAlertWithOwner:self title:title message:nil titleDestructive:destructiveTitle actionDestructive:^(UIAlertAction * _Nonnull __unused destructiveAction) {
        EntityManager *em = [[EntityManager alloc] init];
        [em performSyncBlockAndSafe:^{
                [[em entityDestroyer] deleteWithDistributionListEntity:distributionList];
        }];
        
    } titleCancel:cancelTitle actionCancel:^(UIAlertAction * _Nonnull __unused cancelAction) {
        // Do nothing and allow casting the vote
    }];
}

- (void) doNothing {
    return;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (_mode == ModeContacts) {
        contactForDetails = [self.contactsDataSource contactAtIndexPath:indexPath];
        [self displayContact];
    }
    else if (_mode == ModeGroups) {
        groupForDetails = [self.groupsDataSource groupAtIndexPath:indexPath];
        [self displayGroup];
    }
    else if (_mode == ModeDistributionLists) {
        distributionListForDetails = [self.distributionListTableDataSource distributionListAtIndexPath:indexPath];
        [self displayDistributionList];
    }
    else if (_mode == ModeWorkContacts) {
        contactForDetails = [self.workContactsDataSource workContactAtIndexPath:indexPath];
        [self displayContact];
    }
}

#pragma mark - Fetched results controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    return;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    return;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    return;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (controller.managedObjectContext.hasChanges) {
        [self updateContactsTimer];
    }
}

- (void)updateContactsTimer {
    [updateContactsTimer invalidate];
    updateContactsTimer = [NSTimer timerWithTimeInterval:0.3 repeats:false block:^(NSTimer * _Nonnull timer) {
        [self updateNoContactsView];
        [self.tableView reloadData];
    }];

    [[NSRunLoop mainRunLoop] addTimer:updateContactsTimer forMode:NSDefaultRunLoopMode];
}


#pragma mark - Search controller delegate

- (void)willPresentSearchController:(UISearchController *)searchController {
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 0.0);
    [self setFooterView:NO];
    _rfControl = self.refreshControl;
    self.refreshControl = nil;
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    self.searchController.searchBar.searchFieldBackgroundPositionAdjustment = UIOffsetMake(0.0, 7.0);
    
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
            self.navigationItem.title = [BundleUtil localizedStringForKey:@"segmentcontrol_contacts"];
            self.refreshControl = _rfControl;
            _currentDataSource = [self contactsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:NO];
            [_workContactsDataSource setIgnoreFRCUpdates:YES];
            [_groupsDataSource setIgnoreFRCUpdates:YES];

            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];

            [self updateNoContactsView];
            self.tableView.tableHeaderView = nil;
            break;
            
        case ModeGroups:
            self.navigationItem.title = [BundleUtil localizedStringForKey:@"segmentcontrol_groups"];
            _rfControl = self.refreshControl;
            self.refreshControl = nil;
            _currentDataSource = [self groupsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:YES];
            [_workContactsDataSource setIgnoreFRCUpdates:YES];
            [_groupsDataSource setIgnoreFRCUpdates:NO];

            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            self.tableView.tableHeaderView = nil;
            [self updateNoContactsView];
            break;
            
        case ModeDistributionLists:
            self.navigationItem.title = [BundleUtil localizedStringForKey:@"segmentcontrol_distribution_list"];
            _rfControl = self.refreshControl;
            _currentDataSource = [self distributionListTableDataSource];
            self.tableView.tableHeaderView = nil;
            [self updateNoContactsView];
            break;
            
        case ModeWorkContacts:
            self.navigationItem.title = [BundleUtil localizedStringForKey:@"segmentcontrol_work_contacts"];
            self.refreshControl = _rfControl;
            _currentDataSource = [self workContactsDataSource];
            [_contactsDataSource setIgnoreFRCUpdates:YES];
            [_workContactsDataSource setIgnoreFRCUpdates:NO];
            [_groupsDataSource setIgnoreFRCUpdates:YES];
            
            [_currentDataSource filterByWords: [self searchWordsForText:_searchController.searchBar.text]];
            if ([UserSettings sharedUserSettings].companyDirectory == true) {
                self.tableView.tableHeaderView = _companyDirectoryCellView;
                [[_companyDirectoryCellView.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor] setActive:true];
            }
            else {
                self.tableView.tableHeaderView = nil;
            }
            
            [self updateNoContactsView];
            break;
            
        default:
            break;
    }
    
    [self.tableView reloadData];
        
    if ([self hasData]) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
    }
}

- (IBAction)addAction:(id)sender {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    
    if (_mode == ModeContacts || _mode == ModeWorkContacts) {
        if ([mdmSetup disableAddContact]) {
            [UIAlertTemplate showAlertWithOwner:self title:@"" message:[BundleUtil localizedStringForKey:@"disabled_by_device_policy"] actionOk:nil];
            return;
        }
        UIStoryboard *storyboard = self.storyboard;
        UINavigationController *navVC = [storyboard instantiateViewControllerWithIdentifier:@"AddContactNavigationController"];
        
        [self presentViewController:navVC animated:YES completion:nil];
    } else if (_mode == ModeGroups) {
        if ([mdmSetup disableCreateGroup]) {
            [UIAlertTemplate showAlertWithOwner:self title:@"" message:[BundleUtil localizedStringForKey:@"disabled_by_device_policy"] actionOk:nil];
            return;
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateGroup" bundle:nil];
        UINavigationController *navVC = [storyboard instantiateInitialViewController];
        
        [self presentViewController:navVC animated:YES completion:nil];
    }
    else if (_mode == ModeDistributionLists){
        UIViewController* createDistList = [[DistributionListCreateEditViewController alloc]init];
        UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:createDistList];
        [self presentViewController:navVC animated:YES completion:nil];
    }
}

- (IBAction)pulledForRefresh:(UIRefreshControl *)sender {
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
    
    if ((_mode == ModeContacts || _mode == ModeWorkContacts) && !self.searchController.active) {
        [self setRefreshControlTitle:YES];
        _segmentedControl.userInteractionEnabled = NO;
        
        [[GatewayAvatarMaker gatewayAvatarMaker] refreshForced];
        
        if ([UserSettings sharedUserSettings].syncContacts) {
            [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES ignoreMinimumInterval:YES onCompletion:^(BOOL addressBookAccessGranted) {
                [self updateWorkDataAndEndRefreshing:sender];
                if (!addressBookAccessGranted) {
                    // Show access prompt
                    [UIAlertTemplate showOpenSettingsAlertWithOwner:self noAccessAlertType:NoAccessAlertTypeContacts];
                }
            } onError:^(NSError *error) {
                if (error.code == 429) {
                    [self show429ErrorMessage: sender];
                }
                else {
                    [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:^(UIAlertAction * _Nonnull okAction) {
                        [self updateWorkDataAndEndRefreshing:sender];
                    }];
                }
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

- (void)show429ErrorMessage:(UIRefreshControl *)sender {
    if (TargetManagerObjc.isBusinessApp) {
        NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"pull_to_sync_429_message_work"], TargetManagerObjc.appName];
        [UIAlertTemplate showAlertWithOwner:self title:nil message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
            [self updateWorkDataAndEndRefreshing:sender];
        }];
    }
    else {
        NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"pull_to_sync_429_message"], TargetManagerObjc.appName];
        [UIAlertTemplate showAlertWithOwner:self title:nil message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
            [self updateWorkDataAndEndRefreshing:sender];
        }];
    }
}

- (void)updateWorkDataAndEndRefreshing:(UIRefreshControl*)rfSender {
    [[AppDelegate sharedAppDelegate] setIsWorkContactsLoading:true];
    [WorkDataFetcher checkUpdateWorkDataForce:YES sendForce:YES onCompletion:^{
        [[AppDelegate sharedAppDelegate] setIsWorkContactsLoading:false];
        [self endRefreshingAndScrollUp:rfSender];
    } onError:^(NSError *error) {
        [[AppDelegate sharedAppDelegate] setIsWorkContactsLoading:false];
        [self endRefreshingAndScrollUp:rfSender];
        if (error.code == 401 || error.code == 409) {
            [[NotificationPresenterWrapper shared] presentUpdateWorkDataError];
        }
        else {
            [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }
        DDLogError(@"[UpdateWorkData] Update work data failed: %@)", error.localizedDescription);
    }];
}

- (void)endRefreshingAndScrollUp:(UIRefreshControl*)rfSender {
    [self setRefreshControlTitle:NO];
    self.segmentedControl.userInteractionEnabled = YES;
    [rfSender endRefreshing];
    [self.rfControl endRefreshing];
    
    if ([self.tableView numberOfSections] > 0 && [self.tableView numberOfRowsInSection:0] > 0)
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionNone animated:YES];
}

- (void)companyDirectoryTapped:(UITapGestureRecognizer *)recognizer {
    ThemedTableViewController *companyDirectoryViewController = (ThemedTableViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"CompanyDirectoryViewController"];
    
    ModalNavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:companyDirectoryViewController];
    nav.showDoneButton = true;
    nav.showFullScreenOnIPad = false;
    
    [self presentViewController:nav animated:YES completion:nil];

}

#pragma mark - UIViewControllerPreviewingDelegate

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
        
    NSIndexPath *indexPathOfForceTouchedCell = [self.tableView indexPathForRowAtPoint:location];
    if (indexPathOfForceTouchedCell == nil) {
        return nil;
    }
    
    UITableViewCell *forceTouchedCell = [self.tableView cellForRowAtIndexPath:indexPathOfForceTouchedCell];
    
    previewingContext.sourceRect = forceTouchedCell.frame;
    
    if ([forceTouchedCell isKindOfClass:[ContactCell class]]) {
        
        ContactEntity *contact = [self contactAtIndexPath:indexPathOfForceTouchedCell];
        if (contact == nil) {
            return nil;
        }
        Contact *businessContact = [[Contact alloc] initWithContactEntity:contact];
        SingleDetailsViewController *singleDetailsViewController = [[SingleDetailsViewController alloc] initFor:businessContact displayStyle:DetailsDisplayStylePreview];

        return singleDetailsViewController;
        
    } else if ([forceTouchedCell isKindOfClass:[GroupCell class]]) {
        
        Group *group = [self groupAtIndexPath:indexPathOfForceTouchedCell];
        if (group == nil) {
            return nil;
        }
        
        GroupDetailsViewController *groupDetailsViewController = [[GroupDetailsViewController alloc] initFor:group displayMode:GroupDetailsDisplayModeDefault displayStyle:DetailsDisplayStylePreview delegate:nil];
        
        return groupDetailsViewController;
    }

    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    if ([viewControllerToCommit isKindOfClass:[SingleDetailsViewController class]]) {
        contactForDetails = ((SingleDetailsViewController *)viewControllerToCommit)._contact;
        [self displayContact];
    } else if ([viewControllerToCommit isKindOfClass:[GroupDetailsViewController class]]) {
        groupForDetails = ((GroupDetailsViewController *)viewControllerToCommit)._group;
        [self displayGroup];
    }
}

#pragma mark - Notifications

- (void)refreshWorkContactTableView:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refresh];
        self.tableView.tableHeaderView = [UserSettings sharedUserSettings].companyDirectory == true ? _companyDirectoryCellView : nil;
    });
}

- (void)refreshContactSortIndices:(NSNotification *)notification {
    if (_contactsDataSource != nil) {
        [_contactsDataSource refreshContactSortIndices];
    }
    if (_workContactsDataSource != nil) {
        [_workContactsDataSource refreshWorkContactSortIndices];
    }
}

- (void)refreshDirtyObjects:(NSNotification*)notification {
    NSManagedObjectID *objectID = [notification.userInfo objectForKey:kKeyObjectID];
    if (objectID == nil) {
        [self resetData];
    }
}

- (void)loadingWorkContacts:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateNoContactsView];
    });
}

@end
