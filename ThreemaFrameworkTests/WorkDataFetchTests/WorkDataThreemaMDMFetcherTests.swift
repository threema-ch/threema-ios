import Testing
@testable import ThreemaFramework

@Suite("WorkDataThreemaMDMFetcher Tests")
struct WorkDataThreemaMDMFetcherTests {
    
    // MARK: - Helper Methods
    
    func createFetcher(
        mockMDMSetup: MDMSetupMock,
        licenseStoreMock: LicenseStoreMock,
        mockAppFlavorService: MockAppFlavorService,
        mockWorkDataAPICaller: ServerAPIRequestMock
    ) -> WorkDataThreemaMDMFetcher {
        WorkDataThreemaMDMFetcher(
            mdmSetup: mockMDMSetup,
            licenseStore: licenseStoreMock,
            appFlavorService: mockAppFlavorService,
            workDataAPICaller: WorkDataAPICaller(
                username: "test",
                password: "test",
                serverAPIRequest: mockWorkDataAPICaller
            )
        )
    }
    
    func createValidMDMData() -> Data {
        let mdmDict: [String: Any] = [
            "status": "ok",
            "mdm": [
                "enabled": true,
                "settings": ["key": "value"],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: mdmDict)
    }
    
    // MARK: - checkUpdateThreemaMDM() - Business App Validation Tests
    
    @Test("CheckUpdate with non-business app returns without calling API")
    func checkUpdateWithNonBusinessAppReturnsWithoutCalling() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = false
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert - Should return early without making API call
        #expect(mockWorkDataAPICaller.postJSONCallCount == 0)
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 0)
    }
    
    // MARK: - checkUpdateThreemaMDM() - Credential Validation Tests (Parameterized)
    
    @Test(
        "CheckUpdate with missing credentials throws error",
        arguments: [
            (username: nil as String?, password: "testPassword" as String?, description: "nil username"),
            (username: "testUser", password: nil, description: "nil password"),
            (username: nil, password: nil, description: "both nil"),
        ]
    )
    func checkUpdateWithMissingCredentialsThrowsError(
        username: String?,
        password: String?,
        description: String
    ) async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = username
        licenseStoreMock.licensePassword = password
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        do {
            _ = try await fetcher.checkUpdateThreemaMDM(forceSend: false)
            Issue.record("Expected error to be thrown for \(description)")
        }
        catch {
            let nsError = error as NSError
            #expect(nsError.localizedDescription.contains("Missing credentials"), "Failed for \(description)")
        }
    }
    
    @Test("CheckUpdate with missing credentials does not call API")
    func checkUpdateWithMissingCredentialsDoesNotCallAPI() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = nil
        licenseStoreMock.licensePassword = nil
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        _ = try? await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert
        #expect(mockWorkDataAPICaller.postJSONCallCount == 0)
    }
    
    // MARK: - checkUpdateThreemaMDM() - Successful Flow Tests
    
    @Test("CheckUpdate with valid credentials calls API with empty contacts")
    func checkUpdateWithValidCredentialsCallsAPIWithEmptyContacts() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let mdmData = createValidMDMData()
        let mdmDict = try JSONSerialization.jsonObject(with: mdmData)
        mockWorkDataAPICaller.mockResponse = mdmDict
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert
        #expect(mockWorkDataAPICaller.postJSONCallCount == 1)
        #expect(mockWorkDataAPICaller.capturedData?["contacts"] as? [String] == [])
    }
    
    @Test("CheckUpdate with valid response calls processAndApply")
    func checkUpdateWithValidResponseCallsProcessAndApply() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let mdmData = createValidMDMData()
        let mdmDict = try JSONSerialization.jsonObject(with: mdmData)
        mockWorkDataAPICaller.mockResponse = mdmDict
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 1)
    }
    
    @Test("CheckUpdate success applies MDM configuration")
    func checkUpdateSuccessAppliesMDMConfiguration() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let mdmData = createValidMDMData()
        let mdmDict = try JSONSerialization.jsonObject(with: mdmData)
        mockWorkDataAPICaller.mockResponse = mdmDict
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.lastAppliedWorkData != nil)
        #expect(mockMDMSetup.lastAppliedSendForce == false)
    }
    
    // MARK: - checkUpdateThreemaMDM() - Error Propagation Tests
    
    @Test("CheckUpdate with API error propagates error")
    func checkUpdateWithAPIErrorPropagatesError() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let apiError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockWorkDataAPICaller.mockError = apiError
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        do {
            _ = try await fetcher.checkUpdateThreemaMDM(forceSend: false)
            Issue.record("Expected error to be thrown")
        }
        catch {
            let nsError = error as NSError
            #expect(nsError.domain == NSURLErrorDomain)
            #expect(nsError.code == NSURLErrorNotConnectedToInternet)
        }
    }
    
    @Test("CheckUpdate with invalid response propagates error")
    func checkUpdateWithInvalidResponsePropagatesError() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        mockWorkDataAPICaller.mockResponse = nil
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        await #expect(throws: WorkDataFetchError.self) {
            try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        }
        
        do {
            _ = try await fetcher.checkUpdateThreemaMDM(forceSend: false)
            Issue.record("Expected WorkDataFetchError.invalidResponse to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case .invalidResponse = error else {
                Issue.record("Expected invalidResponse error but got \(error)")
                return
            }
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
    }
    
    // MARK: - processAndApply() - Valid Response Tests
    
    @Test("ProcessAndApply with valid data applies MDM")
    func processAndApplyWithValidDataAppliesMDM() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let mdmData = createValidMDMData()
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.processAndApply(mdmData, forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 1)
    }
    
    @Test("ProcessAndApply with valid data calls MDMSetup")
    func processAndApplyWithValidDataCallsMDMSetup() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let mdmData = createValidMDMData()
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.processAndApply(mdmData, forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.lastAppliedWorkData != nil)
        #expect(mockMDMSetup.lastAppliedWorkData?["status"] as? String == "ok")
    }
    
    @Test("ProcessAndApply with valid data uses sendForce false")
    func processAndApplyWithValidDataUsesSendForceFalse() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let mdmData = createValidMDMData()
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.processAndApply(mdmData, forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.lastAppliedSendForce == false)
    }
    
    // MARK: - processAndApply() - Error Handling Tests
    
    @Test("ProcessAndApply with non-dictionary throws invalid response")
    func processAndApplyWithNonDictionaryThrowsInvalidResponse() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let arrayData = try! JSONSerialization.data(withJSONObject: ["item1", "item2"])
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        await #expect(throws: WorkDataFetchError.self) {
            try await fetcher.processAndApply(arrayData, forceSend: false)
        }
        
        do {
            _ = try await fetcher.processAndApply(arrayData, forceSend: false)
            Issue.record("Expected WorkDataFetchError.invalidResponse to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case .invalidResponse = error else {
                Issue.record("Expected invalidResponse error but got \(error)")
                return
            }
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
    }
    
    @Test("ProcessAndApply with error key throws server error")
    func processAndApplyWithErrorKeyThrowsServerError() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let errorDict: [String: Any] = ["error": "Server maintenance"]
        let errorData = try! JSONSerialization.data(withJSONObject: errorDict)
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        await #expect(throws: WorkDataFetchError.self) {
            try await fetcher.processAndApply(errorData, forceSend: false)
        }
        
        do {
            _ = try await fetcher.processAndApply(errorData, forceSend: false)
            Issue.record("Expected WorkDataFetchError.serverError to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case let .serverError(message) = error else {
                Issue.record("Expected serverError but got \(error)")
                return
            }
            #expect(message == "Server maintenance")
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
    }
    
    @Test("ProcessAndApply with error message includes message in error")
    func processAndApplyWithErrorMessageIncludesMessageInError() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let expectedMessage = "Invalid license"
        let errorDict: [String: Any] = ["error": expectedMessage]
        let errorData = try! JSONSerialization.data(withJSONObject: errorDict)
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        do {
            _ = try await fetcher.processAndApply(errorData, forceSend: false)
            Issue.record("Expected serverError to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case let .serverError(message) = error else {
                Issue.record("Expected serverError but got \(error)")
                return
            }
            #expect(message == expectedMessage)
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("CheckUpdate end-to-end success")
    func checkUpdateEndToEndSuccess() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let mdmData = createValidMDMData()
        let mdmDict = try JSONSerialization.jsonObject(with: mdmData)
        mockWorkDataAPICaller.mockResponse = mdmDict
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: false)
        
        // Assert - Full flow completed
        #expect(mockWorkDataAPICaller.postJSONCallCount == 1)
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 1)
        #expect(mockMDMSetup.lastAppliedWorkData != nil)
        #expect(mockMDMSetup.lastAppliedSendForce == false)
    }
    
    @Test("CheckUpdate end-to-end with server error")
    func checkUpdateEndToEndWithServerError() async {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let errorDict: [String: Any] = ["error": "License expired"]
        mockWorkDataAPICaller.mockResponse = errorDict
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act & Assert
        do {
            _ = try await fetcher.checkUpdateThreemaMDM(forceSend: false)
            Issue.record("Expected serverError to be thrown")
        }
        catch let error as WorkDataFetchError {
            guard case let .serverError(message) = error else {
                Issue.record("Expected serverError but got \(error)")
                return
            }
            #expect(message == "License expired")
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error)")
        }
        
        // Verify MDM was not applied
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 0)
    }
    
    // MARK: - Complex MDM Data Tests
    
    @Test("ProcessAndApply with complex MDM data passes all data to setup")
    func processAndApplyWithComplexMDMDataPassesAllDataToSetup() async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let complexMDM: [String: Any] = [
            "status": "ok",
            "mdm": [
                "enabled": true,
                "safeBackup": [
                    "force": true,
                    "serverUrl": "https://safe.threema.ch",
                ],
                "contacts": [
                    ["id": "AAAAAAAA", "verified": true],
                    ["id": "BBBBBBBB", "verified": false],
                ],
            ],
        ]
        let complexData = try! JSONSerialization.data(withJSONObject: complexMDM)
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.processAndApply(complexData, forceSend: false)
        
        // Assert
        #expect(mockMDMSetup.lastAppliedWorkData != nil)
        let appliedMDM = mockMDMSetup.lastAppliedWorkData?["mdm"] as? [String: Any]
        #expect(appliedMDM?["enabled"] as? Bool == true)
    }
    
    // MARK: - ForceSend Parameter Tests (Parameterized)
    
    @Test(
        "ProcessAndApply passes forceSend parameter to MDMSetup correctly",
        arguments: [
            (forceSend: true, description: "force send true"),
            (forceSend: false, description: "force send false"),
        ]
    )
    func processAndApplyPassesForceSendToMDMSetup(forceSend: Bool, description: String) async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        let mdmData = createValidMDMData()
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.processAndApply(mdmData, forceSend: forceSend)
        
        // Assert
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 1, "Failed for \(description)")
        #expect(mockMDMSetup.lastAppliedSendForce == forceSend, "Failed for \(description)")
    }
    
    @Test(
        "CheckUpdate passes forceSend parameter to MDMSetup correctly",
        arguments: [
            (forceSend: true, description: "force send true"),
            (forceSend: false, description: "force send false"),
        ]
    )
    func checkUpdatePassesForceSendToMDMSetup(forceSend: Bool, description: String) async throws {
        // Arrange
        let mockMDMSetup = MDMSetupMock()
        let licenseStoreMock = LicenseStoreMock()
        let mockAppFlavorService = MockAppFlavorService()
        let mockWorkDataAPICaller = ServerAPIRequestMock()
        
        mockAppFlavorService.isBusinessApp = true
        licenseStoreMock.licenseUsername = "testUser"
        licenseStoreMock.licensePassword = "testPassword"
        
        let mdmData = createValidMDMData()
        mockWorkDataAPICaller.mockResponse = try! JSONSerialization.jsonObject(with: mdmData)
        
        let fetcher = createFetcher(
            mockMDMSetup: mockMDMSetup,
            licenseStoreMock: licenseStoreMock,
            mockAppFlavorService: mockAppFlavorService,
            mockWorkDataAPICaller: mockWorkDataAPICaller
        )
        
        // Act
        try await fetcher.checkUpdateThreemaMDM(forceSend: forceSend)
        
        // Assert
        #expect(mockMDMSetup.applyThreemaMdmCallCount == 1, "Failed for \(description)")
        #expect(mockMDMSetup.lastAppliedSendForce == forceSend, "Failed for \(description)")
    }
}
