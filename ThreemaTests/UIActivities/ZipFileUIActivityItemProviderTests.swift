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

import Testing
@testable import Threema

@Suite @MainActor struct ZipFileUIActivityItemProviderTests {

    @Test("Processing of a ZipFileUIActivityItemProvider")
    func zip() throws {

        // ARRANGE
        let url = anyURL()
        let sut = ZipFileUIActivityItemProvider(url: url, subject: "Subject")
        let vc = UIActivityViewController(activityItems: [], applicationActivities: [])

        // ACT
        let subject = sut.activityViewController(vc, subjectForActivityType: nil)
        let identifier = sut.activityViewController(vc, dataTypeIdentifierForActivityType: nil)

        // ASSERT
        #expect((sut.item as? URL) == url)
        #expect(subject == "Subject")
        #expect(identifier == "com.pkware.zip-archive")
    }

    // MARK: Helpers

    private func anyURL() -> URL {
        URL(string: "https://www.abc.com")!
    }
}
