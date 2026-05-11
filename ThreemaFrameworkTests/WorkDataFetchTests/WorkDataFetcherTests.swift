import Testing
@testable import ThreemaFramework

@Suite("WorkDataFetcher Tests")
struct WorkDataFetcherTests {
    
    // MARK: - Test Context Structure
    
    struct TestContext {
        let testDatabase: TestDatabase
        let contactStoreMock: WorkFetcherContactStoreMock
        let appFlavorServiceMock: MockAppFlavorService
        let mdmSetupMock: MDMSetupMock
        let mdmFetcherMock: WorkDataThreemaMDMFetcherMock
        let apiRequestMock: ServerAPIRequestMock
        let userDefaults: UserDefaults
        let licenseStoreMock: LicenseStoreMock
        let myIdentityStoreMock: MyIdentityStoreMock
        let userSettingsMock: UserSettingsMock
        let serverInfoProviderMock: ServerInfoProviderMock

        init() {
            self.testDatabase = TestDatabase()
            self.contactStoreMock = WorkFetcherContactStoreMock()
            self.appFlavorServiceMock = MockAppFlavorService()
            self.mdmSetupMock = MDMSetupMock()
            self.mdmFetcherMock = WorkDataThreemaMDMFetcherMock()
            self.apiRequestMock = ServerAPIRequestMock()
            self.userDefaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
            self.licenseStoreMock = LicenseStoreMock()
            self.myIdentityStoreMock = MyIdentityStoreMock()
            self.userSettingsMock = UserSettingsMock()
            self.serverInfoProviderMock = ServerInfoProviderMock(baseURLString: "https://example.com")
        }
        
        func createFetcher() -> WorkDataFetcher {
            let apiCaller = WorkDataAPICaller(
                username: "test",
                password: "test",
                serverAPIRequest: apiRequestMock
            )
            
            return WorkDataFetcher(
                contactStore: contactStoreMock,
                licenseStore: licenseStoreMock,
                identityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                userDefaults: userDefaults,
                serverInfoProvider: serverInfoProviderMock,
                appFlavorService: appFlavorServiceMock,
                entityManager: testDatabase.entityManager,
                mdmSetup: mdmSetupMock,
                workDataAPICaller: apiCaller,
                workDataThreemaMDMFetcher: mdmFetcherMock
            )
        }
        
        func createValidWorkDataResponse() -> Data {
            let response: [String: Any] = [
                "checkInterval": 3600,
                "org": ["name": "Test Org"],
                "logo": ["light": "https://example.com/light.png", "dark": "https://example.com/dark.png"],
                "support": "https://support.example.com",
                "contacts": [
                    [
                        "id": "TESTID01",
                        "pk": "dGVzdHB1YmxpY2tleQ==",
                        "first": "John",
                        "last": "Doe",
                        "csi": "CSI123",
                        "jobTitle": "Developer",
                        "department": "Engineering",
                    ],
                ],
            ]
            return try! JSONSerialization.data(withJSONObject: response)
        }
        
        func cleanup() {
            // No cleanup needed for LicenseStoreMock
        }
    }
    
    // MARK: - Business App Validation Tests
    
    @Test("CheckUpdate with non-business app returns early")
    func checkUpdateWithNonBusinessAppReturnsEarly() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = false
        context.licenseStoreMock.licenseUsername = "testUser"
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: false, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 0)
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 0)
        #expect(context.contactStoreMock.batchAddWorkContactsCallCount == 0)
    }
    
    @Test("CheckUpdate with non-business app does not call API")
    func checkUpdateWithNonBusinessAppDoesNotCallAPI() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = false
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 0)
    }
    
    // MARK: - Sync Interval Gate Tests
    
    @Test("CheckUpdate with force true bypasses interval check")
    func checkUpdateWithForceTrueBypassesIntervalCheck() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Set last sync to very recent (should normally skip)
        context.userDefaults.set(Date.now, forKey: "WorkDataLastSync")
        context.userDefaults.set(86400.0, forKey: "WorkDataCheckInterval")
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Should call API despite recent sync
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    @Test("CheckUpdate with force true calls API")
    func checkUpdateWithForceTrueCallsAPI() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    @Test("CheckUpdate with force false within interval skips sync")
    func checkUpdateWithForceFalseWithinIntervalSkipsSync() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Set last sync to 1 hour ago with 24 hour interval
        context.userDefaults.set(Date.now.addingTimeInterval(-3600), forKey: "WorkDataLastSync")
        context.userDefaults.set(86400.0, forKey: "WorkDataCheckInterval")
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: false, forceSendMDM: false)
        
        // Should skip sync
        #expect(context.apiRequestMock.postJSONCallCount == 0)
    }
    
    @Test("CheckUpdate with force false past interval syncs")
    func checkUpdateWithForceFalsePastIntervalSyncs() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Set last sync to 25 hours ago with 24 hour interval
        context.userDefaults.set(Date.now.addingTimeInterval(-90000), forKey: "WorkDataLastSync")
        context.userDefaults.set(86400.0, forKey: "WorkDataCheckInterval")
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: false, forceSendMDM: false)
        
        // Should sync
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    @Test("CheckUpdate with no last sync syncs")
    func checkUpdateWithNoLastSyncSyncs() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // No last sync recorded
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: false, forceSendMDM: false)
        
        // Should sync
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    // MARK: - License Username Validation Tests
    
    @Test("CheckUpdate with nil license username returns early")
    func checkUpdateWithNilLicenseUsernameReturnsEarly() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = nil
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 0)
    }
    
    @Test("CheckUpdate with valid username proceeds with sync")
    func checkUpdateWithValidUsernameProceedsWithSync() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    // MARK: - API Call Tests
    
    @Test("CheckUpdate success calls API with contact IDs")
    func checkUpdateSuccessCallsAPIWithContactIDs() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Add some test contacts to entity manager
        context.testDatabase.entityManager.performAndWaitSave {
            let publicKey1 = Data(repeating: 0x01, count: 32)
            _ = context.testDatabase.entityManager.entityCreator.contactEntity(
                identity: "CONTACT1",
                publicKey: publicKey1,
                sortOrderFirstName: true
            )
            
            let publicKey2 = Data(repeating: 0x02, count: 32)
            _ = context.testDatabase.entityManager.entityCreator.contactEntity(
                identity: "CONTACT2",
                publicKey: publicKey2,
                sortOrderFirstName: true
            )
        }
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.apiRequestMock.postJSONCallCount == 1)
        let capturedContacts = context.apiRequestMock.capturedData?["contacts"] as? [String]
        #expect(capturedContacts != nil)
        #expect(capturedContacts?.contains("CONTACT1") ?? false)
        #expect(capturedContacts?.contains("CONTACT2") ?? false)
    }
    
    @Test("CheckUpdate success parses response")
    func checkUpdateSuccessParsesResponse() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        // Should not throw
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Verify API was called
        #expect(context.apiRequestMock.postJSONCallCount == 1)
    }
    
    @Test("CheckUpdate with API error propagates error")
    func checkUpdateWithAPIErrorPropagatesError() async {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let apiError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        context.apiRequestMock.mockError = apiError
        
        let fetcher = context.createFetcher()
        
        do {
            _ = try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
            Issue.record("Expected error to be thrown")
        }
        catch {
            let nsError = error as NSError
            #expect(nsError.domain == NSURLErrorDomain)
            #expect(nsError.code == NSURLErrorNotConnectedToInternet)
        }
    }
    
    // MARK: - MDM Application Tests
    
    @Test("CheckUpdate success delegates to MDM fetcher")
    func checkUpdateSuccessDelegatesToMDMFetcher() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 1)
    }
    
    @Test("CheckUpdate with MDM error propagates error")
    func checkUpdateWithMDMErrorPropagatesError() async {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let mdmError = WorkDataFetchError.serverError("MDM processing failed")
        context.mdmFetcherMock.shouldThrowProcessAndApplyError = mdmError
        
        let fetcher = context.createFetcher()
        
        do {
            _ = try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
            Issue.record("Expected WorkDataFetchError.serverError to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case let .serverError(message) = error else {
                Issue.record("Expected serverError but got \(error)")
                return
            }
            #expect(message == "MDM processing failed")
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
    }
    
    @Test("CheckUpdate success passes same data to MDM")
    func checkUpdateSuccessPassesSameDataToMDM() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Verify data was passed to MDM fetcher
        #expect(context.mdmFetcherMock.capturedProcessData != nil)
        
        // Compare JSON content instead of Data bytes (serialization may differ)
        let originalJSON = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        let capturedJSON = try JSONSerialization
            .jsonObject(with: context.mdmFetcherMock.capturedProcessData!) as? [String: Any]
        
        #expect(originalJSON?["checkInterval"] as? Int == capturedJSON?["checkInterval"] as? Int)
        #expect(
            (originalJSON?["org"] as? [String: Any])?["name"] as? String ==
                (capturedJSON?["org"] as? [String: Any])?["name"] as? String
        )
    }
    
    // MARK: - Logo Application Tests
    
    @Test("ApplyLogo with light and dark sets URLs")
    func applyLogoWithLightAndDarkSetsURLs() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "logo": [
                "light": "https://example.com/light.png",
                "dark": "https://example.com/dark.png",
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let identityStoreMock = context.myIdentityStoreMock
        #expect(identityStoreMock.licenseLogoLightURL == "https://example.com/light.png")
        #expect(identityStoreMock.licenseLogoDarkURL == "https://example.com/dark.png")
    }
    
    @Test("ApplyLogo with nil logo clears URLs")
    func applyLogoWithNilLogoClearsURLs() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let identityStoreMock = context.myIdentityStoreMock
        identityStoreMock.licenseLogoLightURL = "https://old.com/light.png"
        identityStoreMock.licenseLogoDarkURL = "https://old.com/dark.png"
        
        let response: [String: Any] = [:] // No logo
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(identityStoreMock.licenseLogoLightURL == nil)
        #expect(identityStoreMock.licenseLogoDarkURL == nil)
    }
    
    @Test("ApplyLogo with only light URL sets both correctly")
    func applyLogoWithOnlyLightURLSetsBothCorrectly() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "logo": [
                "light": "https://example.com/light.png",
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let identityStoreMock = context.myIdentityStoreMock
        #expect(identityStoreMock.licenseLogoLightURL == "https://example.com/light.png")
        #expect(identityStoreMock.licenseLogoDarkURL == nil)
    }
    
    // MARK: - Support URL Application Tests
    
    @Test("ApplySupportURL with URL sets in identity store")
    func applySupportURLWithURLSetsInIdentityStore() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "support": "https://support.example.com",
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let myIdentityStoreMock = context.myIdentityStoreMock
        #expect(myIdentityStoreMock.licenseSupportURL == "https://support.example.com")
    }
    
    @Test("ApplySupportURL with nil clears URL")
    func applySupportURLWithNilClearsURL() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let myIdentityStoreMock = context.myIdentityStoreMock
        myIdentityStoreMock.licenseSupportURL = "https://old-support.com"

        let response: [String: Any] = [:] // No support URL
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(myIdentityStoreMock.licenseSupportURL == nil)
    }
    
    // MARK: - Organization Application Tests (Parameterized)
    
    @Test(
        "ApplyOrganization with various configurations",
        arguments: [
            (
                org: ["name": "Acme Corporation"] as [String: Any]?,
                expected: "Acme Corporation" as String?,
                description: "with name"
            ),
            (org: nil, expected: nil, description: "with nil org"),
            (org: [:], expected: nil, description: "with nil name"),
        ]
    )
    func applyOrganizationWithVariousConfigurations(
        org: [String: Any]?,
        expected: String?,
        description: String
    ) async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let myIdentityStoreMock = context.myIdentityStoreMock
        myIdentityStoreMock.companyName = "Old Company"

        var response: [String: Any] = [:]
        if let org {
            response["org"] = org
        }
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(myIdentityStoreMock.companyName == expected, "Failed for \(description)")
    }
    
    // MARK: - Contact Batch Add Tests
    
    @Test("CheckUpdate with contacts batch adds contacts")
    func checkUpdateWithContactsBatchAddsContacts() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "contacts": [
                [
                    "id": "TESTID01",
                    "pk": "dGVzdHB1YmxpY2tleQ==",
                    "first": "John",
                    "last": "Doe",
                ],
                [
                    "id": "TESTID02",
                    "pk": "YW5vdGhlcnB1YmxpY2tleQ==",
                    "first": "Jane",
                    "last": "Smith",
                ],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.contactStoreMock.batchAddWorkContactsCallCount == 1)
        #expect(context.contactStoreMock.capturedBatchContacts?.count == 2)
        #expect(context.contactStoreMock.capturedBatchContacts?[0].identity == "TESTID01")
        #expect(context.contactStoreMock.capturedBatchContacts?[1].identity == "TESTID02")
    }
    
    @Test("CheckUpdate with no contacts skips batch add")
    func checkUpdateWithNoContactsSkipsBatchAdd() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [:] // No contacts
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        #expect(context.contactStoreMock.batchAddWorkContactsCallCount == 0)
    }
    
    @Test("CheckUpdate with empty contacts array calls batch add with empty array")
    func checkUpdateWithEmptyContactsArrayCallsBatchAddWithEmptyArray() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "contacts": [], // Empty array
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Empty array still triggers batch add (with empty array)
        #expect(context.contactStoreMock.batchAddWorkContactsCallCount == 1)
        #expect(context.contactStoreMock.capturedBatchContacts?.isEmpty == true)
    }
    
    @Test("CheckUpdate with multiple contacts converts correctly")
    func checkUpdateWithMultipleContactsConvertsCorrectly() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "contacts": [
                [
                    "id": "TESTID01",
                    "pk": "dGVzdHB1YmxpY2tleQ==",
                    "first": "John",
                    "last": "Doe",
                    "csi": "CSI123",
                    "jobTitle": "Developer",
                    "department": "Engineering",
                ],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let contact = context.contactStoreMock.capturedBatchContacts?[0]
        #expect(contact?.identity == "TESTID01")
        #expect(contact?.firstName == "John")
        #expect(contact?.lastName == "Doe")
        #expect(contact?.csi == "CSI123")
        #expect(contact?.jobTitle == "Developer")
        #expect(contact?.department == "Engineering")
        #expect(contact?.publicKey != nil)
    }
    
    // MARK: - Sync Recording Tests (Parameterized)
    
    @Test(
        "RecordSync with various check intervals",
        arguments: [
            (interval: nil as Int?, expected: 86400.0, description: "no interval uses default"),
            (interval: 7200, expected: 7200.0, description: "server interval uses server value"),
            (interval: -100, expected: 86400.0, description: "negative interval uses default"),
            (interval: 0, expected: 86400.0, description: "zero interval uses default"),
        ]
    )
    func recordSyncWithVariousCheckIntervals(
        interval: Int?,
        expected: Double,
        description: String
    ) async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        var response: [String: Any] = [:]
        if let interval {
            response["checkInterval"] = interval
        }
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let savedInterval = context.userDefaults.double(forKey: "WorkDataCheckInterval")
        #expect(savedInterval == expected, "Failed for \(description)")
    }
    
    @Test("RecordSync saves last sync date")
    func recordSyncSavesLastSyncDate() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [:]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        let beforeSync = Date.now
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let savedDate = context.userDefaults.object(forKey: "WorkDataLastSync") as? Date
        #expect(savedDate != nil)
        #expect(savedDate! >= beforeSync)
    }
    
    // MARK: - Integration Tests
    
    @Test("CheckUpdate end-to-end success")
    func checkUpdateEndToEndSuccess() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Verify all components were called
        #expect(context.apiRequestMock.postJSONCallCount == 1)
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 1)
        #expect(context.contactStoreMock.batchAddWorkContactsCallCount == 1)
        
        // Verify data was applied
        let myIdentityStoreMock = context.myIdentityStoreMock
        #expect(myIdentityStoreMock.companyName == "Test Org")
        #expect(myIdentityStoreMock.licenseLogoLightURL != nil)
        #expect(myIdentityStoreMock.licenseSupportURL != nil)

        // Verify sync was recorded
        #expect(context.userDefaults.object(forKey: "WorkDataLastSync") != nil)
    }
    
    @Test("CheckUpdate end-to-end with complete response")
    func checkUpdateEndToEndWithCompleteResponse() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "checkInterval": 3600,
            "org": ["name": "Complete Org"],
            "logo": [
                "light": "https://example.com/light.png",
                "dark": "https://example.com/dark.png",
            ],
            "support": "https://support.example.com",
            "contacts": [
                [
                    "id": "COMPLETE1",
                    "pk": "Y29tcGxldGVwdWJsaWNrZXk=",
                    "first": "Complete",
                    "last": "Test",
                    "csi": "CSI999",
                    "jobTitle": "Tester",
                    "department": "QA",
                ],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Verify all fields were applied
        let myIdentityStoreMock = context.myIdentityStoreMock
        #expect(myIdentityStoreMock.companyName == "Complete Org")
        #expect(myIdentityStoreMock.licenseLogoLightURL == "https://example.com/light.png")
        #expect(myIdentityStoreMock.licenseLogoDarkURL == "https://example.com/dark.png")
        #expect(myIdentityStoreMock.licenseSupportURL == "https://support.example.com")

        let contact = context.contactStoreMock.capturedBatchContacts?[0]
        #expect(contact?.identity == "COMPLETE1")
        #expect(contact?.firstName == "Complete")
        #expect(contact?.jobTitle == "Tester")
    }
    
    @Test("CheckUpdate end-to-end with minimal response")
    func checkUpdateEndToEndWithMinimalResponse() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [:] // Minimal response
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        // Should not throw
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Verify API was called
        #expect(context.apiRequestMock.postJSONCallCount == 1)
        
        // Verify MDM was called (even with minimal response)
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 1)
    }
    
    // MARK: - ForceSendMDM Parameter Tests (Parameterized)
    
    @Test(
        "CheckUpdate passes forceSendMDM parameter to MDM fetcher correctly",
        arguments: [
            (forceSendMDM: true, description: "force send MDM true"),
            (forceSendMDM: false, description: "force send MDM false"),
        ]
    )
    func checkUpdatePassesForceSendMDMToMDMFetcher(forceSendMDM: Bool, description: String) async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: forceSendMDM)
        
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 1, "Failed for \(description)")
        #expect(context.mdmFetcherMock.capturedForceSend == forceSendMDM, "Failed for \(description)")
    }
    
    @Test("CheckUpdate without forceSendMDM defaults to false")
    func checkUpdateWithoutForceSendMDMDefaultsToFalse() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let responseData = context.createValidWorkDataResponse()
        context.apiRequestMock.mockResponse = try! JSONSerialization.jsonObject(with: responseData)
        
        let fetcher = context.createFetcher()
        
        // Call without forceSendMDM parameter
        try await fetcher.checkUpdateWorkData(force: true)
        
        // Should default to false
        #expect(context.mdmFetcherMock.processAndApplyCallCount == 1)
        #expect(context.mdmFetcherMock.capturedForceSend == false)
    }
    
    // MARK: - ApplyDirectory Tests
    
    @Test("CheckUpdate with directory enabled applies directory")
    func checkUpdateWithDirectoryEnabledAppliesDirectory() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "directory": [
                "enabled": true,
                "cat": ["category1": "Category 1", "category2": "Category 2"],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let myIdentityStoreMock = context.myIdentityStoreMock

        #expect(context.userSettingsMock.companyDirectory == true)
        #expect(myIdentityStoreMock.directoryCategories != nil)
        #expect(myIdentityStoreMock.directoryCategories?["category1"] as? String == "Category 1")
        #expect(myIdentityStoreMock.directoryCategories?["category2"] as? String == "Category 2")
    }
    
    @Test("CheckUpdate with directory disabled disables directory")
    func checkUpdateWithDirectoryDisabledDisablesDirectory() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "directory": [
                "enabled": false,
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let userSettingsMock = context.userSettingsMock
        #expect(userSettingsMock.companyDirectory == false)
    }
    
    @Test("CheckUpdate with no directory disables directory")
    func checkUpdateWithNoDirectoryDisablesDirectory() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [:] // No directory field
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let userSettingsMock = context.userSettingsMock
        #expect(userSettingsMock.companyDirectory == false)
    }
    
    @Test("CheckUpdate with directory enabled but MDM disables it disables directory")
    func checkUpdateWithDirectoryEnabledButMDMDisablesItDisablesDirectory() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Configure MDM to disable work directory
        let mdmSetupMock = MDMSetupMock()
        mdmSetupMock.mockDisableWorkDirectory = true
        
        let response: [String: Any] = [
            "directory": [
                "enabled": true,
                "cat": ["category1": "Category 1"],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let apiCaller = WorkDataAPICaller(
            username: "test",
            password: "test",
            serverAPIRequest: context.apiRequestMock
        )
        
        let fetcher = WorkDataFetcher(
            contactStore: context.contactStoreMock,
            licenseStore: context.licenseStoreMock,
            identityStore: context.myIdentityStoreMock,
            userSettings: context.userSettingsMock,
            userDefaults: context.userDefaults,
            serverInfoProvider: context.serverInfoProviderMock,
            appFlavorService: context.appFlavorServiceMock,
            entityManager: context.testDatabase.entityManager,
            mdmSetup: mdmSetupMock,
            workDataAPICaller: apiCaller,
            workDataThreemaMDMFetcher: context.mdmFetcherMock
        )

        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // MDM should override and disable directory
        #expect(context.userSettingsMock.companyDirectory == false)
    }
    
    @Test("CheckUpdate with directory categories applies categories")
    func checkUpdateWithDirectoryCategoriesAppliesCategories() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        let response: [String: Any] = [
            "directory": [
                "enabled": true,
                "cat": [
                    "engineering": "Engineering",
                    "sales": "Sales",
                    "marketing": "Marketing",
                ],
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        let myIdentityStoreMock = context.myIdentityStoreMock
        #expect(myIdentityStoreMock.directoryCategories != nil)
        #expect(myIdentityStoreMock.directoryCategories?.count == 3)
        #expect(myIdentityStoreMock.directoryCategories?["engineering"] as? String == "Engineering")
        #expect(myIdentityStoreMock.directoryCategories?["sales"] as? String == "Sales")
        #expect(myIdentityStoreMock.directoryCategories?["marketing"] as? String == "Marketing")
    }
    
    @Test("CheckUpdate with directory without categories clears categories")
    func checkUpdateWithDirectoryWithoutCategoriesClearsCategories() async throws {
        let context = TestContext()
        defer { context.cleanup() }
        
        context.appFlavorServiceMock.isBusinessApp = true
        context.licenseStoreMock.licenseUsername = "testUser"
        
        // Pre-populate with existing categories
        let myIdentityStoreMock = context.myIdentityStoreMock
        myIdentityStoreMock.directoryCategories = NSMutableDictionary(dictionary: ["old": "Old Category"])

        let response: [String: Any] = [
            "directory": [
                "enabled": true,
                // No 'cat' field
            ],
        ]
        context.apiRequestMock.mockResponse = response
        
        let fetcher = context.createFetcher()
        
        try await fetcher.checkUpdateWorkData(force: true, forceSendMDM: false)
        
        // Categories should be cleared
        #expect(myIdentityStoreMock.directoryCategories == nil)
    }
}
