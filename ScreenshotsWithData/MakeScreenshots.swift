//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

class MakeScreenshots: XCTestCase {
        
    var language: String = ""
    var theme: String = "light"
    var version: String = "4.6.3"
    var orientation: String = ""
    var screenshotNameStart: String = ""
    var screenshotNameEnd: String = ""
    var app: XCUIApplication?
    var isWorkApp: Bool = false

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            orientation = "landscape"
            XCUIDevice.shared.orientation = .landscapeLeft
        } else {
            orientation = "portrait"
            XCUIDevice.shared.orientation = .portrait
        }

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        Snapshot.setupSnapshot(app!, waitForAnimations: true)
        language = Snapshot.getLanguage()
        app!.launch()
                
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        if let tmpTheme = argValueForKey(key: "-theme", app: app!) {
            theme = tmpTheme
        }
        if let tmpVersion = argValueForKey(key: "-version", app: app!) {
            version = tmpVersion
        }
        
        var ios: String = "ios-"
        ios.append(ProcessInfo().environment["SIMULATOR_DEVICE_NAME"]!)
        
        // add os, device, appversion, locale, theme
        var lang = language
        lang = lang.replacingOccurrences(of: "-", with: "_")
        
        screenshotNameStart = "\(ios)-\(version)-\(lang)"
        screenshotNameEnd = "\(theme)-\(orientation)"
        
        if #available(iOS 13.0, *) {
        }
        else {
            SDStatusBarManager.sharedInstance().carrierName = "3ma"
            SDStatusBarManager.sharedInstance().timeString = "08:15"
            SDStatusBarManager.sharedInstance().bluetoothState = .hidden
            SDStatusBarManager.sharedInstance().batteryDetailEnabled = true
            SDStatusBarManager.sharedInstance().enableOverrides()
        }
                        
        addUIInterruptionMonitor(withDescription: "System Dialog") { (alert) -> Bool in
            let btnAllow: XCUIElement
            let btnAllowAlways: XCUIElement
            let btnAllowAll: XCUIElement
            let btnOK: XCUIElement
            let cancelButton: XCUIElement
            
            btnAllow = alert.buttons[self.allowButtonText()]
            btnAllowAlways = alert.buttons[self.alwaysAllowButtonText()]
            btnAllowAll = alert.buttons[self.allowAllButtonText()]
            btnOK = alert.buttons[self.okButtonText()]
            cancelButton = alert.buttons[self.cancelButtonText()]
            
            if cancelButton.exists {
                cancelButton.tap()
                return true
            }
            if btnAllow.exists {
                btnAllow.tap()
                return true
            }
            if btnAllowAlways.exists {
                btnAllowAlways.tap()
                return true
            }
            if btnAllowAll.exists {
                btnAllowAll.tap()
                return true
            }
            if btnOK.exists {
                btnOK.tap()
                return true
            }
            return true
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        if #available(iOS 13.0, *) {
            
        }
        else {
            SDStatusBarManager.sharedInstance().disableOverrides()
        }
    }
    
    func testMakeScreenshots() {
        app = XCUIApplication()
        
        if Bundle.main.bundleIdentifier == "ch.threema.ScreenshotsWithDataWork.xctrunner" {
            isWorkApp = true
//            theme = "dark"
//            screenshotNameEnd = "\(theme)-\(orientation)"
        }
        
        // MARK: Enter license key
        if isWorkApp && app!.textFields.count > 0 {
            let login = workLogin()
            
            app!.textFields["licenseUsername"].typeText(login!["username"]!)
            if app!.keys.allElementsBoundByIndex[0].exists {
                app!.typeText("\n")
            }
            app!.secureTextFields["licensePassword"].typeText(login!["password"]!)
            app!.buttons["ConfirmButton"].tap()
            
            sleep(5)
        }
        
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
                        
        if UIDevice.current.userInterfaceIdiom == .pad {
            if isWorkApp == true {
                workScreenshotsForIpads()
            } else {
                screenshotsForIpads()
            }
        } else {
            if isWorkApp == true {
                workScreenshotsForIphones()
            } else {
                screenshotsForIphones()
            }
        }
    }
    
    private func workLogin() -> [String: String]? {
        
        // get screenshot project directory for work login
        guard let srcroot: String = ProcessInfo.processInfo.environment["SRCROOT"] else {
            assertionFailure("Can't find environment variable ro SRCROOT")
            return nil
        }
        
        let screenshotProject = "screenshot/dataWork"
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
            return try JSONSerialization.jsonObject(with: loginJsonData, options: []) as? [String : String]
        } catch {
            assertionFailure("Can't create jsonObject from login.json")
            return nil
        }
    }
    
    private func screenshotsForIphones() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIdTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
                        
        // MARK: Screenshot 1: conversations
        Snapshot.snapshot(screenshotName("01", "conversations"))
        
        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        Snapshot.snapshot(screenshotName("02", "contacts"))
        
        // Switch to Chtas
        messagesTabBarItem.tap()
        
        // open chat of hanna schmidt
        app!.tables.cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 3: single_chat
        Snapshot.snapshot(screenshotName("03", "single_chat"))
        
        // tap plus icon
        app!.buttons["PlusButton"].tap()
        
        // MARK: Screenshot 4: single_chat_attachments
        Snapshot.snapshot(screenshotName("04", "single_chat_attachments"))
        
        // leave plus icon
        app!.cells["Cancel"].tap()
        // leave single chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // open chat of lisa goldman
        app!.tables.cells.element(boundBy: 4).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
                
        // MARK: Screenshot 5: threema_call
        Snapshot.snapshot(screenshotName("05", "threema_call_incoming"))
                        
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
        
        // MARK: Screenshot 6: threema_call
        Snapshot.snapshot(screenshotName("06", "threema_call"))
        
        // close call view
        app!.buttons["EndButton"].tap()
        // leave single chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // open chat from roberto dias
        app!.tables.cells.element(boundBy: 3).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
        // tap camera button to change ui to video call
        app!.buttons["VideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        Snapshot.snapshot(screenshotName("07", "threema_video_call"))
        
        // close call view
        app!.buttons["EndButton"].tap()
        // leave single chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // open group chat
        app!.tables.cells.element(boundBy: 1).tap()
        
        // MARK: Screenshot 8: group_chat
        Snapshot.snapshot(screenshotName("08", "group_chat"))
        
        // swipe down to show the header
        app!.swipeDown()
        // show group detail
        app!.scrollViews["GroupImageView"].tap()
        
        // MARK: Screenshot 9: group_detail
        Snapshot.snapshot(screenshotName("09", "group_detail"))
        
        // leave group detail --> group chat
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open ballot view
        app!.buttons["BallotButton"].tap()
        // select closed ballot
        app!.cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 10: ballot_matrix
        Snapshot.snapshot(screenshotName("10", "ballot_matrix"))
        
        // leave ballot --> ballot overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // ballot overview --> group chat
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // group chat --> conversation overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        contactTabBarItem.tap()
        // show detail of Schmidt Hanna
        app!.cells.element(boundBy: indexOfHannaSchmidt()).tap()
        
        // MARK: Screenshot 11: contact_detail
        Snapshot.snapshot(screenshotName("11", "contact_detail"))
        
        // contact detail --> contact overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // show my id tab
        myIdTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        Snapshot.snapshot(screenshotName("12", "my_id"))
        
        //MARK: Show qr code
        app?.buttons["qrCodeButton"].tap()
        
        // MARK: Screenshot 13: qr_code
        Snapshot.snapshot(screenshotName("13", "qr_code"))
        
        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        Snapshot.snapshot(screenshotName("14", "threema_safe"))
    }
    
    private func screenshotsForIpads() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIdTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
        
        // MARK: Screenshot 1: conversations
        Snapshot.snapshot(screenshotName("01", "conversations"))
        
        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        Snapshot.snapshot(screenshotName("02", "contacts"))
        
        // Switch to Chtas
        messagesTabBarItem.tap()
        
        // open chat of hanna schmidt
        app!.tables.cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 3: single_chat
        Snapshot.snapshot(screenshotName("03", "single_chat"))
        
        // tap plus icon
        app!.tap()
        
        // MARK: Screenshot 4: single_chat_attachments
        Snapshot.snapshot(screenshotName("04", "single_chat_attachments"))
        
        // leave plus icon
        app!.cells["Cancel"].tap()
        
        // open chat of lisa goldman
        app!.tables.cells.element(boundBy: 4).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
                
        // MARK: Screenshot 5: threema_call
        Snapshot.snapshot(screenshotName("05", "threema_call_incoming"))
                        
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
                
        // MARK: Screenshot 6: threema_call
        Snapshot.snapshot(screenshotName("06", "threema_call"))
        
        // close call view
        app!.buttons["EndButton"].tap()
        // open chat from roberto dias
        app!.tables.cells.element(boundBy: 3).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
        // tap camera button to change ui to video call
        app!.buttons["VideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        Snapshot.snapshot(screenshotName("07", "threema_video_call"))
        
        // close call view
        app!.buttons["EndButton"].tap()

        // open group chat
        app!.tables.cells.element(boundBy: 1).tap()
        
        // MARK: Screenshot 8: group_chat
        Snapshot.snapshot(screenshotName("08", "group_chat"))
        
        // swipe down to show the header
        app!.swipeDown()
        // show group detail
        app!.scrollViews["GroupImageView"].tap()
        
        // MARK: Screenshot 9: group_detail
        Snapshot.snapshot(screenshotName("09", "group_detail"))
        
        // leave group detail --> group chat
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open ballot view
        app!.buttons["BallotButton"].tap()
        // select closed ballot
        app!.tables.element(boundBy: 1).cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 10: ballot_matrix
        Snapshot.snapshot(screenshotName("10", "ballot_matrix"))
        
        // leave ballot --> ballot overview
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        // ballot overview --> group chat
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        // show contact tab
        contactTabBarItem.tap()
        // show detail of Schmidt Hanna
        app!.tables.element(boundBy: 0).cells.element(boundBy: indexOfHannaSchmidt()).tap()
        
        // MARK: Screenshot 11: contact_detail
        Snapshot.snapshot(screenshotName("11", "contact_detail"))
        
        // show my id tab
        myIdTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        Snapshot.snapshot(screenshotName("12", "my_id"))
        
        //MARK: Show qr code
        app?.buttons["qrCodeButton"].tap()
        
        // MARK: Screenshot 13: qr_code
        Snapshot.snapshot(screenshotName("13", "qr_code"))
        
        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        Snapshot.snapshot(screenshotName("14", "threema_safe"))
    }
    
    private func workScreenshotsForIphones() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIdTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
        
        // MARK: Screenshot 1: conversations
        Snapshot.snapshot(screenshotName("01", "conversations"))
        
        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        Snapshot.snapshot(screenshotName("02", "contacts"))
        
        // Switch to Chtas
        messagesTabBarItem.tap()

        // open chat of peter schreiner
        app!.tables.cells.element(boundBy: 0).tap()

        // MARK: Screenshot 3: single_chat
        Snapshot.snapshot(screenshotName("03", "single_chat"))

        // tap plus icon
        app!/*@START_MENU_TOKEN@*/.buttons["PlusButton"]/*[[".images",".buttons[\"Send media or location\"]",".buttons[\"PlusButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()

        // MARK: Screenshot 4: single_chat_attachments
        Snapshot.snapshot(screenshotName("04", "single_chat_attachments"))

        // leave plus icon
        app!.cells["Cancel"].tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
                
        // MARK: Screenshot 5: threema_call
        Snapshot.snapshot(screenshotName("05", "threema_call_incoming"))
        
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
        
        // MARK: Screenshot 6: threema_call
        Snapshot.snapshot(screenshotName("06", "threema_call"))
        
        // tap camera button to change ui to video call
        app!.buttons["VideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        Snapshot.snapshot(screenshotName("07", "threema_video_call"))

        // close call view
        app!.buttons["EndButton"].tap()
        // leave single chat --> chat overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // open group chat
        app!.tables.cells.element(boundBy: 2).tap()
        
        // MARK: Screenshot 8: group_chat
        Snapshot.snapshot(screenshotName("08", "group_chat"))
        
        // swipe down to show the header
        app!.swipeDown()
        // show group detail
        app!.scrollViews["GroupImageView"].tap()

        // MARK: Screenshot 9: group_detail
        Snapshot.snapshot(screenshotName("09", "group_detail"))

        // leave group detail --> group chat
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open ballot view
        app!.buttons["BallotButton"].tap()
        // select closed ballot
        app!.cells.element(boundBy: 0).tap()

        // MARK: Screenshot 10: ballot_matrix
        Snapshot.snapshot(screenshotName("10", "ballot_matrix"))

        // leave ballot --> ballot overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // ballot overview --> group chat
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        // group chat --> conversation overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        contactTabBarItem.tap()
        
        // tap contacts on segment control
        if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
            app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
        } else {
            if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
            }
        }
        
        // show detail of peter schreiner
        app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        
        // MARK: Screenshot 11: contact_detail
        Snapshot.snapshot(screenshotName("11", "contact_detail"))
        
        // contact detail --> contact overview
        app!.navigationBars.buttons.element(boundBy: 0).tap()
        
        // show my id tab
        myIdTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        Snapshot.snapshot(screenshotName("12", "my_id"))
        
        //MARK: Show qr code
        app?.buttons["qrCodeButton"].tap()
        
        // MARK: Screenshot 13: qr_code
        Snapshot.snapshot(screenshotName("13", "qr_code"))
        
        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        Snapshot.snapshot(screenshotName("14", "threema_safe"))
    }
    
    private func workScreenshotsForIpads() {
        let contactTabBarItem = app!.tabBars.buttons.element(boundBy: 0)
        let messagesTabBarItem = app!.tabBars.buttons.element(boundBy: 1)
        let myIdTabBarItem = app!.tabBars.buttons.element(boundBy: 2)
        
        // switch tabs that fastlane will close all alerts before it will take the first screenshot
        contactTabBarItem.tap()
        messagesTabBarItem.tap()
        
        // MARK: Screenshot 1: conversations
        Snapshot.snapshot(screenshotName("01", "conversations"))
        
        // Switch to Contacts
        contactTabBarItem.tap()
        
        // MARK: Screenshot 2: contacts
        Snapshot.snapshot(screenshotName("02", "contacts"))
        
        // Switch to Chtas
        messagesTabBarItem.tap()
        
        // open chat of peter schreiner
        app!.tables.cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 3: single_chat
        Snapshot.snapshot(screenshotName("03", "single_chat"))
        
        // tap plus icon
        app!/*@START_MENU_TOKEN@*/.buttons["PlusButton"]/*[[".images",".buttons[\"Send media or location\"]",".buttons[\"PlusButton\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // MARK: Screenshot 4: single_chat_attachments
        Snapshot.snapshot(screenshotName("04", "single_chat_attachments"))
        
        // leave plus icon
        app!.cells["Cancel"].tap()
        // swipe down to show the header
        app!.swipeDown()
        // open call view
        app!.buttons["CallButton"].tap()
                
        // MARK: Screenshot 5: threema_call_incoming
        Snapshot.snapshot(screenshotName("05", "threema_call_incoming"))
                        
        // tap hide button to change ui to connected call
        app!.buttons["HideButton"].tap()
                
        // MARK: Screenshot 6: threema_call
        Snapshot.snapshot(screenshotName("06", "threema_call"))
        
        // tap camera button to change ui to video call
        app!.buttons["VideoButton"].tap()
        
        // MARK: Screenshot 7: threema_video_call
        Snapshot.snapshot(screenshotName("07", "threema_video_call"))
                
        // close call view
        app!.buttons["EndButton"].tap()
        // open group chat
        app!.tables.cells.element(boundBy: 2).tap()
        
        // MARK: Screenshot 8: group_chat
        Snapshot.snapshot(screenshotName("08", "group_chat"))
        
        // swipe down to show the header
        app!.swipeDown()
        // show group detail
        app!.scrollViews["GroupImageView"].tap()
        
        // MARK: Screenshot 9: group_detail
        Snapshot.snapshot(screenshotName("09", "group_detail"))
        
        // leave group detail --> group chat
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        // swipe down to show the header
        app!.swipeDown()
        // open ballot view
        app!.buttons["BallotButton"].tap()
        // select closed ballot
        app!.tables.element(boundBy: 1).cells.element(boundBy: 0).tap()
        
        // MARK: Screenshot 10: ballot_matrix
        Snapshot.snapshot(screenshotName("10", "ballot_matrix"))
        
        // leave ballot --> ballot overview
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        // ballot overview --> group chat
        app!.navigationBars.element(boundBy: 1).buttons.element(boundBy: 0).tap()
        contactTabBarItem.tap()
                
        // tap contacts on segment control
        if app!.navigationBars.element(boundBy: 0).buttons["Work"].exists {
            app!.navigationBars.element(boundBy: 0).buttons["Work"].tap()
        } else {
            if app!.navigationBars.element(boundBy: 0).buttons["Case"].exists {
                app!.navigationBars.element(boundBy: 0).buttons["Case"].tap()
            }
        }
        
        // show detail of peter schreiner
        app!.cells.element(boundBy: indexOfPeterSchreiner()).tap()
        
        // MARK: Screenshot 11: contact_detail
        Snapshot.snapshot(screenshotName("11", "contact_detail"))
        
        // show my id tab
        myIdTabBarItem.tap()
        
        // MARK: Screenshot 12: my_id
        Snapshot.snapshot(screenshotName("12", "my_id"))

                
        //MARK: Show qr code
        app?.buttons["qrCodeButton"].tap()
        
        // MARK: Screenshot 13: qr_code
        Snapshot.snapshot(screenshotName("13", "qr_code"))
        
        // MARK: Dismiss qr code
        app?.otherElements["CoverView"].tap()
        
        // show threema safe
        app!.cells["SafeCell"].tap()
        
        // MARK: Screenshot 14: threema_safe
        Snapshot.snapshot(screenshotName("14", "threema_safe"))
    }
        
    private func argValueForKey(key: String, app: XCUIApplication) -> String? {
        if let index = app.launchArguments.firstIndex(of: key) {
            
            return app.launchArguments[index+1]
        }
        return nil
    }
    
    private func screenshotName(_ count: String, _ key: String) -> String {
        return "\(screenshotNameStart)-\(count)-\(key)-\(screenshotNameEnd)"
    }
    
    private func indexOfHannaSchmidt() -> Int {
        if language == "ru-RU" || language == "nl-NL" {
            return 4
        }
        else if language == "it-IT" || language == "pt_BR" {
            return 0
        }
        else if language == "fr-FR" {
            return 1
        }
        
        return 3
    }
    
    private func indexOfPeterSchreiner() -> Int {
        return 2
    }
        
    private func allowButtonText() -> String {
        return "Allow"
    }
    
    private func alwaysAllowButtonText() -> String {
        return "Always Allow"
    }
    
    private func allowAllButtonText() -> String {
        return "Allow Access to All Photos"
    }
    
    private func okButtonText() -> String {
        return "OK"
    }
    
    private func cancelButtonText() -> String {
        return "Cancel"
    }
}
