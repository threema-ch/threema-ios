import SwiftUI
import ThreemaFramework
import ThreemaMacros

struct StorageManagementConversationView: View {
    let businessInjector: BusinessInjectorProtocol
   
    @Environment(\.sizeCategory) var sizeCategory
    @ObservedObject var messageModel: MessageRetentionManagerModel
    @ObservedObject var model: Model
   
    @State var showExport = false
    
    init(businessInjector: BusinessInjectorProtocol, conversation: ConversationEntity? = nil) {
        self.businessInjector = businessInjector
        self.messageModel = businessInjector.messageRetentionManager as! MessageRetentionManagerModel
        self.model = .init(conversation: conversation, businessInjector: businessInjector)
    }
    
    var body: some View {
        ScrollView {
            VStack {
                headerView
                sections
                    .disabled(model.deleteInProgress)
                
                if messageModel.isMDM {
                    HStack(alignment: .center) {
                        Text(#localize("disabled_by_device_policy"))
                            .font(.footnote)
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .sheet(isPresented: $showExport) {
                StorageManagementChatExportView(
                    viewModel: ChatExportViewModel(businessInjector: BusinessInjector(forBackgroundProcess: true))
                )
            }
        }
        .navigationTitle(#localize("storage_management"))
        .task(model.load)
        .background(UIColor.systemGroupedBackground.color)
    }
    
    @ViewBuilder
    private var headerView: some View {
        if let contact = model.contact {
            DetailsHeaderView(
                with: .init(
                    profilePictureInfo: .contact(contact),
                    name: model.conversationName
                )
            ) { }.selfSizingWrappedView
        }
        else if let group = model.group {
            DetailsHeaderView(
                with: .init(
                    profilePictureInfo: .group(group),
                    name: model.conversationName
                )
            ) { }.selfSizingWrappedView
        }
        else {
            DetailsHeaderView(
                with: .init(
                    profilePictureInfo: .contact(nil),
                    name: model.conversationName
                )
            ) { }.selfSizingWrappedView
        }
    }
    
    @ViewBuilder
    private var sections: some View {
        if model.canExport {
            GroupBox(
                label: Label(#localize("chat_export_title"), systemImage: "square.and.arrow.up"),
                content: {
                    Text(#localize("chat_export_description"))
                        .padding(.top, 1)
                        .padding(.bottom, 8)
                        .font(.footnote)
                    Spacer()
                    
                    Button {
                        showExport = true
                    }
                    label: {
                        Text(#localize("chat_export_button_title"))
                            .font(.headline)
                            .padding(4)
                            .frame(maxWidth: .infinity)
                    }
                }
            )
            .groupBoxStyle(.storageManagement)
        }
        
        SectionView(amount: $model.totalMessagesCount, section: .messages) {
            showActionSheet(.messages)
        }
        
        SectionView(amount: $model.totalMediaCount, section: .files) {
            showActionSheet(.files)
        }
        .padding(.bottom, 8)
        
        // TODO: (IOS-5768) We added the temporary fix to remove draft for a conversation in `safeMode`. See ticket for more information.
        if SettingsBundleHelper.safeMode {
            Button(role: .destructive) {
                model.deleteDraft()
            } label: {
                Text(verbatim: "Delete Draft")
            }
            .buttonStyle(.bordered)
        }
        
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
            $0.addAction(UIAlertAction(title: #localize("cancel"), style: .cancel))
            if topVC.traitCollection.horizontalSizeClass == .regular {
                $0.popoverPresentationController?.sourceRect = view.bounds
                $0.popoverPresentationController?.sourceView = view
            }
        }
        topVC.present(actionSheet, animated: true)
    }
}
