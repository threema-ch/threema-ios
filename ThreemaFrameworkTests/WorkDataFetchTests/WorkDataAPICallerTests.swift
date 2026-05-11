import Testing
@testable import ThreemaFramework

@Suite("WorkDataAPICaller Tests")
struct WorkDataAPICallerTests {
    
    // MARK: - Initialization Tests
    
    @Test("Initialization stores credentials correctly")
    func initStoresCredentials() async throws {
        // Arrange
        let expectedUsername = "testUser"
        let expectedPassword = "testPassword"
        let serverAPIRequestMock = ServerAPIRequestMock()
        
        // Act
        let caller = WorkDataAPICaller(
            username: expectedUsername,
            password: expectedPassword,
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Assert
        // We verify credentials are stored by making a fetch call and checking captured data
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        _ = try await caller.fetchWorkData(with: [])
        #expect(serverAPIRequestMock.capturedData?["username"] as? String == expectedUsername)
        #expect(serverAPIRequestMock.capturedData?["password"] as? String == expectedPassword)
    }
    
    // MARK: - Credential Validation Tests (Parameterized)
    
    @Test(
        "Fetch with missing credentials throws missing credentials error",
        arguments: [
            (username: nil as String?, password: "validPassword" as String?, description: "nil username"),
            (username: "validUsername", password: nil, description: "nil password"),
            (username: nil, password: nil, description: "both nil"),
        ]
    )
    func fetchWithMissingCredentialsThrowsError(
        username: String?,
        password: String?,
        description: String
    ) async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let caller = WorkDataAPICaller(
            username: username,
            password: password,
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act & Assert
        await #expect(throws: WorkDataFetchError.self) {
            try await caller.fetchWorkData(with: [])
        }
        
        do {
            _ = try await caller.fetchWorkData(with: [])
            Issue.record("Expected WorkDataFetchError.missingCredentials to be thrown for \(description)")
        }
        catch let error as WorkDataFetchError {
            guard case .missingCredentials = error else {
                Issue.record("Expected missingCredentials error but got \(error) for \(description)")
                return
            }
        }
        catch {
            Issue.record("Expected WorkDataFetchError but got \(error) for \(description)")
        }
    }
    
    @Test("Fetch with missing credentials does not call API")
    func fetchWithMissingCredentialsDoesNotCallAPI() async {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let caller = WorkDataAPICaller(
            username: nil,
            password: nil,
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        _ = try? await caller.fetchWorkData(with: [])
        
        // Assert
        #expect(serverAPIRequestMock.postJSONCallCount == 0)
    }
    
    // MARK: - Successful Response Tests
    
    @Test("Fetch with valid credentials returns data")
    func fetchWithValidCredentialsReturnsData() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let expectedResponse: [String: Any] = ["status": "ok", "contacts": []]
        serverAPIRequestMock.mockResponse = expectedResponse
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        let data = try await caller.fetchWorkData(with: [])
        
        // Assert
        let decodedResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decodedResponse?["status"] as? String == "ok")
    }
    
    @Test("Fetch sends correct payload")
    func fetchSendsCorrectPayload() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let expectedUsername = "myUsername"
        let expectedPassword = "myPassword"
        let expectedContacts = ["CONTACT1", "CONTACT2"]
        
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        let caller = WorkDataAPICaller(
            username: expectedUsername,
            password: expectedPassword,
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        _ = try await caller.fetchWorkData(with: expectedContacts)
        
        // Assert
        #expect(serverAPIRequestMock.capturedData?["username"] as? String == expectedUsername)
        #expect(serverAPIRequestMock.capturedData?["password"] as? String == expectedPassword)
        #expect(serverAPIRequestMock.capturedData?["contacts"] as? [String] == expectedContacts)
    }
    
    @Test(
        "Fetch with various contact lists succeeds",
        arguments: [
            (contacts: [] as [String], description: "empty list"),
            (contacts: ["AAAAAAAA", "BBBBBBBB", "CCCCCCCC", "DDDDDDDD"], description: "multiple contacts"),
        ]
    )
    func fetchWithVariousContactListsSucceeds(contacts: [String], description: String) async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        let data = try await caller.fetchWorkData(with: contacts)
        
        // Assert
        let capturedContacts = serverAPIRequestMock.capturedData?["contacts"] as? [String]
        #expect(capturedContacts == contacts, "Failed for \(description)")
    }
    
    // MARK: - Error Handling Tests (Parameterized)
    
    @Test(
        "Fetch with network errors propagates error correctly",
        arguments: [
            (code: NSURLErrorNotConnectedToInternet, description: "not connected to internet"),
            (code: NSURLErrorTimedOut, description: "timeout"),
        ]
    )
    func fetchWithNetworkErrorPropagatesError(code: Int, description: String) async {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let expectedError = NSError(domain: NSURLErrorDomain, code: code)
        serverAPIRequestMock.mockError = expectedError
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act & Assert
        do {
            _ = try await caller.fetchWorkData(with: [])
            Issue.record("Expected error to be thrown for \(description)")
        }
        catch {
            let nsError = error as NSError
            #expect(nsError.domain == NSURLErrorDomain, "Failed for \(description)")
            #expect(nsError.code == code, "Failed for \(description)")
        }
    }
    
    @Test("Fetch with nil JSON response throws invalid response error")
    func fetchWithNilJsonResponseThrowsInvalidResponse() async {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        serverAPIRequestMock.mockResponse = nil
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act & Assert
        await #expect(throws: WorkDataFetchError.self) {
            try await caller.fetchWorkData(with: [])
        }
        
        do {
            _ = try await caller.fetchWorkData(with: [])
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
    
    // MARK: - API Path Tests
    
    @Test("Fetch uses correct API path")
    func fetchUsesCorrectPath() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        _ = try await caller.fetchWorkData(with: [])
        
        // Assert
        #expect(serverAPIRequestMock.capturedPath == "fetch2")
    }
    
    // MARK: - Response Data Tests
    
    @Test("Fetch returns valid JSON data")
    func fetchReturnsValidJsonData() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let expectedContacts = [
            ["id": "AAAAAAAA", "name": "Test User"],
            ["id": "BBBBBBBB", "name": "Another User"],
        ]
        serverAPIRequestMock.mockResponse = ["contacts": expectedContacts]
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        let data = try await caller.fetchWorkData(with: [])
        
        // Assert
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let contacts = decoded?["contacts"] as? [[String: Any]]
        #expect(contacts?.count == 2)
        #expect(contacts?[0]["id"] as? String == "AAAAAAAA")
        #expect(contacts?[1]["name"] as? String == "Another User")
    }
    
    @Test("Fetch with complex response returns correct data")
    func fetchWithComplexResponseReturnsCorrectData() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        let complexResponse: [String: Any] = [
            "status": "ok",
            "contacts": [
                ["id": "AAAAAAAA", "publicKey": "abc123", "verified": true],
            ],
            "mdm": [
                "enabled": true,
                "settings": ["key": "value"],
            ],
        ]
        serverAPIRequestMock.mockResponse = complexResponse
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        let data = try await caller.fetchWorkData(with: [])
        
        // Assert
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decoded?["status"] as? String == "ok")
        
        let mdm = decoded?["mdm"] as? [String: Any]
        #expect(mdm?["enabled"] as? Bool == true)
    }
    
    // MARK: - Multiple Calls Tests
    
    @Test("Fetch called multiple times increments call count")
    func fetchCalledMultipleTimesIncrementsCallCount() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        _ = try await caller.fetchWorkData(with: [])
        _ = try await caller.fetchWorkData(with: ["A"])
        _ = try await caller.fetchWorkData(with: ["A", "B"])
        
        // Assert
        #expect(serverAPIRequestMock.postJSONCallCount == 3)
    }
    
    @Test("Fetch called multiple times captures last request")
    func fetchCalledMultipleTimesCapturesLastRequest() async throws {
        // Arrange
        let serverAPIRequestMock = ServerAPIRequestMock()
        serverAPIRequestMock.mockResponse = ["status": "ok"]
        
        let caller = WorkDataAPICaller(
            username: "testUser",
            password: "testPassword",
            serverAPIRequest: serverAPIRequestMock
        )
        
        // Act
        _ = try await caller.fetchWorkData(with: ["FIRST"])
        _ = try await caller.fetchWorkData(with: ["SECOND"])
        _ = try await caller.fetchWorkData(with: ["THIRD"])
        
        // Assert
        #expect(serverAPIRequestMock.capturedData?["contacts"] as? [String] == ["THIRD"])
    }
}
