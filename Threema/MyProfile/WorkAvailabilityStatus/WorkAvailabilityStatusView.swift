import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct WorkAvailabilityStatusView: View {
    @Bindable var model: WorkAvailabilityStatusViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        List {
            Section {
                Picker(selection: $model.selectedStatus) {
                    ForEach(WorkAvailabilityStatus.Category.allCases) { status in
                        Label {
                            Text(status.localizedDescription)
                        } icon: {
                            Image(systemName: status.systemImageName)
                                .font(.footnote)
                                .foregroundStyle(status.color.color)
                                .padding(4)
                                .background(status.colorBackground.color, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .tag(status)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            } footer: {
                Text(model.companyInfo)
            }

            if model.selectedStatus != .none {
                Section {
                    HStack(alignment: .center) {
                        TextField(
                            "",
                            text: $model.statusText,
                            prompt: Text(model.textFieldPlaceholder),
                            axis: .vertical
                        )
                        .focused($isTextFieldFocused)

                        if !model.statusText.isEmpty {
                            Button {
                                model.statusText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(model.isByteLimitExceeded ? Color.red : Color.clear, lineWidth: 1.5)
                                    .padding(1)
                            )
                    )
                } header: {
                    Text(model.textFieldSectionHeader)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.isByteLimitExceeded {
                            Text(model.textLimitExceededMessage)
                                .font(.monospacedDigit(.footnote)()).fontWeight(.medium)
                                .foregroundStyle(.red)
                        }

                        Text(model.textFieldSectionFooter)
                    }
                }
            }
        }
        // Animate hiding text field section
        .animation(.default, value: model.selectedStatus)
        .onChange(of: model.statusText) { _, newValue in
            // Strip newlines (e.g. from pasted text)
            if newValue.contains(where: \.isNewline) {
                model.statusText = newValue.replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
            }
        }
        .onChange(of: isTextFieldFocused) { _, isFocused in
            if isFocused {
                moveCursorToEnd()
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CancelButton {
                    model.cancelButtonTapped()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ConfirmationButton(title: model.textConfirmationButton) {
                    Task {
                        await model.confirmationButtonTapped()
                    }
                }
                .disabled(model.isByteLimitExceeded || !model.statusChanged)
            }
        }
        .navigationTitle(model.navigationTitle)
        .loadingOverlay(model.isLoading)
        .applyIf(model.statusChanged) { view in
            view
                .interactiveDismissDisabled()
        }
        .task {
            model.loadCurrentStatus()
        }
    }

    /// Moves the cursor to the end of the text field via UIKit's first responder chain.
    private func moveCursorToEnd() {
        DispatchQueue.main.async {
            guard let textInput = UIResponder.currentFirstResponder as? (any UITextInput) else {
                return
            }
            let endPosition = textInput.endOfDocument
            textInput.selectedTextRange = textInput.textRange(from: endPosition, to: endPosition)
        }
    }
}

// MARK: - UIResponder + FirstResponder

extension UIResponder {
    fileprivate weak static var currentFirst: UIResponder?

    @objc private func findFirstResponder(_ sender: AnyObject) {
        UIResponder.currentFirst = self
    }

    fileprivate static var currentFirstResponder: UIResponder? {
        currentFirst = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return currentFirst
    }
}
