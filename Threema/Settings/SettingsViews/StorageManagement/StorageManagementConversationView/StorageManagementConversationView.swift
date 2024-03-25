//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import ThreemaFramework

struct StorageManagementConversationView: View {
    @Environment(\.sizeCategory) var sizeCategory
    @ObservedObject var messageModel: MessageRetentionManagerModel
    @ObservedObject var model: Model
    
    init(businessInjector: BusinessInjectorProtocol, model: Model) {
        self.messageModel = businessInjector.messageRetentionManager as! MessageRetentionManagerModel
        self.model = model
    }
    
    var body: some View {
        ScrollView {
            VStack {
                headerView
                sections
                    .disabled(model.deleteInProgress)
                
                if messageModel.isMDM {
                    HStack(alignment: .center) {
                        Text("disabled_by_device_policy".localized)
                            .font(.footnote)
                            .foregroundColor(Color(uiColor: Colors.textLight))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("storage_management".localized)
        .onAppear {
            model.refresh()
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        if model.isSingleConversation {
            DetailsHeaderView(
                with: .init(
                    avatarImageProvider: model.avatarImageProvider(completion:),
                    name: model.conversationName
                )
            ) { }.selfSizingWrappedView
        }
    }
    
    @ViewBuilder
    private var sections: some View {
        SectionView(amount: $model.totalMessagesCount, section: .messages) {
            showActionSheet(.messages)
        }
        
        SectionView(amount: $model.totalMediaCount, section: .files) {
            showActionSheet(.files)
        }
        .padding(.bottom, 8)
        
        if !model.isSingleConversation {
            StorageView(bodyText: Section.messageRetention.localizedDescription) {
                MessageRetentionView(
                    model: messageModel,
                    selection: OlderThanOption.retentionOption(from: messageModel.selection)
                )
                .environmentObject(model)
            } header: {
                LabelHeader(
                    symbol: Section.messageRetention.symbol,
                    title: Section.messageRetention.localizedTitle,
                    secondary: ""
                )
            }
        }
    }
    
    private func showActionSheet(_ type: ActionSheetType) {
        guard let topVC = AppDelegate.shared().currentTopViewController(), let view = topVC.view else {
            return
        }
        
        let actionHandler: (OlderThanOption) -> Void = { option in
            switch type {
            case .messages:
                UIAlertTemplate.showConfirm(
                    title: option.deleteMessageConfirmationSentence,
                    titleOk: type.title,
                    on: topVC
                ) {
                    model.messageDelete(option)
                }
            case .files:
                UIAlertTemplate.showConfirm(
                    title: option.deleteMediaConfirmationSentence,
                    titleOk: type.title,
                    on: topVC
                ) {
                    model.mediaDelete(option)
                }
            }
        }
        
        let actionSheet = UIAlertController(
            title: type.title,
            message: type.description,
            preferredStyle: .actionSheet
        ).then {
            for option in OlderThanOption.allDeleteCases {
                $0.addAction(
                    UIAlertAction(
                        title: option.localizedTitleDescription,
                        style: .destructive,
                        handler: { _ in
                            actionHandler(option)
                        }
                    )
                )
            }
            $0.addAction(UIAlertAction(title: "cancel".localized, style: .cancel))
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
                $0.popoverPresentationController?.sourceRect = view.bounds
                $0.popoverPresentationController?.sourceView = view
            }
        }
        topVC.present(actionSheet, animated: true)
    }
}