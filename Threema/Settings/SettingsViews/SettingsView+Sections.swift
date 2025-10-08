//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import CocoaLumberjackSwift
import SwiftUI
import ThreemaFramework
import ThreemaMacros

extension SettingsView {
    
    // MARK: - FeedbackDevSection
    
    struct FeedbackDevSection: View {
        @EnvironmentObject var model: SettingsViewModel
        
        var body: some View {
            Section {
                if model.displayFeedback {
                    if #available(iOS 17, *) {
                        SectionItem(
                            action: {
                                model.giveFeedback()
                            },
                            title: #localize("settings_feedback"),
                            image: .systemImage("ant.fill")
                        )
                        .popoverTip(TipKitManager.ThreemaBetaFeedbackTip())
                    }
                    else {
                        SectionItem(
                            action: {
                                model.giveFeedback()
                            },
                            title: #localize("settings_feedback"),
                            image: .systemImage("ant.fill")
                        )
                    }
                }
                if model.displayDevSettings {
                    SectionItem(
                        destination: {
                            DeveloperSettingsView()
                        },
                        title: "Developer Settings",
                        image: .systemImage("figure.mind.and.body")
                    )
                }
            }
        }
    }
    
    // MARK: - GeneralSection
    
    struct GeneralSection: View {
        @Environment(\.appContainer.businessInjector)
        private var injected: any BusinessInjectorProtocol
        
        @State private var isPasswordRequired = false
        
        var body: some View {
            Section {
                ItemSection {
                    (
                        view: PrivacySettingsView(),
                        title: #localize("settings_list_privacy_title"),
                        symbol: .systemImage("hand.raised.fill")
                    )
                    (
                        view: AppearanceSettingsViewControllerRepresentable(),
                        title: #localize("settings_list_appearance_title"),
                        symbol: .systemImage("paintbrush.fill")
                    )
                    (
                        view: NotificationSettingsView(),
                        title: #localize("settings_list_notifications_title"),
                        symbol: .systemImage("app.badge")
                    )
                    (
                        view: ChatSettingsView(),
                        title: #localize("settings_list_chat_title"),
                        symbol: .systemImage("bubble.left.and.bubble.right.fill")
                    )
                    (
                        view: MediaSettingsView(),
                        title: #localize("settings_list_media_title"),
                        symbol: .systemImage("photo.fill")
                    )
                    (
                        view: StorageManagementView(model: .init(businessInjector: injected)),
                        title: #localize("settings_list_storage_management_title"),
                        symbol: .systemImage("tray.full.fill")
                    )
                }
                
                SectionItem(
                    locked: true,
                    destination: {
                        uiViewController(KKPasscodeSettingsViewController(style: .insetGrouped))
                            .threemaNavigationBar(#localize("settings_list_passcode_lock_title"))
                    },
                    title: #localize("settings_list_passcode_lock_title"),
                    accessoryText: #localize(isPasswordRequired ? "On" : "Off"),
                    image: .systemImage("lock.fill")
                )
                .onAppear {
                    isPasswordRequired = KKPasscodeLock.shared().isPasscodeRequired()
                }
                
                ItemSection {
                    (
                        view: CallSettingsView(),
                        title: #localize("settings_threema_calls"),
                        symbol: .bundleImage("threema.phone.fill")
                    )
                }
            }
        }
    }
    
    // MARK: - DesktopSection
    
    struct DesktopSection: View {
        
        private let mdm = MDMSetup(setup: false)
        @State private var disableWeb = false
        @State private var disableMultiDevice = false

        var body: some View {
            Section {
                ItemSection {
                    if !disableMultiDevice {
                        (
                            view: LinkedDevicesView(),
                            title: String.localizedStringWithFormat(
                                #localize("settings_list_threema_desktop_title"),
                                TargetManager.appName
                            ),
                            symbol: .systemImage("desktopcomputer")
                        )
                    }
                    if !disableWeb {
                        (
                            view: threemaWeb,
                            title: String.localizedStringWithFormat(
                                #localize("settings_list_threema_web_title"),
                                TargetManager.appName
                            ),
                            symbol: .systemImage("menubar.dock.rectangle")
                        )
                    }
                }
            }
            .onAppear {
                checkDesktopWebDisabled()
            }
            .onReceive(\.mdmChanged) { _ in
                checkDesktopWebDisabled()
            }
        }
        
        var threemaWeb: some View {
            ThreemaWebViewControllerRepresentable()
                .applyIf(!disableWeb, apply: { view in
                    view.toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                ThreemaWebQRCodeScanner.shared.scan()
                            }, label: {
                                Image(systemName: "qrcode.viewfinder")
                            })
                            .accessibilityLabel(#localize("webClientSession_add"))
                        }
                    }
                    .asAnyView
                })
                .threemaNavigationBar(#localize("settings_list_threema_web_title"))
        }
        
        private func checkDesktopWebDisabled() {
            disableWeb = mdm?.disableWeb() ?? false
            disableMultiDevice = mdm?.disableMultiDevice() ?? false
        }
    }
    
    // MARK: - ConnectionSection
    
    struct ConnectionSection: View {
        @Environment(\.appContainer.appEnvironment.connectionStateProvider) var connectionStateProvider
        @State var connectionState: ConnectionState = .disconnected
                
        var body: some View {
            Section {
                connection
                    .onReceive(connectionStateProvider.$connectionState, perform: didChange)
                    .onAppear { didChange() }
                version
                if TargetManager.isBusinessApp {
                    license
                }
            }
        }
       
        private var connection: some View {
            let sc = ServerConnector.shared()
            let statusText = "status_\(sc.name(for: connectionState))"
                .localized
                .appending(sc.isIPv6Connection ? " (IPv6)" : "")
                .appending(sc.isProxyConnection ? " (Proxy)" : "")
            
            return SettingsListItemView(
                cellTitle: #localize("settings_list_network_title"),
                accessoryText: statusText
            )
        }
        
        @ViewBuilder
        private var version: some View {
            HStack {
                SettingsListItemView(
                    cellTitle: #localize("settings_list_version_title")
                )
                Spacer()
                Text(ThreemaUtility.appAndBuildVersionPretty)
                    .foregroundColor(.secondary)
                    .copyLabel(value: ThreemaUtility.appAndBuildVersion)
            }
        }

        private var license: some View {
            SettingsListItemView(
                cellTitle: #localize("settings_list_settings_license_username_title"),
                accessoryText: LicenseStore.shared().licenseUsername
            )
        }
        
        private func didChange(_ connectionState: ConnectionState = ServerConnector.shared().connectionState) {
            self.connectionState = connectionState
        }
    }
        
    // MARK: - ThreemaWorkSection
    
    struct ThreemaWorkAdvertisingSection: View {
        private let appURL = URL(string: "threemawork://app")
        
        private var canOpenThreemaWork: Bool {
            UIApplication.shared.canOpenURL(appURL!)
        }
        
        var body: some View {
            Section {
                if canOpenThreemaWork {
                    SectionItem {
                        UIApplication.shared.open(appURL!, options: [:], completionHandler: nil)
                    } label: {
                        label
                    }
                }
                else {
                    SectionItem {
                        uiViewController(SettingsWebViewViewController(
                            url: ThreemaURLProvider.workInfo,
                            title: #localize("settings_threema_work"),
                            allowsContentJavaScript: true
                        ))
                        .threemaNavigationBar(title)
                    } label: {
                        label
                    }
                }
            }
        }
        
        private var title: String {
            #localize("settings_threema_work")
        }
        
        private var label: SettingsListImageItemView {
            .init(
                cellTitle: title,
                subCellTitle: #localize("settings_threema_work_subtitle"),
                image: Image(uiImage: UIImage(resource: .threemaWorkSettings))
            )
        }
    }
    
    // MARK: - InviteSection
    
    struct InviteConsumerSection: View {
        var body: some View {
            Section {
                if let link = TargetManager.rateLink {
                    SectionItem(
                        action: {
                            UIApplication.shared.open(link, options: [:], completionHandler: nil)
                            
                        },
                        title: String.localizedStringWithFormat(
                            #localize("settings_list_rate"),
                            TargetManager.appName
                        ),
                        image: .systemImage("star.fill")
                    )
                }
                SectionItem(
                    action: inviteFriends,
                    title: #localize("settings_list_invite_a_friend_title"),
                    image: .systemImage("person.2.wave.2.fill")
                )
                SectionItem(
                    action: {
                        topViewController.map { AddThreemaChannelAction.run(in: $0) }
                    },
                    title: String.localizedStringWithFormat(
                        #localize("settings_list_threema_channel_title"),
                        TargetManager.localizedAppName
                    ),
                    image: .systemImage("antenna.radiowaves.left.and.right")
                )
            }
        }
        
        private func inviteFriends() {
            _ = topViewController.map { currentVC in
                InviteController().then {
                    $0.parentViewController = currentVC
                    $0.shareViewController = currentVC
                    $0.actionSheetViewController = currentVC
                    $0.rect = .zero
                    $0.invite()
                }
            }
        }
    }
    
    // MARK: - AboutSection
    
    struct AboutSection: View {
        var body: some View {
            Section {
                ItemSection {
                    if ThreemaURLProvider.supportFAQ != nil {
                        (
                            view: uiViewController(SettingsWebViewViewController(
                                url: ThreemaURLProvider.supportFAQ,
                                title: #localize("settings_list_support_title"),
                                allowsContentJavaScript: true
                            )),
                            title: #localize("settings_list_support_title"),
                            symbol: .systemImage("lightbulb.fill")
                        )
                    }
                    if !TargetManager.isOnPrem {
                        (
                            view: uiViewController(SettingsWebViewViewController(
                                url: ThreemaURLProvider.privacyPolicy,
                                title: #localize("settings_list_privacy_policy_title")
                            )),
                            title: #localize("settings_list_privacy_policy_title"),
                            symbol: .systemImage("lock.shield.fill")
                        )
                        (
                            view: uiViewController(SettingsWebViewViewController(
                                url: ThreemaURLProvider.termsOfService,
                                title: #localize("settings_list_tos_title")
                            )),
                            title: #localize("settings_list_tos_title"),
                            symbol: .systemImage("signature")
                        )
                    }
                    (
                        view: uiViewController(LicenseViewController()),
                        title: #localize("settings_list_license_title"),
                        symbol: .systemImage("c.circle")
                    )
                    (
                        view: AdvancedSettingsView(),
                        title: #localize("settings_advanced"),
                        symbol: .systemImage("ellipsis.circle.fill")
                    )
                }
            }
        }
    }
    
    // MARK: - RateBusinessSection
    
    struct RateBusinessSection: View {
        var body: some View {
            Section {
                if let link = TargetManager.rateLink {
                    SectionItem(
                        action: {
                            UIApplication.shared.open(link, options: [:], completionHandler: nil)
                            
                        },
                        title: String.localizedStringWithFormat(#localize("settings_list_rate"), TargetManager.appName),
                        image: .systemImage("star.fill")
                    )
                }
                if !TargetManager.isOnPrem {
                    SectionItem(
                        action: {
                            topViewController.map { AddThreemaWorkChannelAction.run(in: $0) }
                        },
                        title: String.localizedStringWithFormat(
                            #localize("settings_list_threema_work_channel_title"),
                            TargetManager.appName
                        ),
                        image: .systemImage("antenna.radiowaves.left.and.right")
                    )
                }
            }
        }
    }

    struct ItemSection: View {
        typealias Item = (view: any View, title: String, symbol: ThreemaImageResource)
        
        private var items: [Item]
        
        init(@ArrayBuilder<Item> _ items: () -> [Item]) {
            self.items = items()
        }
        
        var body: some View {
            buildSectionItems(items)
        }
        
        private func buildSectionItems(_ items: [Item]) -> some View {
            ForEach(items, id: \.title) { item in
                SectionItem(
                    destination: {
                        item.view.applyIf(item.view is (any UIViewControllerRepresentable)) { view in
                            view
                                .ignoresSafeArea(.all)
                                .asAnyView
                        }
                        .navigationBarTitle(
                            item.title,
                            displayMode: .inline
                        )
                    },
                    title: item.title,
                    image: item.symbol
                )
            }
        }
    }
}
