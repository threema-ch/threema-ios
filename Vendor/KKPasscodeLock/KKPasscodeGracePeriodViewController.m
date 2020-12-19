//
//  KKPasscodeGracePeriodViewController.m
//  Threema
//
//  Copyright (c) 2012 Threema GmbH. All rights reserved.
//

#import "KKPasscodeGracePeriodViewController.h"
#import "KKPasscodeSettingsViewController.h"
#import "KKKeychain.h"
#import "KKPasscodeLock.h"
#import "BundleUtil.h"

@interface KKPasscodeGracePeriodViewController ()

@end

@implementation KKPasscodeGracePeriodViewController {
    int _gracePeriod;
    NSIndexPath *selectedIndexPath;
}

static int gracePeriods[] = {0, 60, 300, 900, 3600, 14400};

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = KKPasscodeLockLocalizedString(@"Require Passcode", @"");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _gracePeriod = [[KKKeychain getStringForKey:@"grace_period"] intValue];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return sizeof(gracePeriods) / sizeof(int);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"GracePeriodCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    
    cell.textLabel.text = [KKPasscodeSettingsViewController textForGracePeriod:gracePeriods[indexPath.row] shortForm:NO];
    
    if (gracePeriods[indexPath.row] == _gracePeriod) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        selectedIndexPath = indexPath;
    } else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _gracePeriod = gracePeriods[indexPath.row];
    [KKKeychain setString:[NSString stringWithFormat:@"%d", _gracePeriod] forKey:@"grace_period"];
    
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
}

@end
