//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2020 Threema GmbH
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

#import "VoIPSoundViewController.h"
#import "VoIPSounds.h"
#import "UserSettings.h"
#import "BundleUtil.h"

#import <AVFoundation/AVFoundation.h>

@interface VoIPSoundViewController ()

@end

@implementation VoIPSoundViewController {
    NSArray *voIPSounds;
    NSIndexPath *selectedIndexPath;
    AVAudioPlayer *_audioPlayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    voIPSounds = [VoIPSounds getVoIPSounds];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_audioPlayer stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)playVoIPSound:(NSString*)voIPSoundName {
    if ([voIPSoundName isEqualToString:@"default"]) {
        return;
    }
    
    NSString *soundPath = [BundleUtil pathForResource:voIPSoundName ofType:@"caf"];
    NSURL *soundUrl = [NSURL fileURLWithPath:soundPath];
    
    if (_audioPlayer) {
        if ([_audioPlayer.url isEqual:soundUrl]) {
            if (_audioPlayer.isPlaying) {
                [_audioPlayer stop];
            } else {
                _audioPlayer.currentTime = 0;
                [_audioPlayer play];
            }
            return;
        }
        [_audioPlayer stop];
        _audioPlayer = nil;
    }
    
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundUrl error:nil];
    _audioPlayer.numberOfLoops = 2;
    [_audioPlayer play];
}

- (NSString*)currentVoIPSound {
    return [UserSettings sharedUserSettings].voIPSound;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return voIPSounds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SoundCell"];
    
    NSString *soundName = voIPSounds[indexPath.row];
    NSString *soundNameLoc = [NSString stringWithFormat:@"sound_%@", soundName];
    cell.textLabel.text = NSLocalizedString(soundNameLoc, nil);
    
    if ([self.currentVoIPSound isEqualToString:soundName]) {
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
    [UserSettings sharedUserSettings].voIPSound = voIPSounds[indexPath.row];
//    [[CallManager sharedInstance] createNewProvider];
    
    [self playVoIPSound:voIPSounds[indexPath.row]];
    
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
}


#pragma mark - Notifications

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if (_audioPlayer) {
        [_audioPlayer stop];
    };
}

@end
