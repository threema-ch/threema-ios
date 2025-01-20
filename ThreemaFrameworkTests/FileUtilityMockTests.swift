//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class FileUtilityTests: XCTestCase {
    
    var fileUtility: FileUtilityMock!
    
    override func setUpWithError() throws {
        super.setUp()
        fileUtility = FileUtilityMock()
    }
    
    func testAppDataDirectory() {
        XCTAssertNotNil(fileUtility.appDataDirectory, "appDataDirectory should not be nil")
    }
    
    func testAppDocumentsDirectory() {
        XCTAssertNotNil(fileUtility.appDocumentsDirectory, "appDocumentsDirectory should not be nil")
    }
    
    func testAppCachesDirectory() {
        XCTAssertNotNil(fileUtility.appCachesDirectory, "appCachesDirectory should not be nil")
    }
    
    func testAppTemporaryDirectory() {
        let tempDirectory = fileUtility.appTemporaryDirectory
        XCTAssertNotNil(tempDirectory, "appTemporaryDirectory should not be nil")
    }
    
    func testMkDir() {
        let newDir = fileUtility.appTemporaryDirectory.appendingPathComponent("TestDir")
        XCTAssertTrue(fileUtility.mkDir(at: newDir), "Directory should be created successfully")
        // Cleanup after test
        fileUtility.delete(at: newDir)
    }
    
    func testDir() {
        let contents = fileUtility.dir(pathURL: fileUtility.appTemporaryDirectory)
        XCTAssertNotNil(contents, "Directory contents should be retrievable")
    }
    
    func testLogDirectoriesAndFiles() {
        let logPath = fileUtility.appDocumentsDirectory!.appendingPathComponent("log.txt")
        fileUtility.logDirectoriesAndFiles(path: fileUtility.appTemporaryDirectory, logFileName: "log.txt")
        XCTAssertTrue(fileUtility.isExists(fileURL: logPath), "Log file should exist after logging")
        // Cleanup after test
        fileUtility.delete(at: logPath)
    }
    
    func testCleanTemporaryDirectory() {
        let oldFile = fileUtility.appTemporaryDirectory.appendingPathComponent("old_file.txt")
        let written = fileUtility.write(fileURL: oldFile, text: "test")
        XCTAssertTrue(written, "File should be written successfully")
        fileUtility.cleanTemporaryDirectory(olderThan: Date())
        XCTAssertFalse(fileUtility.isExists(fileURL: oldFile), "Old file should be cleaned up")
    }
    
    func testRemoveItemsInAllDirectories() {
        fileUtility.removeItemsInAllDirectories()
        // Assert expectations after operation.
    }
    
    func testWriteAndReadFile() {
        let testFile = fileUtility.appTemporaryDirectory.appendingPathComponent("test.txt")
        let testData = "Test data".data(using: .utf8)!
        XCTAssertTrue(
            fileUtility.write(fileURL: testFile, contents: testData),
            "File should be written successfully"
        )
        let readData = fileUtility.read(fileURL: testFile)
        XCTAssertEqual(readData, testData, "Read data should match written data")
        // Cleanup after test
        fileUtility.delete(at: testFile)
    }
    
    func testMoveFile() {
        let testFile = fileUtility.appTemporaryDirectory.appendingPathComponent("test.txt")
        let testData = "Test data".data(using: .utf8)!
        XCTAssertTrue(
            fileUtility.write(fileURL: testFile, contents: testData),
            "File should be written successfully"
        )
        let destination = fileUtility.appDocumentsDirectory!.appendingPathComponent(testFile.lastPathComponent)
        let readData = fileUtility.read(fileURL: testFile)
        let moveResult = fileUtility.move(source: testFile, destination: destination)
        let readDataDestination = fileUtility.read(fileURL: destination)
        XCTAssertTrue(moveResult, "File should be moved successfully")
        XCTAssertEqual(readData, readDataDestination, "Read data should match written data")
        let testFileMoved = !fileUtility.isExists(fileURL: testFile) && fileUtility
            .isExists(fileURL: destination)
        XCTAssertTrue(testFileMoved, "File should be moved successfully")
        // Cleanup after test
        fileUtility.delete(at: destination)
    }
    
    func testCopyFile() {
        let testFile = fileUtility.appTemporaryDirectory.appendingPathComponent("test.txt")
        let testData = "Test data".data(using: .utf8)!
        XCTAssertTrue(
            fileUtility.write(fileURL: testFile, contents: testData),
            "File should be written successfully"
        )
        
        let destination = fileUtility.appDocumentsDirectory!.appendingPathComponent(testFile.lastPathComponent)
        let copyResult = fileUtility.copy(source: testFile, destination: destination)
        XCTAssertTrue(copyResult, "File should be copied successfully")
        let readData = fileUtility.read(fileURL: destination)
        XCTAssertEqual(readData, testData, "Read data should match written data")
        // Cleanup after test
        fileUtility.delete(at: testFile)
        fileUtility.delete(at: destination)
    }
    
    func testDeleteFile() {
        let testFile = fileUtility.appTemporaryDirectory.appendingPathComponent("deleteMe.txt")
        let written = fileUtility.write(fileURL: testFile, text: "Delete this file")
        XCTAssertTrue(written, "File should be written successfully")
        fileUtility.delete(at: testFile)
        XCTAssertFalse(fileUtility.isExists(fileURL: testFile), "File should be deleted successfully")
    }
}
