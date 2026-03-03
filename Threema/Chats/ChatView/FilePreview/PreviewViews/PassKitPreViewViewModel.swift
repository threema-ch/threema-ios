//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import PassKit
import ThreemaFramework

@MainActor
final class PassKitPreviewViewModel: ObservableObject {
    @Published private(set) var pkPass: PKPass?
    @Published private(set) var hasFailed = false
    
    let fileMessageEntity: FileMessageEntity
    
    var shouldShowPass: Bool {
        pkPass != nil
    }
    
    var shouldShowFailure: Bool {
        hasFailed
    }
    
    init(fileMessageEntity: FileMessageEntity) {
        self.fileMessageEntity = fileMessageEntity
    }
    
    func loadPass() {
        guard let passData = fileMessageEntity.data?.data else {
            hasFailed = true
            return
        }
        
        do {
            pkPass = try PKPass(data: passData)
        }
        catch {
            hasFailed = true
        }
    }
}
