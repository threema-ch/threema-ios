import SwiftUI
import ThreemaMacros

struct ChatViewSpamReportingBanner: View {
    
    enum ReportAction {
        case report
        case reportBlockAndDelete
    }
    
    enum ConversationType {
        case oneToOne(displayName: String?)
        case group(displayName: String)
    }
    
    let conversationType: ConversationType
    let reportAction: (ReportAction) -> Void
    let notSpamAction: () -> Void
    
    @State private var showConfirmation: Bool = false
    
    var body: some View {
        VStack {
            Text(bannerText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            AdaptiveStack {
                Button {
                    notSpamAction()
                } label: {
                    Text(#localize("chat_view_spam_reporting_banner_not_spam_button"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .apply { view in
                    if #available(iOS 27.0, *) {
                        view
                            .glassEffect()
                    }
                    else if #available(iOS 26.0, *) {
                        view
                            .overlay(
                                // cornerRadius is big enough that it covers all dynamic type sizes
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .strokeBorder(.tint, lineWidth: 0.3)
                            )
                    }
                    else {
                        view
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.tint, lineWidth: 0.3)
                            )
                    }
                }
                
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Text(#localize("chat_view_spam_reporting_banner_button"))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .apply { view in
                    if #available(iOS 27.0, *) {
                        view
                            .glassEffect()
                    }
                    else {
                        view
                    }
                }
                .confirmationDialog(
                    confirmationDialogTitle,
                    isPresented: $showConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        reportAction(.report)
                    } label: {
                        Text(#localize("chat_view_spam_reporting_banner_confirmation_report_button"))
                    }
                    
                    Button(role: .destructive) {
                        reportAction(.reportBlockAndDelete)
                    } label: {
                        Text(#localize("chat_view_spam_reporting_banner_confirmation_report_block_delete_button"))
                    }
                    
                    Button(#localize("cancel"), role: .cancel) {
                        // no-op
                    }
                } message: {
                    Text(confirmationDialogText)
                }
            }
        }
        .padding(4) // A little extra padding for a better visual appearance
        .padding()
        .apply { view in
            if #available(iOS 26.0, *) {
                view
                    .glassEffect(
                        .regular,
                        // Ensure the concentric corners don't grow too big for XXX Large and bigger
                        in: RoundedRectangle(cornerRadius: 40, style: .continuous)
                    )
            }
            else {
                view
                    .background(.regularMaterial)
                    .cornerRadius(12)
            }
        }
    }
    
    private var bannerText: String {
        switch conversationType {
        case .oneToOne:
            #localize("chat_view_spam_reporting_banner_text")
        case .group:
            #localize("chat_view_spam_reporting_banner_group_text")
        }
    }
    
    private var confirmationDialogTitle: String {
        switch conversationType {
        case let .oneToOne(displayName?):
            String.localizedStringWithFormat(
                #localize("chat_view_spam_reporting_banner_confirmation_title_with_nickname"),
                displayName
            )
        case .oneToOne(nil):
            #localize("chat_view_spam_reporting_banner_confirmation_title")
        case let .group(displayName):
            String.localizedStringWithFormat(
                #localize("chat_view_spam_reporting_banner_group_confirmation_title_with_group_name"),
                displayName
            )
        }
    }
    
    private var confirmationDialogText: String {
        switch conversationType {
        case .oneToOne:
            #localize("chat_view_spam_reporting_banner_confirmation_text")
        case .group:
            #localize("chat_view_spam_reporting_banner_group_confirmation_text")
        }
    }
}

#Preview("With Nickname") {
    ZStack(alignment: .top) {
        Color.green
            .ignoresSafeArea()
        
        VStack {
            ChatViewSpamReportingBanner(conversationType: .oneToOne(displayName: "~fooBar")) { action in
                print("Reported: \(action)")
            } notSpamAction: {
                print("No Spam selected")
            }
            .padding()
        }
    }
}

#Preview("Without Nickname") {
    VStack {
        ChatViewSpamReportingBanner(conversationType: .oneToOne(displayName: nil)) { action in
            print("Reported: \(action)")
        } notSpamAction: {
            print("No Spam selected")
        }
        .padding()
    }
    .padding(.bottom, 500)
}

#Preview("Group") {
    VStack {
        ChatViewSpamReportingBanner(conversationType: .group(displayName: "Foo Bar Group")) { action in
            print("Reported: \(action)")
        } notSpamAction: {
            print("No Spam selected")
        }
        .padding()
    }
    .padding(.bottom, 500)
}
