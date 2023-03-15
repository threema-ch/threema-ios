//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

// swiftformat:disable blankLinesAroundMark

import UniformTypeIdentifiers
import XCTest

class MakeScreenshots: XCTestCase {
    
    enum ThreemaApp {
        case threema
        case work
        case onPrem
    }
    
    var language = ""
    var theme = "light"
    var version = "5.0"
    var orientation = ""
    var screenshotNameStart = ""
    var screenshotNameEnd = ""
    var app: XCUIApplication?
    var threemaApp: ThreemaApp = .threema
    static var waitForAnimations = true
    
    override func setUp() {
        app = XCUIApplication()
        language = languageCode()
        
        app?.launchArguments = ["-isRunningForScreenshots"]

        if UIScreen.main.traitCollection.horizontalSizeClass == .regular {
            orientation = "landscape"
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        else {
            orientation = "portrait"
            XCUIDevice.shared.orientation = .portrait
        }
        continueAfterFailure = false
        
        app!.launch()
        
        let ios = "ios-\(ProcessInfo().environment["SIMULATOR_DEVICE_NAME"]!)"
        
        screenshotNameStart = "\(ios)-\(version)-\(language)"
        screenshotNameEnd = "\(theme)-\(orientation)"
                                
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert -> Bool in
            
            switch alert.buttons.count {
            case 2:
                if alert.description.contains("Apple") {
                    alert.buttons.element(boundBy: 0).tap()
                }
                else {
                    alert.buttons.element(boundBy: 1).tap()
                }
                return true
            case 3:
                alert.buttons.element(boundBy: 1).tap()
                return true
            default:
                return false
            }
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testMakeScreenshots() {
        app = XCUIApplication()
                                
        if Bundle.main.bundleIdentifier == "ch.threema.ScreenshotsWithDataWork.xctrunner" {
            threemaApp = .work
        }
        else if Bundle.main.bundleIdentifier == "ch.threema.ScreenshotsWithDataOnPrem.xctrunner" {
            threemaApp = .onPrem
        }
              
        // MARK: Enter license key
        if threemaApp == .work || threemaApp == .onPrem,
           // swiftformat:disable:next isEmpty
           app!.textFields.count > 0 {
            let login = appLogin()
            
            app!.textFields["licenseUsername"].typeText(login!["username"]!)
            if app!.keys.allElementsBoundByIndex[0].exists {
                app!.typeText("\n")
            }
            app!.secureTextFields["licensePassword"].typeText(login!["password"]!)
            app!.buttons["ConfirmButton"].tap()
            
            sleep(5)
        }
                
        let contactTabBarItem = app!.tabBars["TabBar"].buttons["TabBarContacts"]
        let messagesTabBarItem = app!.tabBars["TabBar"].buttons["TabBarChats"]
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
                        
        if UIDevice.current.userInterfaceIdiom == .pad {
            screenshotsForIpads()
        }
        else {
            screenshotsForIphones()
        }
    }
    
    private func appLogin() -> [String: String]? {
        
        // get screenshot project directory for work login
        guard let srcroot: String = ProcessInfo.processInfo.environment["SRCROOT"] else {
            assertionFailure("Can't find environment variable ro SRCROOT")
            return nil
        }
                
        let screenshotProject = threemaApp == .work ? "screenshot/chat_data/work" : "screenshot/chat_data/onPrem"
        let screenshotPath = srcroot.replacingOccurrences(of: "ios-client", with: screenshotProject)
        
        let bundle = Bundle(path: screenshotPath)
        let loginJsonPath = bundle?.path(forResource: "login.json", ofType: nil)
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: loginJsonPath!),
              let loginJsonData = fileManager.contents(atPath: loginJsonPath!) else {
            assertionFailure("Can't find login.json")
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: loginJsonData, options: []) as? [String: String]
        }
        catch {
            assertionFailure("Can't create jsonObject from login.json")
            return nil
        }
    }
                
    private func screenshotsForIphones() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIDTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
        
        // MARK: Screenshot 1: conversations
        takeScreenshot(number: "01", name: "conversations")
        
        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        takeScreenshot(number: "02", name: "contacts")
        
        // Switch to Chats
        messagesTabBarItem.tap()
        
        switch threemaApp {
        case .threema:
            // open chat of hanna schmidt
            app!.tables.cells.element(boundBy: 0).tap()
        case .work:
            // open chat of peter schreiner
            app!.tables.cells.element(boundBy: 0).tap()
        case .onPrem:
            // open chat of peter schreiner
            app!.tables.cells.element(boundBy: 0).tap()
        }
        
        // MARK: Screenshot 3: single_chat
        takeScreenshot(number: "03", name: "single_chat")
        
        // tap plus icon
        app!.buttons["ChatBarViewImageButton"].tap()
        
        // MARK: Screenshot 4: single_chat_attachments
        takeScreenshot(number: "04", name: "single_chat_attachments")
        
        // leave plus icon
        app!.cells.matching(identifier: "PPOptionsViewControllerCancelCell").firstMatch.tap()

        switch threemaApp {
        case .threema:
            // leave single chat --> chat overview
            app!.navigationBars.buttons.element(boundBy: 0).tap()
            // open chat of lisa goldman
            app!.tables.cells.element(boundBy: 4).tap()
        case .work: break
        case .onPrem: break
        }
        
        // open call view
        app!.buttons["ChatViewControllerCallBarButtonItem"].tap()
        
        // MARK: Screenshot 5: threema_call
        takeScreenshot(number: "05", name: "threema_call_incoming")
        
        // tap hide button to change ui to connected call
        app!.buttons["CallViewControllerHideButton"].tap()
        
        // MARK: Screenshot 6: threema_call
        takeScreenshot(number: "06", name: "threema_call")
        
        switch threemaApp {
        case .threema:
            // close call view
            app!.buttons["CallViewControllerEndButton"].tap()
            
            // leave single chat --> chat overview
            app!.navigationBars.buttons.element(boundBy: 0).tap()
            // open chat from roberto dias
            app!.tables.cells.element(boundBy: 3).tap()
            // open call view
            app!.buttons["ChatViewControllerCallBarButtonItem"].tap()
            // tap hide button to change ui to connected call
            app!.buttons["CallViewControllerHideButton"].tap()
            
        case .work: break
        case .onPrem: break
        }
        
        // tap camera button to change ui to video call
        app!.buttons["CallViewControllerVideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        takeScreenshot(number: "07", name: "threema_video_call")
        
        // close call view
        app!.buttons["CallViewControllerEndButton"].tap()
        
        // leave single chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        
        switch threemaApp {
        case .threema:
            // open group chat
            app!.tables.cells.element(boundBy: 1).tap()
        case .work:
            // open group chat
            app!.tables.cells.element(boundBy: 2).tap()
        case .onPrem:
            // open group chat
            app!.tables.cells.element(boundBy: 2).tap()
        }
        
        // MARK: Screenshot 8: group_chat
        takeScreenshot(number: "08", name: "group_chat")

        // show group detail
        app!.buttons["ChatProfileViewViewButton"].tap()

        // MARK: Screenshot 9: group_detail
        takeScreenshot(number: "09", name: "group_detail")

        // show ballots of the group
        app!.buttons["GroupDetailsDataSourceBallotQuickActionButton"].tap()

        // show ballot result
        app!.cells.matching(identifier: "BallotListTableViewControllerBallotListTableCell").element.tap()
        
        // MARK: Screenshot 10: ballot_matrix
        takeScreenshot(number: "10", name: "ballot_matrix")
        
        // leave ballot result --> ballot list
        app!.navigationBars.buttons["BallotResultViewControllerDoneBarButtonItem"].tap()
        
        // leave ballot list --> group detail
        app!.navigationBars.buttons["BallotListTableViewControllerDoneBarButtonItem"].tap()
        
        // leave group detail --> group chat
        app!.navigationBars.buttons["GroupDetailsViewControllerDoneButton"].tap()
        
        // // leave group chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()

        contactTabBarItem.tap()
        
        switch threemaApp {
        case .threema: break
        case .work:
            // tap contacts on segment control
            if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
            }
            else {
                if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                    app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
                }
            }
        case .onPrem:
            // tap contacts on segment control
            if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
            }
            else {
                if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                    app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
                }
            }
        }
        
        switch threemaApp {
        case .threema:
            // show detail of Schmidt Hanna
            app!.cells.element(boundBy: indexOfHannaSchmidt()).tap()
        case .work:
            // show detail of peter schreiner
            app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        case .onPrem:
            // show detail of peter schreiner
            app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        }
        
        // MARK: Screenshot 11: contact_detail
        takeScreenshot(number: "11", name: "contact_detail")
        
        // contact detail --> contact overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        
        // show my id tab
        myIDTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        takeScreenshot(number: "12", name: "my_id")
        
        // MARK: Show qr code
        if app!.buttons["MyIdentityViewControllerQrCodeButton"].exists {
            app!.buttons["MyIdentityViewControllerQrCodeButton"].tap()
        }
        else {
            app!.otherElements["MyIdentityViewControllerQrCodeButton"].tap()
        }
        
        // MARK: Screenshot 13: qr_code
        takeScreenshot(number: "13", name: "qr_code")
        
        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        takeScreenshot(number: "14", name: "threema_safe")
    }
    
    private func screenshotsForIpads() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIDTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
        
        // MARK: Screenshot 1: conversations
        takeScreenshot(number: "01", name: "conversations")

        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        takeScreenshot(number: "02", name: "contacts")

        // Switch to Chtas
        messagesTabBarItem.tap()
        
        switch threemaApp {
        case .threema:
            // open chat of hanna schmidt
            app!.tables.cells.element(boundBy: 0).tap()
        case .work:
            // open chat of peter schreiner
            app!.tables.cells.element(boundBy: 0).tap()
        case .onPrem:
            // open chat of peter schreiner
            app!.tables.cells.element(boundBy: 0).tap()
        }
        
        // MARK: Screenshot 3: single_chat
        takeScreenshot(number: "03", name: "single_chat")

        // tap plus icon
        app!.buttons["ChatBarViewImageButton"].tap()
        
        // MARK: Screenshot 4: single_chat_attachments
        takeScreenshot(number: "04", name: "single_chat_attachments")

        // leave plus icon
        app!.cells.matching(identifier: "PPOptionsViewControllerCancelCell").firstMatch.tap()
        
        switch threemaApp {
        case .threema:
            // open chat of lisa goldman
            app!.tables.cells.element(boundBy: 4).tap()
        case .work: break
        case .onPrem: break
        }

        // open call view
        app!.buttons["ChatViewControllerCallBarButtonItem"].tap()
        
        // MARK: Screenshot 5: threema_call
        takeScreenshot(number: "05", name: "threema_call_incoming")

        // tap hide button to change ui to connected call
        app!.buttons["CallViewControllerHideButton"].tap()
        
        // MARK: Screenshot 6: threema_call
        takeScreenshot(number: "06", name: "threema_call")

        switch threemaApp {
        case .threema:
            // close call view
            app!.buttons["CallViewControllerEndButton"].tap()
            
            // open chat from roberto dias
            app!.tables.cells.element(boundBy: 3).tap()
            // open call view
            app!.buttons["ChatViewControllerCallBarButtonItem"].tap()
            // tap hide button to change ui to connected call
            app!.buttons["CallViewControllerHideButton"].tap()
        case .work: break
        case .onPrem: break
        }
                
        // tap camera button to change ui to video call
        app!.buttons["CallViewControllerVideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        takeScreenshot(number: "07", name: "threema_video_call")

        // close call view
        app!.buttons["CallViewControllerEndButton"].tap()
        
        switch threemaApp {
        case .threema:
            // open group chat
            app!.tables.cells.element(boundBy: 1).tap()
        case .work:
            // open group chat
            app!.tables.cells.element(boundBy: 2).tap()
        case .onPrem:
            // open group chat
            app!.tables.cells.element(boundBy: 2).tap()
        }
        
        // MARK: Screenshot 8: group_chat
        takeScreenshot(number: "08", name: "group_chat")

        // show group detail
        app!.buttons["ChatProfileViewViewButton"].tap()

        // MARK: Screenshot 9: group_detail
        takeScreenshot(number: "09", name: "group_detail")

        // show ballots of the group
        app!.buttons["GroupDetailsDataSourceBallotQuickActionButton"].tap()

        // show ballot result
        app!.cells.matching(identifier: "BallotListTableViewControllerBallotListTableCell").element.tap()
        
        // MARK: Screenshot 10: ballot_matrix
        takeScreenshot(number: "10", name: "ballot_matrix")

        // leave ballot result --> ballot list
        app!.navigationBars.buttons["BallotResultViewControllerDoneBarButtonItem"].tap()
        
        // leave ballot list --> group detail
        app!.navigationBars.buttons["BallotListTableViewControllerDoneBarButtonItem"].tap()
        
        // leave group detail --> group chat
        app!.navigationBars.buttons["GroupDetailsViewControllerDoneButton"].tap()
        
        contactTabBarItem.tap()
                
        switch threemaApp {
        case .threema:
            // show detail of Schmidt Hanna
            app!.tables.element(boundBy: 0).cells.element(boundBy: indexOfHannaSchmidt()).tap()
        case .work:
            // tap contacts on segment control
            if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
            }
            else {
                if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                    app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
                }
            }
            
            // show detail of peter schreiner
            app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        case .onPrem:
            // tap contacts on segment control
            if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
            }
            else {
                if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                    app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
                }
            }
            
            // show detail of peter schreiner
            app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        }
        
        // MARK: Screenshot 11: contact_detail
        takeScreenshot(number: "11", name: "contact_detail")

        // show my id tab
        myIDTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        takeScreenshot(number: "12", name: "my_id")

        // MARK: Show qr code
        app?.buttons["MyIdentityViewControllerQrCodeButton"].tap()
        
        // MARK: Screenshot 13: qr_code
        takeScreenshot(number: "13", name: "qr_code")

        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        takeScreenshot(number: "14", name: "threema_safe")
        XCTAssertTrue(true)
    }
    
    // MARK: - Helpers
    func takeScreenshot(number: String, name: String) {
        sleep(1)
        let fullScreenshot = XCUIScreen.main.screenshot()
        let screenshot = XCTAttachment(
            uniformTypeIdentifier: UTType.png.identifier,
            name: "\(screenshotNameStart)-\(number)-\(name)-\(screenshotNameEnd).png",
            payload: fullScreenshot.pngRepresentation,
            userInfo: nil
        )
            
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    private func indexOfHannaSchmidt() -> Int {
        if language == "ru_RU" || language == "nl_NL" || language == "zh_Hans" || language == "zh_Hant" {
            return 4
        }
        else if language == "it_IT" || language == "pt_BR" {
            return 0
        }
        else if language == "fr_FR" {
            return 1
        }
        
        return 3
    }
    
    private func indexOfPeterSchreiner() -> Int {
        2
    }
    
    func waitForElementToDisappear(_ element: XCUIElement) -> Bool {
        let expectation = XCTKVOExpectation(
            keyPath: "exists",
            object: element,
            expectedValue: false
        )

        let result = XCTWaiter().wait(for: [expectation], timeout: 15)
        return result == .completed
    }
    
    func languageCode() -> String {
        let lang = NSLocale.preferredLanguages.first!
        
        switch lang {
        case "en":
            return "en_US"
        case "de":
            return "de_DE"
        case "it":
            return "it_IT"
        case "fr":
            return "fr_FR"
        case "es":
            return "es_ES"
        case "pt-BR":
            return "pt_BR"
        case "ru":
            return "ru_RU"
        case "pl":
            return "pl_PL"
        case "nl":
            return "nl_NL"
        case "cs":
            return "cs_CZ"
        case "zh-Hans":
            return "zh_hans"
        case "zh-Hant":
            return "zh_hant"
        case "tr":
            return "tr_TR"
        case "ja":
            return "ja_JP"
        default:
            XCTFail("Unknown language code: \(lang)")
        }
        return ""
    }
}
