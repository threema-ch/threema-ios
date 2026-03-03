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

import SwiftUI
import ThreemaMacros

struct QRCodeScannerView: View {
    @Bindable var model: QRCodeScannerViewModel

    var body: some View {
        GeometryReader { geometryProxy in
            ScrollView {
                VStack {
                    Spacer()

                    VStack {
                        Text(model.title)
                            .font(.title)
                            .bold()
                            .padding(.bottom)
                            .accessibilityAddTraits(.isHeader)

                        Text(model.info)
                            .padding(.bottom)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    QRCodeCameraView(
                        audioSessionManager: model.audioSessionManager,
                        systemFeedbackManager: model.systemFeedbackManager,
                        systemPermissionsManager: model.systemPermissionsManager,
                        shouldResume: $model.shouldResume
                    ) { result in
                        model.handleResult(result)
                    }
                    .frame(maxHeight: geometryProxy.size.height * 0.6)
                    .accessibilityElement()
                    .accessibilityLabel(#localize("qr_code_scanner_camera_label"))
                    .accessibilityHint(#localize("qr_code_scanner_camera_hint"))
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Spacer()
                    Spacer()
                }
                .padding([.horizontal, .bottom], 24)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .cancel) {
                            model.cancelButtonTapped()
                        } label: {
                            Label(#localize("cancel"), systemImage: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            model.onViewAppear()
        }
        .onDisappear {
            model.onViewDisappear()
        }
        .alert(item: $model.alert) { alertData in
            Alert(
                title: Text(alertData.title),
                message: Text(alertData.message),
                dismissButton: .default(Text(#localize("ok"))) {
                    model.alertOKButtonTapped()
                }
            )
        }
    }
}

#if DEBUG

    @MainActor
    fileprivate func makeScannerView(_ mode: QRCodeScannerViewModel.QRCodeDecodeMode) -> some View {
        NavigationStack {
            QRCodeScannerView(
                model: QRCodeScannerViewModel(
                    mode: mode,
                    audioSessionManager: .null,
                    systemFeedbackManager: .null,
                    systemPermissionsManager: .alwaysAllows
                )
            )
        }
    }

    #Preview("Identity") {
        makeScannerView(.identity)
    }

    #Preview("Identity Backup") {
        makeScannerView(.identityBackup)
    }

    #Preview("Multi Device Join Link") {
        makeScannerView(.multiDeviceLink)
    }

    #Preview("Desktop Web Session") {
        makeScannerView(.webSession)
    }

    #Preview("Plain Text") {
        makeScannerView(.plainText)
    }

#endif
