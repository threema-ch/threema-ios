//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import <Foundation/Foundation.h>

/// Defines endpoint of upload/download blob resource.
///
/// Blob origin logic for file (group) messages (request:origin), if Multi Device activated:
///
/// ```
/// Device Group A                    | |                    Device Group B
/// ----------------------------------| |----------------------------------
/// File message                      | |
///        ┌────────┐ upload:public   | | download:public ┌────────┐
/// Leader │Device 1│––––––––––––––––→| |←–––––––––––––––→│Device 1│ Leader
///        └────────┘                 | | done:public     └────────┘
///                                   | |
///        ┌────────┐ download:local  |B| download:public ┌────────┐
///        │Device 2│←–––––––––––––––→|L|←–––––––––––––––→│Device 2│
///        └────────┘ done:local      |O| done:public     └────────┘
///                                   |B|
/// ----------------------------------| |----------------------------------
/// Group file message                |M|
///        ┌────────┐ upload:public * |I| download:public ┌────────┐
/// Leader │Device 1│––––––––––––––––→|R|←–––––––––––––––→│Device 1│ Leader
///        └────────┘                 |R| done:local      └────────┘
///                                   |O|
///        ┌────────┐ download:local  |R| download:public ┌────────┐
///        │Device 2│←–––––––––––––––→| |←–––––––––––––––→│Device 2│
///        └────────┘ done:local      | | done:local      └────────┘
///                                   | |
/// ```
/// * If group is a note group, we upload with origin local, since we are the only ones that download the blob anyways.
///
/// The origin of deprecated message types, `AudioMessageEntity`, `ImageMessageEntity` and `VideoMessageEntity`
/// are always `public`, because they will never be reflected as outgoing message! In new version this types will
/// send/reflected as `FileMessageEntity`.
typedef NS_ENUM(NSInteger, BlobOrigin) {
    BlobOriginPublic = 0,
    BlobOriginLocal = 1,
};
