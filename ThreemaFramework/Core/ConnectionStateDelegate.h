//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2022 Threema GmbH
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

typedef NS_CLOSED_ENUM(NSInteger, ConnectionState) {
    ConnectionStateDisconnected = 1,
    ConnectionStateConnecting,
    ConnectionStateConnected,
    ConnectionStateLoggedIn,
    ConnectionStateDisconnecting
};

@protocol ConnectionStateDelegate <NSObject>

/**
 Will be called when sever connection state has changed.

 @param state: Current connection state
 */
- (void)connectionStateChanged:(ConnectionState)state
    NS_SWIFT_NAME(changed(connectionState:));

@end
