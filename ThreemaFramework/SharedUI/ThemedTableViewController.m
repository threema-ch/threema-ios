#import "ThemedTableViewController.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@interface ThemedTableViewController ()

@end

@implementation ThemedTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self updateColors];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDynamicTypeChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    if (self.tableView.style == UITableViewStyleGrouped) {
        self.tableView.estimatedSectionHeaderHeight = 38;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.view.backgroundColor = Colors.backgroundView;
    
    if (self.tableView.style == UITableViewStyleInsetGrouped) {
        self.view.backgroundColor = Colors.backgroundView;
    }
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refresh {
    [self updateColors];
    
    [self.tableView reloadData];
}

- (void)updateColors {        
    [Colors updateWithTableView:self.tableView];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {    
    if ([cell respondsToSelector:@selector(updateColors)]) {
        [cell performSelector:@selector(updateColors)];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)handleDynamicTypeChange:(NSNotification *)theNotification {
    [self refresh];
}

@end
