import Foundation
import Testing
@testable import ThreemaFramework

/// Serialized because the MDM configuration is process wide state: both user defaults domains and the
/// MDM caches inside `MDMSetup`.
@Suite("MDMSetup", .serialized)
final class MDMSetupTests {

    // MARK: - Instances to be injected
    
    private let userSettings = UserSettingsMock()
    private let licenseStore = LicenseStoreMock()
    private let myIdentityStore = MyIdentityStoreMock()

    // MARK: - Lifecycle
    
    init() {
        AppGroup.setGroupID("group.ch.threema")
        Self.deleteMDM()
    }

    deinit {
        Self.deleteMDM()
    }

    // MARK: - ID backup

    @Test("ID backup and its password from the company MDM")
    func idBackupFromCompanyMDM() throws {
        setMDM(company: [MDM_KEY_ID_BACKUP: "XXXX-XXXX-..."])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)

        // `hasIDBackup()` reads the backup, so the assertions below only mean something if it succeeded
        try #require(mdmSetup.hasIDBackup())
        #expect(mdmSetup.idBackup == "XXXX-XXXX-...")
        #expect(mdmSetup.idBackupPassword == nil)
    }

    // MARK: - Keep messages

    @Test("Keep messages days from the company MDM")
    func keepMessagesDays() {
        setMDM(company: [MDM_KEY_KEEP_MESSAGE_DAYS: NSNumber(value: 10)])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)

        #expect(mdmSetup.keepMessagesDays()?.intValue == 10)
    }

    // MARK: - Threema Safe backup & restore

    @Test(
        "Threema Safe backup and restore state",
        arguments: [
            SafeSetupCase(
                name: "backup disabled",
                companyMDM: [MDM_KEY_DISABLE_BACKUPS: .string("1")],
                expected: SafeSetupState(backupDisable: true, restoreDisable: true)
            ),
            SafeSetupCase(
                name: "backup enabled",
                companyMDM: [MDM_KEY_DISABLE_BACKUPS: .string("0")],
                expected: SafeSetupState()
            ),
            SafeSetupCase(
                name: "backup forced",
                companyMDM: [
                    MDM_KEY_DISABLE_BACKUPS: .string("0"),
                    MDM_KEY_SAFE_ENABLE: .number(1),
                ],
                expected: SafeSetupState(backupForce: true)
            ),
            SafeSetupCase(
                name: "backup with server and password",
                companyMDM: [
                    MDM_KEY_DISABLE_BACKUPS: .string("0"),
                    MDM_KEY_SAFE_SERVER_URL: .string("https://example.com"),
                    MDM_KEY_SAFE_PASSWORD: .string("password"),
                ],
                expected: SafeSetupState(backupServerPreset: true, restoreServerPreset: true)
            ),
            SafeSetupCase(
                name: "backup forced with server and password",
                companyMDM: [
                    MDM_KEY_DISABLE_BACKUPS: .string("0"),
                    MDM_KEY_SAFE_ENABLE: .number(1),
                    MDM_KEY_SAFE_SERVER_URL: .string("https://example.com"),
                    MDM_KEY_SAFE_PASSWORD: .string("password"),
                ],
                expected: SafeSetupState(
                    backupForce: true,
                    backupPasswordPreset: true,
                    backupServerPreset: true,
                    restoreServerPreset: true
                )
            ),
            SafeSetupCase(
                name: "restore disabled",
                companyMDM: [MDM_KEY_SAFE_RESTORE_ENABLE: .string("0")],
                expected: SafeSetupState(restoreDisable: true)
            ),
            SafeSetupCase(
                name: "restore enabled",
                companyMDM: [MDM_KEY_SAFE_RESTORE_ENABLE: .string("1")],
                expected: SafeSetupState()
            ),
            SafeSetupCase(
                name: "restore enabled with server and password",
                companyMDM: [
                    MDM_KEY_SAFE_SERVER_URL: .string("https://example.com"),
                    MDM_KEY_SAFE_PASSWORD: .string("password"),
                    MDM_KEY_SAFE_RESTORE_ENABLE: .string("1"),
                ],
                expected: SafeSetupState(backupServerPreset: true, restoreServerPreset: true)
            ),
            SafeSetupCase(
                name: "restore forced with server and password",
                companyMDM: [
                    MDM_KEY_SAFE_SERVER_URL: .string("https://example.com"),
                    MDM_KEY_SAFE_PASSWORD: .string("password"),
                    MDM_KEY_SAFE_RESTORE_ENABLE: .string("1"),
                    MDM_KEY_SAFE_RESTORE_ID: .string("EINSZWEI"),
                ],
                expected: SafeSetupState(
                    backupServerPreset: true,
                    restoreForce: true,
                    restorePasswordPreset: true,
                    restoreServerPreset: true
                )
            ),
        ]
    )
    func safeSetupState(testCase: SafeSetupCase) {
        setMDM(company: testCase.companyMDM.mapValues(\.value))

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)

        #expect(mdmSetup.isSafeBackupDisable() == testCase.expected.backupDisable)
        #expect(mdmSetup.isSafeBackupForce() == testCase.expected.backupForce)
        #expect(mdmSetup.isSafeBackupPasswordPreset() == testCase.expected.backupPasswordPreset)
        #expect(mdmSetup.isSafeBackupServerPreset() == testCase.expected.backupServerPreset)

        #expect(mdmSetup.isSafeRestoreDisable() == testCase.expected.restoreDisable)
        #expect(mdmSetup.isSafeRestoreForce() == testCase.expected.restoreForce)
        #expect(mdmSetup.isSafeRestorePasswordPreset() == testCase.expected.restorePasswordPreset)
        #expect(mdmSetup.isSafeRestoreServerPreset() == testCase.expected.restoreServerPreset)
    }

    // MARK: - Empty values

    @Test("Empty string values in the company MDM count as unset")
    func emptyValuesInCompanyMDM() {
        setMDM(company: [
            MDM_KEY_WEB_HOSTS: "",
            MDM_KEY_SAFE_PASSWORD: "",
            MDM_KEY_SAFE_SERVER_URL: "",
            MDM_KEY_SAFE_SERVER_USERNAME: "",
            MDM_KEY_SAFE_SERVER_PASSWORD: "",
            MDM_KEY_SAFE_RESTORE_ID: "",
            MDM_KEY_SAFE_PASSWORD_PATTERN: "",
            MDM_KEY_SAFE_PASSWORD_MESSAGE: "",
        ])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)

        #expect(mdmSetup.webHosts() == nil)
        #expect(mdmSetup.safePassword() == nil)
        #expect(mdmSetup.safeServerURL() == nil)
        #expect(mdmSetup.safeServerUsername() == nil)
        #expect(mdmSetup.safeServerPassword() == nil)
        #expect(mdmSetup.safeRestoreID() == nil)
        #expect(mdmSetup.safePasswordPattern() == nil)
        #expect(mdmSetup.safePasswordMessage() == nil)
    }

    // MARK: - Support description

    @Test("Support description string with Threema MDM only")
    func supportDescriptionStringWithThreemaMDM() {
        setMDM(threema: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup()

        #expect(mdmSetup.supportDescriptionString() == "m")
    }

    @Test("Support description string with company and Threema MDM")
    func supportDescriptionStringWithBothMDMs() {
        let mdm = Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        )
        setMDM(company: mdm, threema: mdm)

        let mdmSetup = makeMDMSetup()

        #expect(mdmSetup.supportDescriptionString() == "me")
    }

    @Test("Support description string with company MDM only")
    func supportDescriptionStringWithCompanyMDM() {
        setMDM(company: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup()

        #expect(mdmSetup.supportDescriptionString() == "e")
    }

    @Test("No support description string for empty MDMs")
    func supportDescriptionStringWithEmptyMDMs() {
        setMDM(
            company: [String: Any](),
            threema: Self.threemaMDM(override: true, parameters: [String: Any]())
        )

        let mdmSetup = makeMDMSetup()

        #expect(mdmSetup.supportDescriptionString() == nil)
    }

    @Test("No support description string without any MDM")
    func supportDescriptionStringWithoutMDM() {
        let mdmSetup = makeMDMSetup()

        #expect(mdmSetup.supportDescriptionString() == nil)
    }

    // MARK: - Discarded Threema MDM parameters

    @Test("ID backup and Safe password of the company MDM win over the Threema MDM")
    func applyDiscardsThreemaMDMValuesWithCompanyMDM() throws {
        setMDM(company: [
            MDM_KEY_ID_BACKUP: "XXXX-XXXX-...",
            MDM_KEY_SAFE_PASSWORD: "12345678",
            MDM_KEY_ID_BACKUP_PASSWORD: "12345678",
        ])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [
                MDM_KEY_ID_BACKUP: "YYYY-YYYY-...",
                MDM_KEY_ID_BACKUP_PASSWORD: "87654321",
                MDM_KEY_SAFE_PASSWORD: "87654321",
            ]),
            sendForce: false
        )

        try #require(mdmSetup.hasIDBackup())
        #expect(mdmSetup.idBackup == "XXXX-XXXX-...")
        #expect(mdmSetup.safePassword() == "12345678")
        #expect(mdmSetup.idBackupPassword == "12345678")
    }

    @Test("ID backup, Safe password and license of a Threema MDM are discarded without company MDM")
    func applyDiscardsThreemaMDMValuesWithoutCompanyMDM() {
        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [
                MDM_KEY_ID_BACKUP: "YYYY-YYYY-...",
                MDM_KEY_ID_BACKUP_PASSWORD: "87654321",
                MDM_KEY_SAFE_PASSWORD: "87654321",
                MDM_KEY_LICENSE_USERNAME: "mdm@mdm.ch",
                MDM_KEY_LICENSE_PASSWORD: "87654321",
            ]),
            sendForce: false
        )

        #expect(!mdmSetup.hasIDBackup())
        #expect(mdmSetup.idBackup == nil)
        #expect(mdmSetup.safePassword() == nil)
        #expect(mdmSetup.idBackupPassword == nil)
        #expect(licenseStore.licenseUsername == nil)
        #expect(licenseStore.licensePassword == nil)
    }

    // MARK: - Remote secret

    @Test("Remote secret from the company MDM during setup")
    func remoteSecretInCompanyMDMForSetup() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: "1"])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup, isOnPrem: true)

        #expect(mdmSetup.enableRemoteSecret())
    }

    @Test("Remote secret from the Threema MDM during setup")
    func remoteSecretInThreemaMDMForSetup() {
        let mdmSetup = makeMDMSetup(appSetupState: .notSetup, isOnPrem: true)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(mdmSetup.enableRemoteSecret())
    }

    @Test("Company MDM wins during setup if the Threema MDM does not override")
    func remoteSecretInThreemaMDMWithCompanyMDMForSetup() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: 0])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup, isOnPrem: true)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: false, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(!mdmSetup.enableRemoteSecret())
    }

    @Test("Remote secret from the company MDM")
    func remoteSecretInCompanyMDM() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: "1"])

        let mdmSetup = makeMDMSetup(isOnPrem: true)

        #expect(mdmSetup.enableRemoteSecret())
    }

    @Test("Remote secret from the Threema MDM")
    func remoteSecretInThreemaMDM() {
        let mdmSetup = makeMDMSetup(isOnPrem: true)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(mdmSetup.enableRemoteSecret())
    }

    @Test("Overriding Threema MDM wins over the company MDM")
    func remoteSecretInThreemaMDMWithCompanyMDM() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: 0])

        let mdmSetup = makeMDMSetup(isOnPrem: true)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(mdmSetup.enableRemoteSecret())
    }

    @Test("No remote secret in a work environment")
    func remoteSecretInWorkEnvironment() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: 1])

        let mdmSetup = makeMDMSetup(isOnPrem: false)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(!mdmSetup.enableRemoteSecret())
    }

    @Test("No remote secret in a private environment")
    func remoteSecretInPrivateEnvironment() {
        setMDM(company: [MDM_KEY_ENABLE_REMOTE_SECRET: 1])

        let mdmSetup = makeMDMSetup(isBusinessApp: false, isOnPrem: false)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [MDM_KEY_ENABLE_REMOTE_SECRET: 1]),
            sendForce: false
        )

        #expect(!mdmSetup.enableRemoteSecret())
    }

    // MARK: - Loading values

    @Test("Load license info from the company MDM")
    func loadLicenseInfo() {
        setMDM(company: [
            MDM_KEY_LICENSE_USERNAME: "tester",
            MDM_KEY_LICENSE_PASSWORD: "testi123",
        ])

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadLicenseInfo()

        #expect(licenseStore.licenseUsernameSetCount == 1)
        #expect(licenseStore.licenseUsername == "tester")
        #expect(licenseStore.licensePasswordSetCount == 1)
        #expect(licenseStore.licensePassword == "testi123")
    }

    @Test("Load renewable values from the company MDM, leaving the profile untouched")
    func loadRenewableValues() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: false))

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadRenewableValues()

        #expect(licenseStore.licenseUsernameSetCount == 1)
        #expect(licenseStore.licenseUsername == "tester")
        #expect(licenseStore.licensePasswordSetCount == 1)
        #expect(licenseStore.licensePassword == "test1234")

        expectProfileUntouched()

        #expect(mdmSetup.readonlyProfile())
        #expect(userSettings.blockUnknownSetCount == 1)
        #expect(userSettings.blockUnknown)
        #expect(userSettings.syncContactsSetCount == 1)
        #expect(userSettings.syncContacts)

        expectRestrictions(mdmSetup, allEqual: true)

        #expect(mdmSetup.skipWizard())
        #expect(mdmSetup.safeEnable()?.boolValue == true)
        #expect(mdmSetup.safePassword() == "87654321")
        #expect(mdmSetup.safeServerURL() == "http://test.com")
        #expect(mdmSetup.safeServerUsername() == "server-user")
        #expect(mdmSetup.safeServerPassword() == "server-password")
        #expect(!mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == "ECHOECHO")
        #expect(mdmSetup.safePasswordPattern() == "^[0-9]{1,15}$")
        #expect(mdmSetup.safePasswordMessage() == "Wrong-password-pattern")
        #expect(mdmSetup.webHosts() == "threema.ch")
    }

    @Test("Load ID creation values from the company MDM, leaving the license untouched")
    func loadIDCreationValues() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: false))

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadIDCreationValues()

        #expect(licenseStore.licenseUsernameSetCount == 0)
        #expect(licenseStore.licensePasswordSetCount == 0)

        expectProfile(
            pushFromName: "Eieri",
            firstName: "Heiri",
            lastName: "Heirassa",
            csi: "customer-id",
            jobTitle: "jobtitle",
            department: "department",
            category: "category",
            createIDEmail: "linked@email.com",
            createIDPhone: "111"
        )

        #expect(mdmSetup.readonlyProfile())
        #expect(userSettings.blockUnknownSetCount == 0)
        #expect(userSettings.syncContactsSetCount == 1)

        expectRestrictions(mdmSetup, allEqual: true)

        #expect(mdmSetup.skipWizard())
        #expect(mdmSetup.safeEnable()?.boolValue == true)
        #expect(mdmSetup.safePassword() == "87654321")
        #expect(mdmSetup.safeServerURL() == "http://test.com")
        #expect(mdmSetup.safeServerUsername() == "server-user")
        #expect(mdmSetup.safeServerPassword() == "server-password")
        #expect(!mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == "ECHOECHO")
        #expect(mdmSetup.safePasswordPattern() == "^[0-9]{1,15}$")
        #expect(mdmSetup.safePasswordMessage() == "Wrong-password-pattern")
        #expect(mdmSetup.webHosts() == "threema.ch")
    }

    @Test("Repeated load of ID creation values without MDM sets the profile values twice")
    func repeatedLoadIDCreationValuesWithoutMDM() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: false))

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadIDCreationValues()

        setMDM(company: nil, threema: nil)
        mdmSetup.loadIDCreationValues()

        expectProfileSetCounts(2)
    }

    @Test("Repeated load of ID creation values with empty values sets the profile values twice")
    func repeatedLoadIDCreationValuesWithEmptyValues() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: false))

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadIDCreationValues()

        setMDM(company: [
            MDM_KEY_FIRST_NAME: "",
            MDM_KEY_LAST_NAME: "",
            MDM_KEY_CSI: "",
            MDM_KEY_JOB_TITLE: "",
            MDM_KEY_DEPARTMENT: "",
            MDM_KEY_CATEGORY: "",
        ])
        mdmSetup.loadIDCreationValues()

        expectProfileSetCounts(2)
    }

    @Test("Repeated load of ID creation values after removing the MDM sets the profile values twice")
    func repeatedLoadIDCreationValuesAfterMDMRemoval() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: true))

        let mdmSetup = makeMDMSetup()
        mdmSetup.loadIDCreationValues()

        Self.deleteMDM()
        mdmSetup.loadIDCreationValues()

        expectProfileSetCounts(2)
    }

    // MARK: - Applying a Threema MDM

    /// Renewable Threema MDM parameters override the existing company and Threema MDM parameters
    @Test("Apply overriding Threema MDM with existing company and Threema MDM")
    func applyThreemaMDMWithCompanyAndThreemaMDM() {
        setMDM(
            company: Self.allMDMParameters(isThreemaMDM: false),
            threema: Self.threemaMDM(override: true, parameters: Self.allMDMParameters(isThreemaMDM: true))
        )

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: Self.overridingMDMParameters()),
            sendForce: false
        )

        expectOverriddenValues(mdmSetup)
    }

    /// Renewable Threema MDM parameters override the existing company MDM parameters
    @Test("Apply overriding Threema MDM with existing company MDM only")
    func applyThreemaMDMWithCompanyMDMOnly() {
        setMDM(company: Self.allMDMParameters(isThreemaMDM: false))

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: Self.overridingMDMParameters()),
            sendForce: false
        )

        expectOverriddenValues(mdmSetup)
    }

    /// Without existing MDM parameters all renewable Threema MDM parameters are applied
    @Test("Apply overriding Threema MDM without any existing MDM")
    func applyThreemaMDMWithoutExistingMDM() {
        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: Self.overridingMDMParameters()),
            sendForce: false
        )

        // The license of a Threema MDM is never applied
        #expect(licenseStore.licenseUsernameSetCount == 0)
        #expect(licenseStore.licensePasswordSetCount == 0)
        #expect(licenseStore.licenseUsername == nil)
        #expect(licenseStore.licensePassword == nil)

        // The original test asserted `times(0) setPushFromName:@"New-Heiri"`, which passed only because it
        // named the first name: the nickname is renewable, so it is applied
        #expect(myIdentityStore.pushFromNameSetCount == 1)
        #expect(myIdentityStore.pushFromName == "New-Eieri")
        #expect(myIdentityStore.firstNameSetCount == 1)
        #expect(myIdentityStore.firstName == "New-Heiri")
        #expect(myIdentityStore.lastNameSetCount == 1)
        #expect(myIdentityStore.lastName == "New-Heirassa")
        #expect(myIdentityStore.csiSetCount == 1)
        #expect(myIdentityStore.csi == "new-customer-id")
        #expect(myIdentityStore.jobTitleSetCount == 1)
        #expect(myIdentityStore.jobTitle == "new-jobtitle")
        #expect(myIdentityStore.departmentSetCount == 1)
        #expect(myIdentityStore.department == "new-department")
        #expect(myIdentityStore.categorySetCount == 1)
        #expect(myIdentityStore.category == "new-category")
        // Not renewable
        #expect(myIdentityStore.createIDEmailSetCount == 0)
        #expect(myIdentityStore.createIDPhoneSetCount == 0)

        #expect(!mdmSetup.readonlyProfile())
        #expect(userSettings.blockUnknownSetCount == 1)
        #expect(!userSettings.blockUnknown)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN))
        #expect(userSettings.syncContactsSetCount == 2)
        #expect(!userSettings.syncContacts)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC))
        #expect(userSettings.hideStaleContactsSetCount == 1)
        #expect(!userSettings.hideStaleContacts)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_HIDE_INACTIVE_IDS))

        expectRestrictions(mdmSetup, allEqual: false)
        #expect(!mdmSetup.disableShareMedia())
        #expect(!mdmSetup.disableWorkDirectory())

        // Not renewable
        #expect(!mdmSetup.skipWizard())
        #expect(mdmSetup.safeEnable()?.boolValue == false)
        #expect(mdmSetup.safePassword() == nil)
        #expect(mdmSetup.safeServerURL() == "http://new-test.com")
        #expect(mdmSetup.safeServerUsername() == "new-server-user")
        #expect(mdmSetup.safeServerPassword() == "new-server-password")
        // Not renewable
        #expect(mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == nil)
        #expect(mdmSetup.safePasswordPattern() == "new-^[0-9]{1,15}$")
        #expect(mdmSetup.safePasswordMessage() == "New-Wrong-password-pattern")
        #expect(mdmSetup.webHosts() == "new.threema.ch")
    }

    /// Existing Threema MDM parameters that are missing from the new Threema MDM are removed
    @Test("Apply Threema MDM with missing parameters")
    func applyThreemaMDMWithMissingParameters() {
        setMDM(threema: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [
                MDM_KEY_LICENSE_USERNAME: "new-tester",
                MDM_KEY_LICENSE_PASSWORD: "new-test1234",
                MDM_KEY_LINKED_EMAIL: "new-linked@email.com",
                MDM_KEY_LINKED_PHONE: "222",
                MDM_KEY_SKIP_WIZARD: "0",
            ]),
            sendForce: false
        )

        expectRemovedThreemaMDM(mdmSetup)
    }

    /// An empty Threema MDM configuration removes the existing Threema MDM
    @Test("Apply empty Threema MDM")
    func applyEmptyThreemaMDM() {
        setMDM(threema: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm([MDM_KEY_THREEMA_CONFIGURATION: [String: Any]()], sendForce: false)

        expectRemovedThreemaMDM(mdmSetup)
    }

    /// Work data without `MDM_KEY_THREEMA_CONFIGURATION` leaves the MDM unchanged
    @Test("Apply work data without a Threema MDM configuration")
    func applyWorkDataWithoutThreemaConfiguration() {
        setMDM(threema: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm([String: Any](), sendForce: false)

        #expect(licenseStore.licenseUsernameSetCount == 0)
        #expect(licenseStore.licensePasswordSetCount == 0)

        #expect(myIdentityStore.pushFromNameSetCount == 1)
        #expect(myIdentityStore.firstNameSetCount == 1)
        #expect(myIdentityStore.lastNameSetCount == 1)
        #expect(myIdentityStore.csiSetCount == 1)
        #expect(myIdentityStore.jobTitleSetCount == 1)
        #expect(myIdentityStore.departmentSetCount == 1)
        #expect(myIdentityStore.categorySetCount == 1)
        #expect(myIdentityStore.createIDEmailSetCount == 0)
        #expect(myIdentityStore.createIDPhoneSetCount == 0)

        #expect(mdmSetup.readonlyProfile())
        #expect(userSettings.blockUnknownSetCount == 1)
        #expect(userSettings.syncContactsSetCount == 2)

        expectRestrictions(mdmSetup, allEqual: true)

        #expect(!mdmSetup.skipWizard())
        #expect(mdmSetup.safeEnable()?.boolValue == true)
        #expect(mdmSetup.safePassword() == nil)
        #expect(mdmSetup.safeServerURL() == "http://test.com")
        #expect(mdmSetup.safeServerUsername() == "server-user")
        #expect(mdmSetup.safeServerPassword() == "server-password")
        #expect(mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == nil)
        #expect(mdmSetup.safePasswordPattern() == "^[0-9]{1,15}$")
        #expect(mdmSetup.safePasswordMessage() == "Wrong-password-pattern")
        #expect(mdmSetup.webHosts() == "threema.ch")
    }

    /// Adding a Threema MDM to a company MDM: parameters that are not renewable are not applied
    @Test("Apply Threema MDM added to a company MDM")
    func applyThreemaMDMAddedToCompanyMDM() {
        setMDM(company: Self.companyMDMParametersForAddedThreemaMDM())

        let mdmSetup = makeMDMSetup()
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: Self.enablingMDMParameters()),
            sendForce: false
        )

        expectValuesForThreemaMDMAddedToCompanyMDM(mdmSetup)

        // Not renewable, so the company MDM values win
        #expect(!mdmSetup.skipWizard())
        #expect(mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == nil)
    }

    /// Adding a Threema MDM to a company MDM during setup: parameters that are not renewable are applied too
    @Test("Apply Threema MDM added to a company MDM during setup")
    func applyThreemaMDMAddedToCompanyMDMDuringSetup() {
        setMDM(company: Self.companyMDMParametersForAddedThreemaMDM())

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: Self.enablingMDMParameters()),
            sendForce: false
        )

        expectValuesForThreemaMDMAddedToCompanyMDM(mdmSetup)

        #expect(mdmSetup.skipWizard())
        #expect(!mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == "ECHOECHO")
    }

    @Test("License of the company MDM is applied when the Threema MDM has no parameters")
    func applyThreemaMDMWithoutParametersKeepsCompanyMDM() throws {
        setMDM(company: [
            MDM_KEY_ID_BACKUP: "XXXX-XXXX-...",
            MDM_KEY_SAFE_PASSWORD: "12345678",
            MDM_KEY_ID_BACKUP_PASSWORD: "12345678",
            MDM_KEY_LICENSE_USERNAME: "new-tester",
            MDM_KEY_LICENSE_PASSWORD: "new-test1234",
        ])

        let mdmSetup = makeMDMSetup(appSetupState: .notSetup)
        mdmSetup.applyThreemaMdm(
            Self.threemaMDMWorkData(override: true, parameters: [String: Any]()),
            sendForce: false
        )

        #expect(licenseStore.licenseUsernameSetCount == 1)
        #expect(licenseStore.licenseUsername == "new-tester")
        #expect(licenseStore.licensePasswordSetCount == 1)
        #expect(licenseStore.licensePassword == "new-test1234")

        try #require(mdmSetup.hasIDBackup())
        #expect(mdmSetup.idBackup == "XXXX-XXXX-...")
        #expect(mdmSetup.safePassword() == "12345678")
        #expect(mdmSetup.idBackupPassword == "12345678")
    }

    // MARK: - Without a work license

    /// Without a valid work license the renewable MDM settings are not applied
    @Test("No MDM values without a business app")
    func noMDMValuesWithoutBusinessApp() {
        setMDM(threema: Self.threemaMDM(
            override: true,
            parameters: Self.allMDMParameters(isThreemaMDM: true)
        ))

        let mdmSetup = makeMDMSetup(isBusinessApp: false)

        #expect(licenseStore.licenseUsernameSetCount == 0)
        #expect(licenseStore.licensePasswordSetCount == 0)

        expectProfileUntouched()

        #expect(!mdmSetup.readonlyProfile())
        #expect(userSettings.blockUnknownSetCount == 0)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN))
        #expect(userSettings.syncContactsSetCount == 0)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC))
        #expect(userSettings.hideStaleContactsSetCount == 0)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_HIDE_INACTIVE_IDS))

        expectRestrictions(mdmSetup, allEqual: false)

        #expect(!mdmSetup.skipWizard())
        #expect(mdmSetup.safeEnable() == nil)
        #expect(mdmSetup.safePassword() == nil)
        #expect(mdmSetup.safeServerURL() == nil)
        #expect(mdmSetup.safeServerUsername() == nil)
        #expect(mdmSetup.safeServerPassword() == nil)
        #expect(mdmSetup.safeRestoreEnable())
        #expect(mdmSetup.safeRestoreID() == nil)
        #expect(mdmSetup.safePasswordPattern() == nil)
        #expect(mdmSetup.safePasswordMessage() == nil)
        #expect(mdmSetup.webHosts() == nil)
    }

    // MARK: - Shared expectations

    /// The restrictions asserted together in the original tests, all with the same expected value
    private func expectRestrictions(
        _ mdmSetup: MDMSetup,
        allEqual expected: Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(mdmSetup.disableSaveToGallery() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableAddContact() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableExport() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableBackups() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableIDExport() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableSystemBackups() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableMessagePreview() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableSendProfilePicture() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableCalls() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableVideoCalls() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableGroupCalls() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableCreateGroup() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableWeb() == expected, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableMultiDevice() == expected, sourceLocation: sourceLocation)
    }

    private func expectProfile(
        pushFromName: String,
        firstName: String,
        lastName: String,
        csi: String,
        jobTitle: String,
        department: String,
        category: String,
        createIDEmail: String,
        createIDPhone: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(myIdentityStore.pushFromNameSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.pushFromName == pushFromName, sourceLocation: sourceLocation)
        #expect(myIdentityStore.firstNameSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.firstName == firstName, sourceLocation: sourceLocation)
        #expect(myIdentityStore.lastNameSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.lastName == lastName, sourceLocation: sourceLocation)
        #expect(myIdentityStore.csiSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.csi == csi, sourceLocation: sourceLocation)
        #expect(myIdentityStore.jobTitleSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.jobTitle == jobTitle, sourceLocation: sourceLocation)
        #expect(myIdentityStore.departmentSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.department == department, sourceLocation: sourceLocation)
        #expect(myIdentityStore.categorySetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.category == category, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDEmailSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDEmail == createIDEmail, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDPhoneSetCount == 1, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDPhone == createIDPhone, sourceLocation: sourceLocation)
    }

    private func expectProfileUntouched(sourceLocation: SourceLocation = #_sourceLocation) {
        expectProfileSetCounts(0, sourceLocation: sourceLocation)
        #expect(myIdentityStore.pushFromNameSetCount == 0, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDEmailSetCount == 0, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDPhoneSetCount == 0, sourceLocation: sourceLocation)
    }

    /// The set counts of the profile values `loadIDCreationValues` always writes
    private func expectProfileSetCounts(
        _ expected: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(myIdentityStore.firstNameSetCount == expected, sourceLocation: sourceLocation)
        #expect(myIdentityStore.lastNameSetCount == expected, sourceLocation: sourceLocation)
        #expect(myIdentityStore.csiSetCount == expected, sourceLocation: sourceLocation)
        #expect(myIdentityStore.jobTitleSetCount == expected, sourceLocation: sourceLocation)
        #expect(myIdentityStore.departmentSetCount == expected, sourceLocation: sourceLocation)
        #expect(myIdentityStore.categorySetCount == expected, sourceLocation: sourceLocation)
    }

    /// Expectations shared by the two tests applying `overridingMDMParameters()` on top of a company MDM
    private func expectOverriddenValues(
        _ mdmSetup: MDMSetup,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        // The license of a Threema MDM is never applied, so the company MDM values remain
        #expect(licenseStore.licenseUsernameSetCount == 1, sourceLocation: sourceLocation)
        #expect(licenseStore.licenseUsername == "tester", sourceLocation: sourceLocation)
        #expect(licenseStore.licensePasswordSetCount == 1, sourceLocation: sourceLocation)
        #expect(licenseStore.licensePassword == "test1234", sourceLocation: sourceLocation)

        expectProfile(
            pushFromName: "New-Eieri",
            firstName: "New-Heiri",
            lastName: "New-Heirassa",
            csi: "new-customer-id",
            jobTitle: "new-jobtitle",
            department: "new-department",
            category: "new-category",
            // Not renewable
            createIDEmail: "linked@email.com",
            createIDPhone: "111",
            sourceLocation: sourceLocation
        )

        #expect(!mdmSetup.readonlyProfile(), sourceLocation: sourceLocation)
        #expect(userSettings.blockUnknownSetCount == 1, sourceLocation: sourceLocation)
        #expect(!userSettings.blockUnknown, sourceLocation: sourceLocation)
        #expect(userSettings.hideStaleContactsSetCount == 1, sourceLocation: sourceLocation)
        #expect(!userSettings.hideStaleContacts, sourceLocation: sourceLocation)
        #expect(userSettings.syncContactsSetCount == 2, sourceLocation: sourceLocation)
        #expect(!userSettings.syncContacts, sourceLocation: sourceLocation)

        expectRestrictions(mdmSetup, allEqual: false, sourceLocation: sourceLocation)
        #expect(!mdmSetup.disableShareMedia(), sourceLocation: sourceLocation)
        #expect(!mdmSetup.disableWorkDirectory(), sourceLocation: sourceLocation)

        // Not renewable
        #expect(mdmSetup.skipWizard(), sourceLocation: sourceLocation)
        #expect(mdmSetup.safeEnable()?.boolValue == false, sourceLocation: sourceLocation)
        #expect(mdmSetup.safePassword() == "87654321", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerURL() == "http://new-test.com", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerUsername() == "new-server-user", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerPassword() == "new-server-password", sourceLocation: sourceLocation)
        // Not renewable
        #expect(!mdmSetup.safeRestoreEnable(), sourceLocation: sourceLocation)
        #expect(mdmSetup.safeRestoreID() == "ECHOECHO", sourceLocation: sourceLocation)
        #expect(mdmSetup.safePasswordPattern() == "new-^[0-9]{1,15}$", sourceLocation: sourceLocation)
        #expect(
            mdmSetup.safePasswordMessage() == "New-Wrong-password-pattern",
            sourceLocation: sourceLocation
        )
        #expect(mdmSetup.webHosts() == "new.threema.ch", sourceLocation: sourceLocation)
    }

    /// Expectations shared by the two tests removing an existing Threema MDM
    private func expectRemovedThreemaMDM(
        _ mdmSetup: MDMSetup,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(licenseStore.licenseUsernameSetCount == 0, sourceLocation: sourceLocation)
        #expect(licenseStore.licensePasswordSetCount == 0, sourceLocation: sourceLocation)
        #expect(licenseStore.licenseUsername == nil, sourceLocation: sourceLocation)
        #expect(licenseStore.licensePassword == nil, sourceLocation: sourceLocation)

        #expect(myIdentityStore.pushFromNameSetCount == 0, sourceLocation: sourceLocation)
        // Not renewable
        #expect(myIdentityStore.createIDEmailSetCount == 0, sourceLocation: sourceLocation)
        #expect(myIdentityStore.createIDPhoneSetCount == 0, sourceLocation: sourceLocation)
        expectProfileSetCounts(1, sourceLocation: sourceLocation)

        #expect(!mdmSetup.readonlyProfile(), sourceLocation: sourceLocation)
        #expect(userSettings.blockUnknownSetCount == 0, sourceLocation: sourceLocation)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN), sourceLocation: sourceLocation)
        #expect(userSettings.syncContactsSetCount == 0, sourceLocation: sourceLocation)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC), sourceLocation: sourceLocation)
        #expect(userSettings.hideStaleContactsSetCount == 0, sourceLocation: sourceLocation)
        #expect(!mdmSetup.existsMdmKey(MDM_KEY_HIDE_INACTIVE_IDS), sourceLocation: sourceLocation)

        expectRestrictions(mdmSetup, allEqual: false, sourceLocation: sourceLocation)

        #expect(!mdmSetup.skipWizard(), sourceLocation: sourceLocation)
        #expect(mdmSetup.safeEnable() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safePassword() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerURL() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerUsername() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerPassword() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safeRestoreEnable(), sourceLocation: sourceLocation)
        #expect(mdmSetup.safeRestoreID() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safePasswordPattern() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.safePasswordMessage() == nil, sourceLocation: sourceLocation)
        #expect(mdmSetup.webHosts() == nil, sourceLocation: sourceLocation)
    }

    /// Expectations shared by the two tests adding `enablingMDMParameters()` to a company MDM, without the
    /// values that differ between a "normal" and a "setup" sync
    private func expectValuesForThreemaMDMAddedToCompanyMDM(
        _ mdmSetup: MDMSetup,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(licenseStore.licenseUsernameSetCount == 1, sourceLocation: sourceLocation)
        #expect(licenseStore.licenseUsername == "company-tester", sourceLocation: sourceLocation)
        #expect(licenseStore.licensePasswordSetCount == 1, sourceLocation: sourceLocation)
        #expect(licenseStore.licensePassword == "company-test1234", sourceLocation: sourceLocation)

        expectProfile(
            pushFromName: "Eieri",
            firstName: "Heiri",
            lastName: "Heirassa",
            csi: "customer-id",
            jobTitle: "jobtitle",
            department: "department",
            category: "category",
            // Not renewable
            createIDEmail: "company-linked@email.com",
            createIDPhone: "555",
            sourceLocation: sourceLocation
        )

        #expect(mdmSetup.readonlyProfile(), sourceLocation: sourceLocation)
        #expect(userSettings.blockUnknownSetCount == 1, sourceLocation: sourceLocation)
        #expect(userSettings.blockUnknown, sourceLocation: sourceLocation)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_BLOCK_UNKNOWN), sourceLocation: sourceLocation)
        #expect(userSettings.syncContactsSetCount == 2, sourceLocation: sourceLocation)
        #expect(userSettings.syncContacts, sourceLocation: sourceLocation)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC), sourceLocation: sourceLocation)
        #expect(userSettings.hideStaleContactsSetCount == 1, sourceLocation: sourceLocation)
        #expect(userSettings.hideStaleContacts, sourceLocation: sourceLocation)
        #expect(mdmSetup.existsMdmKey(MDM_KEY_HIDE_INACTIVE_IDS), sourceLocation: sourceLocation)

        expectRestrictions(mdmSetup, allEqual: true, sourceLocation: sourceLocation)
        #expect(mdmSetup.disableShareMedia(), sourceLocation: sourceLocation)
        #expect(mdmSetup.disableWorkDirectory(), sourceLocation: sourceLocation)

        #expect(mdmSetup.safeEnable()?.boolValue == true, sourceLocation: sourceLocation)
        #expect(mdmSetup.safePassword() == "12345678", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerURL() == "http://test.com", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerUsername() == "server-user", sourceLocation: sourceLocation)
        #expect(mdmSetup.safeServerPassword() == "server-password", sourceLocation: sourceLocation)
        #expect(mdmSetup.safePasswordPattern() == "^[0-9]{1,15}$", sourceLocation: sourceLocation)
        #expect(
            mdmSetup.safePasswordMessage() == "Wrong-password-pattern",
            sourceLocation: sourceLocation
        )
        #expect(mdmSetup.webHosts() == "new.threema.ch", sourceLocation: sourceLocation)
    }

    // MARK: - Helpers

    private func makeMDMSetup(
        appSetupState: AppSetupState = .complete,
        isBusinessApp: Bool = true,
        isOnPrem: Bool = false
    ) -> MDMSetup {
        MDMSetup(
            forTestWithAppSetupStateRawValue: appSetupState.rawValue,
            isBusinessApp: isBusinessApp,
            isOnPrem: isOnPrem,
            userSettings: userSettings,
            licenseStore: licenseStore,
            myIdentityStore: myIdentityStore
        )
    }

    /// Stores the passed MDMs, `nil` leaves that MDM untouched
    ///
    /// Deliberately does not clear the MDM caches of `MDMSetup`, matching the original tests: they are only
    /// cleared between tests and by `setEmptyMDM`, so a second call within a test has no effect on an
    /// `MDMSetup` that already read its configuration.
    private func setMDM(company: [String: Any]? = nil, threema: [String: Any]? = nil) {
        if let company {
            UserDefaults.standard.set(company, forKey: MDM_CONFIGURATION_KEY)
        }
        if let threema {
            AppGroup.userDefaults().set(threema, forKey: MDM_THREEMA_CONFIGURATION_KEY)
        }
    }

    private static func deleteMDM() {
        UserDefaults.standard.removeObject(forKey: MDM_CONFIGURATION_KEY)
        AppGroup.userDefaults().removeObject(forKey: MDM_THREEMA_CONFIGURATION_KEY)
        MDMSetup.clearMdmCache()
    }

    /// A Threema MDM as it is stored in the app group user defaults
    private static func threemaMDM(override: Bool, parameters: [String: Any]) -> [String: Any] {
        [
            MDM_KEY_THREEMA_OVERRIDE: override,
            MDM_KEY_THREEMA_PARAMS: parameters,
        ]
    }

    /// A Threema MDM as it arrives in the work data
    private static func threemaMDMWorkData(override: Bool, parameters: [String: Any]) -> [String: Any] {
        [MDM_KEY_THREEMA_CONFIGURATION: threemaMDM(override: override, parameters: parameters)]
    }

    /// All MDM parameters, with the Safe password added for a company MDM
    private static func allMDMParameters(isThreemaMDM: Bool) -> [String: Any] {
        var parameters: [String: Any] = [
            MDM_KEY_LICENSE_USERNAME: "tester",
            MDM_KEY_LICENSE_PASSWORD: "test1234",
            MDM_KEY_NICKNAME: "Eieri",
            MDM_KEY_FIRST_NAME: "Heiri",
            MDM_KEY_LAST_NAME: "Heirassa",
            MDM_KEY_CSI: "customer-id",
            MDM_KEY_JOB_TITLE: "jobtitle",
            MDM_KEY_DEPARTMENT: "department",
            MDM_KEY_CATEGORY: "category",
            MDM_KEY_LINKED_EMAIL: "linked@email.com",
            MDM_KEY_LINKED_PHONE: "111",
            MDM_KEY_CONTACT_SYNC: "1",
            MDM_KEY_READONLY_PROFILE: "1",
            MDM_KEY_BLOCK_UNKNOWN: "1",
            MDM_KEY_HIDE_INACTIVE_IDS: "1",
            MDM_KEY_DISABLE_SAVE_TO_GALLERY: "1",
            MDM_KEY_DISABLE_ADD_CONTACT: "1",
            MDM_KEY_DISABLE_EXPORT: "1",
            MDM_KEY_DISABLE_BACKUPS: "1",
            MDM_KEY_DISABLE_ID_EXPORT: "1",
            MDM_KEY_DISABLE_SYSTEM_BACKUPS: "1",
            MDM_KEY_DISABLE_MESSAGE_PREVIEW: "1",
            MDM_KEY_DISABLE_SEND_PROFILE_PICTURE: "1",
            MDM_KEY_DISABLE_CALLS: "1",
            MDM_KEY_DISABLE_VIDEO_CALLS: "1",
            MDM_KEY_DISABLE_GROUP_CALLS: "1",
            MDM_KEY_SKIP_WIZARD: "1",
            MDM_KEY_DISABLE_CREATE_GROUP: "1",
            MDM_KEY_DISABLE_WEB: "1",
            MDM_KEY_DISABLE_MULTIDEVICE: "1",
            MDM_KEY_SAFE_ENABLE: NSNumber(value: 1),
            MDM_KEY_SAFE_SERVER_URL: "http://test.com",
            MDM_KEY_SAFE_SERVER_USERNAME: "server-user",
            MDM_KEY_SAFE_SERVER_PASSWORD: "server-password",
            MDM_KEY_SAFE_RESTORE_ENABLE: "0",
            MDM_KEY_SAFE_RESTORE_ID: "ECHOECHO",
            MDM_KEY_SAFE_PASSWORD_PATTERN: "^[0-9]{1,15}$",
            MDM_KEY_SAFE_PASSWORD_MESSAGE: "Wrong-password-pattern",
            MDM_KEY_WEB_HOSTS: "threema.ch",
            MDM_KEY_DISABLE_SHARE_MEDIA: "1",
            MDM_KEY_DISABLE_WORK_DIRECTORY: "1",
            MDM_KEY_KEEP_MESSAGE_DAYS: "7",
        ]

        if !isThreemaMDM {
            parameters[MDM_KEY_SAFE_PASSWORD] = "87654321"
        }

        return parameters
    }

    /// All renewable parameters with values differing from `allMDMParameters(isThreemaMDM:)`, to check that
    /// they override existing ones
    private static func overridingMDMParameters() -> [String: Any] {
        [
            MDM_KEY_LICENSE_USERNAME: "new-tester",
            MDM_KEY_LICENSE_PASSWORD: "new-test1234",
            MDM_KEY_NICKNAME: "New-Eieri",
            MDM_KEY_FIRST_NAME: "New-Heiri",
            MDM_KEY_LAST_NAME: "New-Heirassa",
            MDM_KEY_CSI: "new-customer-id",
            MDM_KEY_JOB_TITLE: "new-jobtitle",
            MDM_KEY_DEPARTMENT: "new-department",
            MDM_KEY_CATEGORY: "new-category",
            MDM_KEY_LINKED_EMAIL: "new-linked@email.com",
            MDM_KEY_LINKED_PHONE: "222",
            MDM_KEY_CONTACT_SYNC: "0",
            MDM_KEY_READONLY_PROFILE: "0",
            MDM_KEY_BLOCK_UNKNOWN: "0",
            MDM_KEY_HIDE_INACTIVE_IDS: "0",
            MDM_KEY_DISABLE_SAVE_TO_GALLERY: "0",
            MDM_KEY_DISABLE_ADD_CONTACT: "0",
            MDM_KEY_DISABLE_EXPORT: "0",
            MDM_KEY_DISABLE_BACKUPS: "0",
            MDM_KEY_DISABLE_ID_EXPORT: "0",
            MDM_KEY_DISABLE_SYSTEM_BACKUPS: "0",
            MDM_KEY_DISABLE_MESSAGE_PREVIEW: "0",
            MDM_KEY_DISABLE_SEND_PROFILE_PICTURE: "0",
            MDM_KEY_DISABLE_CALLS: "0",
            MDM_KEY_DISABLE_VIDEO_CALLS: "0",
            MDM_KEY_DISABLE_GROUP_CALLS: "0",
            MDM_KEY_SKIP_WIZARD: "0",
            MDM_KEY_DISABLE_CREATE_GROUP: "0",
            MDM_KEY_DISABLE_WEB: "0",
            MDM_KEY_DISABLE_MULTIDEVICE: "0",
            MDM_KEY_SAFE_ENABLE: NSNumber(value: 0),
            MDM_KEY_SAFE_SERVER_URL: "http://new-test.com",
            MDM_KEY_SAFE_SERVER_USERNAME: "new-server-user",
            MDM_KEY_SAFE_SERVER_PASSWORD: "new-server-password",
            MDM_KEY_SAFE_RESTORE_ENABLE: "1",
            MDM_KEY_SAFE_RESTORE_ID: "EINSZWEI",
            MDM_KEY_SAFE_PASSWORD_PATTERN: "new-^[0-9]{1,15}$",
            MDM_KEY_SAFE_PASSWORD_MESSAGE: "New-Wrong-password-pattern",
            MDM_KEY_WEB_HOSTS: "new.threema.ch",
            MDM_KEY_DISABLE_SHARE_MEDIA: "0",
            MDM_KEY_DISABLE_WORK_DIRECTORY: "0",
        ]
    }

    /// The Threema MDM parameters added to `companyMDMParametersForAddedThreemaMDM()`, enabling every
    /// restriction
    private static func enablingMDMParameters() -> [String: Any] {
        [
            MDM_KEY_NICKNAME: "Eieri",
            MDM_KEY_FIRST_NAME: "Heiri",
            MDM_KEY_LAST_NAME: "Heirassa",
            MDM_KEY_CSI: "customer-id",
            MDM_KEY_JOB_TITLE: "jobtitle",
            MDM_KEY_DEPARTMENT: "department",
            MDM_KEY_CATEGORY: "category",
            MDM_KEY_CONTACT_SYNC: "1",
            MDM_KEY_READONLY_PROFILE: "1",
            MDM_KEY_BLOCK_UNKNOWN: "1",
            MDM_KEY_HIDE_INACTIVE_IDS: "1",
            MDM_KEY_DISABLE_SAVE_TO_GALLERY: "1",
            MDM_KEY_DISABLE_ADD_CONTACT: "1",
            MDM_KEY_DISABLE_EXPORT: "1",
            MDM_KEY_DISABLE_BACKUPS: "1",
            MDM_KEY_DISABLE_ID_EXPORT: "1",
            MDM_KEY_DISABLE_SYSTEM_BACKUPS: "1",
            MDM_KEY_DISABLE_MESSAGE_PREVIEW: "1",
            MDM_KEY_DISABLE_SEND_PROFILE_PICTURE: "1",
            MDM_KEY_DISABLE_CALLS: "1",
            MDM_KEY_DISABLE_VIDEO_CALLS: "1",
            MDM_KEY_DISABLE_GROUP_CALLS: "1",
            MDM_KEY_SKIP_WIZARD: "1",
            MDM_KEY_DISABLE_CREATE_GROUP: "1",
            MDM_KEY_DISABLE_WEB: "1",
            MDM_KEY_DISABLE_MULTIDEVICE: "1",
            MDM_KEY_SAFE_ENABLE: NSNumber(value: 1),
            MDM_KEY_SAFE_SERVER_URL: "http://test.com",
            MDM_KEY_SAFE_SERVER_USERNAME: "server-user",
            MDM_KEY_SAFE_SERVER_PASSWORD: "server-password",
            MDM_KEY_SAFE_RESTORE_ENABLE: "0",
            MDM_KEY_SAFE_RESTORE_ID: "ECHOECHO",
            MDM_KEY_SAFE_PASSWORD_PATTERN: "^[0-9]{1,15}$",
            MDM_KEY_SAFE_PASSWORD_MESSAGE: "Wrong-password-pattern",
            MDM_KEY_WEB_HOSTS: "new.threema.ch",
            MDM_KEY_DISABLE_SHARE_MEDIA: "1",
            MDM_KEY_DISABLE_WORK_DIRECTORY: "1",
        ]
    }

    /// A company MDM with only parameters that are not renewable, so a Threema MDM adds to it
    private static func companyMDMParametersForAddedThreemaMDM() -> [String: Any] {
        [
            MDM_KEY_LICENSE_USERNAME: "company-tester",
            MDM_KEY_LICENSE_PASSWORD: "company-test1234",
            MDM_KEY_LINKED_EMAIL: "company-linked@email.com",
            MDM_KEY_LINKED_PHONE: "555",
            MDM_KEY_SKIP_WIZARD: "0",
            MDM_KEY_SAFE_PASSWORD: "12345678",
        ]
    }

    // MARK: - Test cases

    /// A value of an MDM dictionary
    ///
    /// Keeps the value types of the original tests — an MDM may deliver a boolean as a number or as a
    /// string — while staying `Sendable`, which test case arguments must be.
    enum MDMValue: Sendable {
        case string(String)
        case number(Int)

        var value: Any {
            switch self {
            case let .string(string): string
            case let .number(number): NSNumber(value: number)
            }
        }
    }

    struct SafeSetupCase: Sendable, CustomTestStringConvertible {
        let name: String
        let companyMDM: [String: MDMValue]
        let expected: SafeSetupState

        var testDescription: String { name }
    }

    struct SafeSetupState: Sendable {
        var backupDisable = false
        var backupForce = false
        var backupPasswordPreset = false
        var backupServerPreset = false
        var restoreDisable = false
        var restoreForce = false
        var restorePasswordPreset = false
        var restoreServerPreset = false
    }
}
