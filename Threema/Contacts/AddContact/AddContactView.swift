//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SwiftUI
import ThreemaEssentials
import ThreemaMacros

struct AddContactView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject var viewModel = AddContactViewModel()
    
    @FocusState private var isInputFocused: Bool
    @State private var showAlert = false
    @State private var alertData: AddContactError?
    private let onSaveDisplayMode: OnSaveDisplayMode

    init(onSaveDisplayMode: OnSaveDisplayMode = .showDetails) {
        self.onSaveDisplayMode = onSaveDisplayMode
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(#localize("add_contact_ID_placeholder"), text: $viewModel.identity)
                        .font(Font(Configuration().nameFont))
                        .padding(.vertical, 3)
                        .focused($isInputFocused)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        .accessibilityIdentifier("AddContactViewControllerCTextField")
                        .submitLabel(.done)
                        .onChange(of: viewModel.identity) { [weak viewModel] _, newValue in
                            guard let viewModel else {
                                return
                            }
                            Task { @MainActor [weak viewModel] in
                                guard let viewModel else {
                                    return
                                }
                                let uppercased = newValue.uppercased()
                                if newValue != uppercased {
                                    viewModel.identity = uppercased
                                }
                            }
                        }
                        .onSubmit {
                            add()
                        }
                }
                Section {
                    buildRow(#localize("add_contact_scan"), "qrcode.viewfinder", action: showScanner)
                        .disabled(viewModel.isScanningDisabled)
                }
                Section {
                    buildShareLink()
                }
            }
            .navigationTitle(#localize("add_contact_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(#localize("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(#localize("add_button")) {
                        add()
                    }
                    .accessibilityIdentifier("AddContactModalAddButton")
                    .disabled(!viewModel.canAdd)
                }
            }
            .alert(alertData?.title ?? "", isPresented: $showAlert, presenting: alertData) { _ in
                Button(#localize("ok"), role: .cancel) {
                    alertData = nil
                }
            } message: { alert in
                Text(alert.message)
            }
        }
        .onAppear {
            Task { @MainActor in
                isInputFocused = true
            }
        }
        // Force navigation style to stack so it doesn't show as split view on iPadOS 17
        // Can be removed after migrating from NavigationView to NavigationStack
        .navigationViewStyle(.stack)
        .loadingOverlay(viewModel.isLoading)
    }
    
    @ViewBuilder
    private func buildShareLink() -> some View {
        let shareText = String.localizedStringWithFormat(
            #localize("invite_sms_body"),
            TargetManager.appName,
            TargetManager.localizedAppName,
            BusinessInjector.ui.profileStore.profile.myIdentity.rawValue
        )
        
        ShareLink(item: shareText) {
            HStack {
                Label(#localize("add_contact_invite_friend"), systemImage: "person.2.wave.2.fill")
                    .labelStyle(.titleAndIcon)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
    }
    
    @ViewBuilder
    private func buildRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .labelStyle(.titleAndIcon)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
    }

    private func showScanner() {
        let model = QRCodeScannerViewModel(
            mode: .identity,
            audioSessionManager: AudioSessionManager(),
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            ),
            systemPermissionsManager: SystemPermissionsManager()
        )
        model.onCompletion = { result in
            handleScannerResult(result)
        }
        model.onCancel = {
            topViewController?.dismiss(animated: true) // dismiss only the scanner
        }
        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)
        topViewController?.present(nav, animated: true)
    }

    private func handleScannerResult(_ result: QRCodeScannerViewModel.QRCodeResult) {
        switch result {
        case let .identityContact(identity: id, publicKey: key, expirationDate: date):
            handleIdentityContact(id: id, key: key, date: date)

        case let .identityLink(url: url):
            dismissScannerViewAndAddContactView {
                URLHandler.handleThreemaDotIDURL(url, hideAppChooser: true)
            }

        default:
            break
        }
    }

    private func handleIdentityContact(id: ThreemaIdentity, key: Data, date: Date?) {
        let contactVM = ContactIdentityProcessingViewModel(
            expectedIdentity: nil,
            scannedIdentity: id,
            scannedPublicKey: key,
            scannedExpirationDate: date,
            systemFeedbackManager: SystemFeedbackManager(
                deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                settingsStore: BusinessInjector.ui.settingsStore
            )
        )
        let rootView = ContactIdentityProcessingView(model: contactVM)
        let viewController = UIHostingController(rootView: rootView)
        (topViewController as? UINavigationController)?.pushViewController(viewController, animated: true)
        contactVM.onCompletion = { verifiedContact in
            dismissScannerViewAndAddContactView {
                if let verifiedContact {
                    let name = Notification.Name(kNotificationShowContact)
                    let userInfo = [kKeyContact: verifiedContact]
                    NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
                }
            }
        }
    }

    private func dismissScannerViewAndAddContactView(completion: (() -> Void)? = nil) {
        topViewController? // PortraitNavigationController
            .presentingViewController? // AddContactView
            .presentingViewController? // MainTabBarController
            .dismiss(animated: true, completion: completion)
    }

    private func add() {
        isInputFocused = false
        
        guard viewModel.canAdd else {
            return
        }

        Task {
            do {
                try await viewModel.addContact(onSaveDisplayMode: onSaveDisplayMode)
                await MainActor.run {
                    dismiss()
                }
            }
            catch let error as AddContactValidationError {
                showErrorAlert(error)
            }
            catch {
                assertionFailure("All errors should be wrapped by AddContactValidationError")
                showErrorAlert(AddContactValidationError.unknown(error))
            }
        }
    }

    private func showErrorAlert(_ error: AddContactValidationError) {
        showAlert(
            title: error.errorTitle,
            message: error.localizedDescription
        )
    }
    
    private func showAlert(title: String, message: String) {
        alertData = AddContactError(title: title, message: message)
        showAlert = true
    }
}

struct AddContactView_Previews: PreviewProvider {
    static var previews: some View {
        AddContactView()
    }
}

private struct Configuration: DetailsConfiguration { }

private struct AddContactError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
