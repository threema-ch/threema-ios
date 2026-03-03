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

import Combine
import FileUtility
import ThreemaFramework
import ThreemaMacros

@MainActor
final class QuickLookPreviewViewModel: ObservableObject {
    @Published private(set) var tempFileURL: URL?
    
    let fileMessageEntity: FileMessageEntity
    
    var shouldShowPreview: Bool {
        tempFileURL != nil
    }
    
    private(set) var doneButtonTitle = #localize("Done")
    
    let fileUtility: FileUtilityProtocol
    
    init(
        fileMessageEntity: FileMessageEntity,
        fileUtility: FileUtilityProtocol = FileUtility.shared
    ) {
        self.fileMessageEntity = fileMessageEntity
        self.fileUtility = fileUtility
    }
    
    func load() {
        prepareFile()
    }
    
    func onDisappear() {
        cleanupTempFile()
    }
    
    private func prepareFile() {
        let filename = fileUtility.getTemporarySendableFileName(base: "file")
        let tmpURL = fileMessageEntity.tempFileURL(fallBackFileName: filename)
        
        fileMessageEntity.exportData(to: tmpURL)
        tempFileURL = tmpURL
    }
    
    private func cleanupTempFile() {
        guard let url = tempFileURL else {
            return
        }
        
        do {
            try fileUtility.delete(at: url)
            tempFileURL = nil
        }
        catch {
            print("Failed to cleanup temp file: \(error)")
        }
    }
}
