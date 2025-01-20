//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import Foundation

struct RendezvousEmoji: Hashable {
    let codepoints: [String]
    
    var localizedString: String {
        "md_device_join_emoji.\(codepoints.joined(separator: "_"))" // md_device_join_emoji.1F408_200D_2B1B
    }
    
    var imageName: String {
        "emoji_\(codepoints.joined(separator: "_"))" // emoji_1F3D5_FE0F
    }
}

// MARK: - Identifiable, Equatable

extension RendezvousEmoji: Identifiable, Equatable {
    typealias ID = String
    
    var id: String {
        codepoints.joined(separator: "_")
    }
}

enum RendezvousEmojis: Equatable {
    private static let numberOfEmojis: UInt8 = 128
    private static let emojiList = [
        ["1F435"],
        ["1F436"],
        ["1F429"],
        ["1F98A"],
        ["1F408", "200D", "2B1B"],
        ["1F434"],
        ["1F9AC"],
        ["1F42E"],
        ["1F437"],
        ["1F42A"],
        ["1F992"],
        ["1F418"],
        ["1F42D"],
        ["1F430"],
        ["1F43F", "FE0F"],
        ["1F43C"],
        ["1F998"],
        ["1F414"],
        ["1F54A", "FE0F"],
        ["1F986"],
        ["1F9A2"],
        ["1F989"],
        ["1F9A4"],
        ["1FAB6"],
        ["1F9A9"],
        ["1F438"],
        ["1F40B"],
        ["1F42C"],
        ["1F9AD"],
        ["1F41F"],
        ["1F41A"],
        ["1FAB2"],
        ["1F578", "FE0F"],
        ["1F3F5", "FE0F"],
        ["1F33B"],
        ["1F332"],
        ["1F33F"],
        ["2618", "FE0F"],
        ["1F349"],
        ["1F34B"],
        ["1F34E"],
        ["1F352"],
        ["1F353"],
        ["1FAD0"],
        ["1F345"],
        ["1F951"],
        ["1F955"],
        ["1F966"],
        ["1F344"],
        ["1FAD8"],
        ["1F9C2"],
        ["1F36A"],
        ["1F36B"],
        ["2615"],
        ["1F9CA"],
        ["1F962"],
        ["1F5FA", "FE0F"],
        ["1F30B"],
        ["1F3D5", "FE0F"],
        ["1F3DD", "FE0F"],
        ["1F3DB", "FE0F"],
        ["1F682"],
        ["1F69A"],
        ["1F69C"],
        ["1F6E4", "FE0F"],
        ["2693"],
        ["1F6F0", "FE0F"],
        ["1F680"],
        ["1F319"],
        ["2600", "FE0F"],
        ["2B50"],
        ["1F308"],
        ["2602", "FE0F"],
        ["2744", "FE0F"],
        ["2603", "FE0F"],
        ["1F525"],
        ["1F4A7"],
        ["2728"],
        ["1F388"],
        ["1F380"],
        ["1F947"],
        ["1F3C0"],
        ["1F3D0"],
        ["1F3B3"],
        ["1F3D3"],
        ["26F3"],
        ["1F3AF"],
        ["1F579", "FE0F"],
        ["1F9E9"],
        ["1F9F8"],
        ["2660", "FE0F"],
        ["2665", "FE0F"],
        ["1F457"],
        ["1F451"],
        ["1F514"],
        ["1F3B7"],
        ["1F3B8"],
        ["1F5A8", "FE0F"],
        ["1F4F8"],
        ["1F56F", "FE0F"],
        ["1F4D6"],
        ["1F4E6"],
        ["1F4EE"],
        ["1F4DD"],
        ["1F4BC"],
        ["1F4CB"],
        ["1F512"],
        ["1F511"],
        ["2692", "FE0F"],
        ["1FA83"],
        ["2696", "FE0F"],
        ["1F517"],
        ["1FA9D"],
        ["1F52C"],
        ["1FA91"],
        ["1F6BD"],
        ["1F9F9"],
        ["1FAA3"],
        ["1FAE7"],
        ["26AB"],
        ["1F7E8"],
        ["25B6", "FE0F"],
        ["1F4F6"],
        ["1F4A5"],
        ["1F4AC"],
        ["1F4AB"],
        ["1F440"],
        ["1F463"],
    ]

    private static func emojis(for rendezvousPathHash: Data) -> Set {
        let emoji1Index = Int(rendezvousPathHash[0] % numberOfEmojis)
        let emoji2Index = Int(rendezvousPathHash[1] % numberOfEmojis)
        let emoji3Index = Int(rendezvousPathHash[2] % numberOfEmojis)
        
        let emoji1 = RendezvousEmoji(codepoints: emojiList[emoji1Index])
        let emoji2 = RendezvousEmoji(codepoints: emojiList[emoji2Index])
        let emoji3 = RendezvousEmoji(codepoints: emojiList[emoji3Index])
        
        return Set(
            emojis: [
                emoji1,
                emoji2,
                emoji3,
            ],
            fromRendezvousPathHash: true
        )
    }
    
    private static func randomEmojis() -> Set {
        Set(
            emojis: [
                RendezvousEmoji(codepoints: emojiList.randomElement()!),
                RendezvousEmoji(codepoints: emojiList.randomElement()!),
                RendezvousEmoji(codepoints: emojiList.randomElement()!),
            ],
            fromRendezvousPathHash: false
        )
    }
    
    struct Set: Hashable, Identifiable, Equatable {
        var id: [RendezvousEmoji] {
            emojis
        }
        
        let emojis: [RendezvousEmoji]
        let fromRendezvousPathHash: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(emojis)
        }
    }
    
    static func emojiSets(for rendezvousPathHash: Data) -> [Set] {
        var set = Swift.Set<Set>()
        
        let rendezvousSet = emojis(for: rendezvousPathHash)
        set.insert(rendezvousSet)
        
        while set.count < 3 {
            set.insert(randomEmojis())
        }
        
        return set.shuffled()
    }
}
