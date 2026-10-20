import DataBackup
import Observation
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupRecoveryKeyEntryViewModel {

    // MARK: - Public types

    struct KeyRow: Identifiable {
        let id: Int
        let cells: [KeyCell]

        struct KeyCell: Identifiable {
            let index: Int
            let text: String

            var id: Int { index }
        }
    }

    // MARK: - Public properties

    static let characterCount = RecoveryKeyGenerator.defaultLength
    static let charactersPerComponent = 4
    static let componentCount = characterCount / charactersPerComponent

    let continueButtonTitle = #localize("continue")
    let headerTitle = #localize("enter_your_recovery_key")
    let headerSubtitle = #localize("enter_your_recovery_key_subtitle")
    let headerIconName = "key"
    let sectionHeader = #localize("Recovery_key")

    @ObservationIgnored
    var onContinueButtonTapped: (String) -> Void = { _ in /* no-op */ }

    var componentPlaceholder: String {
        String(repeating: "-", count: Self.charactersPerComponent)
    }

    var widestComponent: String {
        String(repeating: "W", count: Self.charactersPerComponent)
    }

    var recoveryKey: String {
        get {
            enteredKey
        }
        set {
            enteredKey = String(Self.sanitized(newValue).prefix(Self.characterCount))
        }
    }

    var focusedComponent: Int {
        guard !enteredKey.isEmpty else {
            return 0
        }

        return (enteredKey.count - 1) / Self.charactersPerComponent
    }

    var isContinueButtonDisabled: Bool {
        enteredKey.count != Self.characterCount
    }

    // MARK: - Private properties

    private static let allowedCharacters = Set(
        RecoveryKeyGenerator.defaultLetters + RecoveryKeyGenerator.defaultDigits
    )

    private var enteredKey = ""

    // MARK: - Internal methods

    func continueButtonTapped() {
        onContinueButtonTapped(enteredKey)
    }

    func updateComponent(_ text: String, at index: Int) {
        let head = String(enteredKey.prefix(index * Self.charactersPerComponent))
        let room = Self.characterCount - head.count

        recoveryKey = head + Self.sanitized(text).prefix(room)
    }

    func component(at index: Int) -> String {
        let offset = index * Self.charactersPerComponent

        guard offset < enteredKey.count else {
            return ""
        }

        return String(enteredKey.dropFirst(offset).prefix(Self.charactersPerComponent))
    }

    /// Slices the entered key into components and groups them into rows for display.
    func keyRows(columnsPerRow: Int) -> [KeyRow] {
        let cells = (0..<Self.componentCount).map { index in
            KeyRow.KeyCell(index: index, text: component(at: index))
        }

        guard columnsPerRow > 0 else {
            return [KeyRow(id: 0, cells: cells)]
        }

        return stride(from: 0, to: cells.count, by: columnsPerRow)
            .map { index in
                KeyRow(id: index, cells: Array(cells[index..<min(index + columnsPerRow, cells.count)]))
            }
    }

    // MARK: - Private methods

    private static func sanitized(_ text: String) -> String {
        text.uppercased().filter { allowedCharacters.contains($0) }
    }
}
