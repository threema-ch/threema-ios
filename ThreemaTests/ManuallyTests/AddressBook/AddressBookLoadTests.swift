import Contacts
import FileUtility
import PromiseKit
import RSKImageCropper
import XCTest
@testable import Threema

final class AddressBookLoadTests: XCTestCase {

    override func setUp() {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        FileUtility.updateSharedInstance(with: FileUtility())
    }

    func testGenerateVCardsAndEmailHashes() throws {
        let testBundle = Bundle(for: AddressBookLoadTests.self)
        guard let filePath = testBundle.path(forResource: "test_sandbox_ids", ofType: "txt") else {
            XCTFail(
                "File test_sandbox_ids.txt could not be loaded."
            )
            return
        }

        let fileSandboxContacts = FileUtility.shared.appDocumentsDirectory?
            .appendingPathComponent("test_sandbox_contacts.vcf")
        let fileSandboxEmailHashes = FileUtility.shared.appDocumentsDirectory?
            .appendingPathComponent("test_sandbox_email_hashes.txt")

        FileUtility.shared.deleteIfExists(at: fileSandboxContacts)
        FileUtility.shared.deleteIfExists(at: fileSandboxEmailHashes)

        let ids = try String(contentsOfFile: filePath, encoding: .utf8)
        for id in ids.components(separatedBy: .newlines) where !id.isEmpty {
            var vCard: String
                
            let r = Int.random(in: 0..<3)
                
            if r == 0 {
                vCard = "\(String(format: profilePictureFreezing(), id, id, id))\n"
            }
            else if r == 1 {
                vCard = "\(String(format: profilePictureUnicorn(), id, id, id))\n"
            }
            else {
                vCard = "\(String(format: profilePictureCup(), id, id, id))\n"
            }
                
            print(id)
                
            FileUtility.shared.append(text: vCard, to: fileSandboxContacts)
            FileUtility.shared.append(text: vCard, to: fileSandboxEmailHashes)
        }
    }

    func testImportVCardIntoAddressBook() throws {
        let sandboxContactsURL = FileUtility.shared.appDocumentsDirectory?
            .appendingPathComponent("test_sandbox_contacts.vcf")
        guard let sandboxContactsURL,
              FileUtility.shared.fileExists(at: sandboxContactsURL) else {
            XCTFail(
                "File test_sandbox_contacts.cvf could not be loaded, please run func testGenerateVCardsAndEmailHashes() first!"
            )
            return
        }
        let importContactsData = try Data(contentsOf: sandboxContactsURL)
        let importContacts = try CNContactVCardSerialization.contacts(with: importContactsData)
        print(importContacts.map { "\($0.givenName) \($0.familyName)" })

        let expect = expectation(description: "Import contacts")

        processCNContactStore { contactStore in
            do {
                var existingContacts = [CNContact]()

                let fetchRequest =
                    CNContactFetchRequest(keysToFetch: [
                        CNContactFormatter
                            .descriptorForRequiredKeys(for: .fullName),
                    ])
                try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                    if importContacts.first(where: { importContact in
                        importContact.familyName == contact.familyName
                    }) != nil {
                        existingContacts.append(contact)
                    }
                }

                // Delete contact if exists already
                let delRequest = CNSaveRequest()
                for contact in existingContacts {
                    delRequest.delete(contact.mutableCopy() as! CNMutableContact)
                }
                try contactStore.execute(delRequest)

                // Add contact
                let saveRequest = CNSaveRequest()
                for importContact in importContacts {
                    saveRequest.add(
                        importContact.mutableCopy() as! CNMutableContact,
                        toContainerWithIdentifier: nil
                    )
                }
                try contactStore.execute(saveRequest)

                expect.fulfill()
            }
            catch {
                print("Error while import contacts")
            }
        }

        wait(for: [expect], timeout: 10)
    }

    func testDeleteAddressBook() throws {
        let expect = expectation(description: "Delete contacts")

        processCNContactStore { contactStore in
            do {
                var existingContacts = [CNContact]()

                let fetchRequest =
                    CNContactFetchRequest(keysToFetch: [
                        CNContactFormatter
                            .descriptorForRequiredKeys(for: .fullName),
                    ])
                try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                    if contact.givenName == "Testuser" {
                        existingContacts.append(contact)
                    }
                }

                // Delete contact
                let delRequest = CNSaveRequest()
                for contact in existingContacts {
                    delRequest.delete(contact.mutableCopy() as! CNMutableContact)
                }
                try contactStore.execute(delRequest)

                expect.fulfill()
            }
            catch {
                print("Error while deleting contacts")
            }
        }

        wait(for: [expect], timeout: 10)
    }

    // Process action on address book
    func processCNContactStore(action: @escaping (CNContactStore) -> Void) {
        let contactStore = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized, .limited:
            action(contactStore)
        case .notDetermined:
            // In case of not determined request for access
            // If allowed it will return success otherwise return error
            contactStore.requestAccess(for: .contacts, completionHandler: { success, _ in
                if success {
                    action(contactStore)
                }
            })
        case .restricted, .denied:
            fatalError()
            break
        @unknown default:
            fatalError()
        }
    }

    private func profilePictureFreezing() -> String {
        loadVCard("ProfilePictureFreezing")
    }

    private func profilePictureUnicorn() -> String {
        loadVCard("ProfilePictureUnicorn")
    }

    private func profilePictureCup() -> String {
        loadVCard("ProfilePictureCup")
    }
    
    private func loadVCard(_ fileName: String) -> String {
        let bundle = Bundle(for: type(of: self))
        
        guard let filePath = bundle.path(forResource: fileName, ofType: "txt") else {
            return "File not found"
        }
        
        do {
            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
            return contents
        }
        catch {
            return "Error reading file: \(error)"
        }
    }
}

extension FileUtilityProtocol {
    /// Append text to the end of file.
    ///
    /// - Parameters:
    ///    - filePath: path to appending file
    ///    - text: content to addend
    @discardableResult
    fileprivate func append(text: String, to fileURL: URL?) -> Bool {
        guard let fileURL else {
            return false
        }

        var result = false

        if fileExists(atPath: fileURL.path) {
            do {
                let data = Data(text.utf8)
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
            catch {
                print("\(error)")
            }

            result = true
        }
        else {
            result = write(contents: Data(text.utf8), to: fileURL)
        }

        return result
    }
}
