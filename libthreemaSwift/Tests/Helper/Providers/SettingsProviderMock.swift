import Foundation
import libthreemaSwift

final class SettingsProviderMock: libthreemaSwift.SettingsProvider {
    private let _settings: libthreemaSwift.Settings

    init(settings: libthreemaSwift.Settings) {
        self._settings = settings
    }

    func get() throws -> libthreemaSwift.Settings {
        _settings
    }

    func set(settings: libthreemaSwift.Settings) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    func update(update: libthreemaSwift.SettingsUpdate) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
}
