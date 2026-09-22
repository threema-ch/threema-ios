import Testing
@testable import ThreemaFramework

struct AppSetupRecomputeTests {

    @Test("A present identity with a preexisting database becomes .complete and is persisted")
    func presentWithDatabaseIsComplete() {
        let result = AppSetup.recomputeState(
            identityPresence: .present,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: true
        )

        #expect(result.state == .complete)
        #expect(result.shouldPersist)
        #expect(result.unavailable == nil)
    }

    @Test("A present identity without a preexisting database becomes .notSetup (app deleted, ID left in keychain)")
    func presentWithoutDatabaseIsNotSetup() {
        let result = AppSetup.recomputeState(
            identityPresence: .present,
            hasPreexistingDatabaseFile: false,
            protectedDataAvailable: true
        )

        #expect(result.state == .notSetup)
        #expect(result.shouldPersist)
        #expect(result.unavailable == nil)
    }

    @Test("An absent identity becomes .notSetup and is persisted (fresh install / completed erase)")
    func absentIsNotSetup() {
        let result = AppSetup.recomputeState(
            identityPresence: .absent,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: true
        )

        #expect(result.state == .notSetup)
        #expect(result.shouldPersist)
        #expect(result.unavailable == nil)
    }

    /// Regression: the permanence behind the "open to fetch" onboarding bug. An undetermined identity presence
    /// (keychain read failure) must return `.notSetup` transiently but MUST NOT be persisted, so the state
    /// self-heals on the next read once the keychain is available again.
    @Test("An undetermined identity is NOT persisted, so a transient keychain failure never sticks")
    func undeterminedIsNotPersisted() {
        let result = AppSetup.recomputeState(
            identityPresence: .undetermined,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: true
        )

        #expect(result.state == .notSetup)
        #expect(result.shouldPersist == false)
        #expect(result.unavailable == .keychainUnreadable)
    }

    /// Regression: the UserDefaults-while-locked corruption. While protected data is unavailable the app-group
    /// UserDefaults reads the state key as 0 even for a fully set up app, so the recompute must NOT persist,
    /// even if the identity looks present, otherwise it would clobber the real `.complete` on disk.
    @Test("Nothing is persisted while protected data is unavailable, even if the identity looks present")
    func protectedDataUnavailableNeverPersists() {
        let result = AppSetup.recomputeState(
            identityPresence: .present,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: false
        )

        #expect(result.state == .notSetup)
        #expect(result.shouldPersist == false)
        #expect(result.unavailable == .protectedDataUnavailable)
    }

    @Test("A locked device and an unreadable keychain are reported as different reasons")
    func unavailableReasonsAreDistinct() {
        let locked = AppSetup.recomputeState(
            identityPresence: .undetermined,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: false
        )
        let unreadable = AppSetup.recomputeState(
            identityPresence: .undetermined,
            hasPreexistingDatabaseFile: true,
            protectedDataAvailable: true
        )

        #expect(locked.unavailable != unreadable.unavailable)
    }
}
