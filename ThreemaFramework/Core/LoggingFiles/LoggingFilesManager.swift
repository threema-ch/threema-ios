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

import FileUtility
import Foundation

public final class LoggingFilesManager: LoggingFilesManagerProtocol {
    private let fileUtility: FileUtilityProtocol

    public init(fileUtility: FileUtilityProtocol) {
        self.fileUtility = fileUtility
    }

    // MARK: - LoggingFilesManagerProtocol

    public func logDirectoriesAndFiles() {
        let urls = [
            fileUtility.appDataDirectory(appGroupID: AppGroup.groupID()),
            fileUtility.appDocumentsDirectory,
            fileUtility.appCachesDirectory,
            FileManager.default.temporaryDirectory,
        ].compactMap { $0 }

        urls.forEach { fileUtility.logDirectoriesAndFiles(pathURL: $0) }
    }
}
