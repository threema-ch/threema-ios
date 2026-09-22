import Foundation
import Testing
import ThreemaEssentials
import ThreemaFramework
@testable import Threema

@MainActor
struct AppLaunchSequenceManagerTests {

    // MARK: - Regression: the "open to fetch" push bug

    @Test("A transient keychain miss is NOT treated as a missing identity")
    func transientMissIsNotConfirmedMissing() async throws {
        // First read reports the identity as not-found (the transient), every retry finds it.
        let reader = IdentityReader(
            responses: [.missing],
            fallback: .identity(ThreemaIdentity("ECHOECHO"))
        )
        let manager = makeManager(reader: reader)

        let confirmedMissing = try await manager.isIdentityConfirmedMissing()

        // The identity is present, so the destructive AppSetupState reset must NOT run.
        #expect(confirmedMissing == false)
        // The transient miss triggered a retry that then found the identity.
        #expect(reader.callCount == 2)
    }

    // MARK: - Preserved behavior

    @Test("A persistent keychain miss IS treated as a missing identity (genuine device restore)")
    func persistentMissIsConfirmedMissing() async throws {
        // The identity stays missing across every attempt. This is a real restore.
        let reader = IdentityReader(responses: [], fallback: .missing)
        let manager = makeManager(reader: reader, attempts: 3)

        let confirmedMissing = try await manager.isIdentityConfirmedMissing()

        #expect(confirmedMissing == true)
        // Every attempt was used before concluding the identity is gone.
        #expect(reader.callCount == 3)
    }

    @Test("A present identity is confirmed on the first read, without retrying")
    func presentIdentityIsNotMissing() async throws {
        let reader = IdentityReader(responses: [], fallback: .identity(ThreemaIdentity("ECHOECHO")))
        let manager = makeManager(reader: reader)

        let confirmedMissing = try await manager.isIdentityConfirmedMissing()

        #expect(confirmedMissing == false)
        // The common launch path reads once and adds no retry latency.
        #expect(reader.callCount == 1)
    }

    @Test("A keychain read error is propagated, never mistaken for a missing identity")
    func keychainErrorPropagates() async {
        let reader = IdentityReader(responses: [], fallback: .failure(KeychainReadError()))
        let manager = makeManager(reader: reader)

        // A throwing read must surface as an error (routed to `.failed(.keychainError)` by `run()`),
        // not silently collapse to "identity missing" and reset the setup state.
        await #expect(throws: KeychainReadError.self) {
            try await manager.isIdentityConfirmedMissing()
        }
    }
    
    // MARK: - Regression: an undetermined setup state must not start onboarding

    @Test("An unreadable keychain surfaces as a retryable keychain error, not as onboarding")
    func unreadableStateDoesNotStartOnboarding() async {
        let manager = makeManager(
            reader: IdentityReader(responses: [], fallback: .identity(ThreemaIdentity("ECHOECHO"))),
            appSetupState: (.notSetup, .keychainUnreadable)
        )

        let result = await manager.run()

        guard case let .failed(error) = result, case .keychainError = error else {
            Issue.record("Expected .failed(.keychainError), got \(result)")
            return
        }
        #expect(error.isRetryable)
    }

    @Test("A state read blocked by protected data surfaces as .protectedDataUnavailable")
    func protectedDataUnavailableStateWaitsInsteadOfOnboarding() async {
        let manager = makeManager(
            reader: IdentityReader(responses: [], fallback: .identity(ThreemaIdentity("ECHOECHO"))),
            // The early `isKeychainLocked` check passes; only the later state read is blocked.
            appSetupState: (.notSetup, .protectedDataUnavailable)
        )

        let result = await manager.run()

        guard case .protectedDataUnavailable = result else {
            Issue.record("Expected .protectedDataUnavailable, got \(result)")
            return
        }
    }

    @Test("A determined .notSetup still leads to onboarding")
    func determinedNotSetupStartsOnboarding() async {
        let appLaunchManager = AppLaunchManagerMock()
        appLaunchManager.isAppSetupCompleted = false
        // Keeps the Remote Secret cleanup that follows the state check from touching the test host's real
        // keychain; this test is only about which result a determined `.notSetup` produces.
        appLaunchManager.hasPreexistingDatabaseFile = true

        let manager = makeManager(
            reader: IdentityReader(responses: [], fallback: .identity(ThreemaIdentity("ECHOECHO"))),
            appSetupState: (.notSetup, nil),
            appLaunchManager: appLaunchManager
        )

        let result = await manager.run()

        guard case .needsOnboarding = result else {
            Issue.record("Expected .needsOnboarding, got \(result)")
            return
        }
    }

    // MARK: - Test helpers

    private final class IdentityReader {
        enum Response {
            case identity(ThreemaIdentity)
            case missing
            case failure(any Error)
        }

        private var responses: [Response]
        private let fallback: Response
        private(set) var callCount = 0

        init(responses: [Response], fallback: Response) {
            self.responses = responses
            self.fallback = fallback
        }

        func read() throws -> ThreemaIdentity? {
            callCount += 1
            let response = responses.isEmpty ? fallback : responses.removeFirst()
            switch response {
            case let .identity(identity):
                return identity
            case .missing:
                return nil
            case let .failure(error):
                throw error
            }
        }
    }

    private struct KeychainReadError: Error { }

    private func makeManager(
        reader: IdentityReader,
        attempts: Int = 3,
        appSetupState: (state: AppSetupState, unavailable: AppSetup.StateUnavailableReason?) = (.notSetup, nil),
        appLaunchManager: AppLaunchManagerMock? = nil
    ) -> AppLaunchSequenceManager {
        AppLaunchSequenceManager(
            bootstrap: .mock(appLaunchManager: appLaunchManager),
            loadThreemaIdentity: { try reader.read() },
            resolveAppSetupState: { appSetupState },
            missingIdentityConfirmationAttempts: attempts,
            // No delay so the retries do not slow the test down.
            missingIdentityConfirmationDelay: nil
        )
    }
}
