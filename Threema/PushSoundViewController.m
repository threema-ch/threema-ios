//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
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

#import "PushSoundViewController.h"
#import "PushSounds.h"
#import "UserSettings.h"
#import "BundleUtil.h"

#import <AudioToolbox/AudioToolbox.h>

@interface PushSoundViewController ()

@end

@implementation PushSoundViewController {
    NSArray *pushSounds;
    NSIndexPath *selectedIndexPath;
}

@synthesize group;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    pushSounds = [PushSounds getPushSounds];    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

static void soundCompletionCallback(SystemSoundID soundId, void *arg) {
    
    AudioServicesRemoveSystemSoundCompletion(soundId);
    AudioServicesDisposeSystemSoundID(soundId);
}

- (void)playPushSound:(NSString*)pushSoundName {
    if ([pushSoundName isEqualToString:@"none"])
        return;
    
    if ([pushSoundName isEqualToString:@"default"]) {
        AudioServicesPlayAlertSound(1007);
        return;
    }
    
    NSString *soundPath = [BundleUtil pathForResource:pushSoundName ofType:@"caf"];
    CFURLRef soundUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:soundPath];
    SystemSoundID soundId;
    AudioServicesCreateSystemSoundID(soundUrl, &soundId);
    AudioServicesAddSystemSoundCompletion(soundId, NULL, NULL, soundCompletionCallback, NULL);
    AudioServicesPlayAlertSound(soundId);
}

- (NSString*)currentPushSound {
    if (group)
        return [UserSettings sharedUserSettings].pushGroupSound;
    else
        return [UserSettings sharedUserSettings].pushSound;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return pushSounds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SoundCell"];
    
    NSString *soundName = pushSounds[indexPath.row];
    NSString *soundNameLoc = [NSString stringWithFormat:@"sound_%@", soundName];
    cell.textLabel.text = NSLocalizedString(soundNameLoc, nil);
    
    if ([self.currentPushSound isEqualToString:soundName]) {
        selectedIndexPath = indexPath;
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (group)
        [UserSettings sharedUserSettings].pushGroupSound = pushSounds[indexPath.row];
    else
        [UserSettings sharedUserSettings].pushSound = pushSounds[indexPath.row];
    
    [self playPushSound:pushSounds[indexPath.row]];
    
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
}

@end
