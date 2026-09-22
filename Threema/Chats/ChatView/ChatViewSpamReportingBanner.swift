import SwiftUI
import ThreemaMacros

struct ChatViewSpamReportingBanner: View {
    
    enum ReportAction {
        case report
        case reportBlockAndDelete
    }
    
    let displayName: String?
    let reportAction: (ReportAction) -> Void
    
    @State private var showConfirmation: Bool = false
    
    var body: some View {
        AdaptiveStack {
            Text(#localize("chat_view_spam_reporting_banner_text"))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 12)
            
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Text(#localize("chat_view_spam_reporting_banner_button"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
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
                Text(#localize("chat_view_spam_reporting_banner_confirmation_text"))
            }
        }
        .padding(.leading, 8) // A little extra leading padding for a better visual appearance
        .padding()
        .apply { view in
            if #available(iOS 26.0, *) {
                view
                    .glassEffect(
                        .regular,
                        // Ensure the concentric corners don't grow too big for XXX Large and bigger
                        in: RoundedRectangle(cornerRadius: 50, style: .continuous)
                    )
            }
            else {
                view
                    .background(.regularMaterial)
                    .cornerRadius(12)
            }
        }
    }
    
    private var confirmationDialogTitle: String {
        if let displayName {
            String.localizedStringWithFormat(
                #localize("chat_view_spam_reporting_banner_confirmation_title_with_nickname"),
                displayName
            )
        }
        else {
            #localize("chat_view_spam_reporting_banner_confirmation_title")
        }
    }
}

#Preview("With Nickname") {
    ZStack(alignment: .top) {
        Color.green
            .ignoresSafeArea()
        
        VStack {
            ChatViewSpamReportingBanner(displayName: "~fooBar") { action in
                print("Reported: \(action)")
            }
            .padding()
            
            Text(
                verbatim: "Note: For a correct preview of XXX Large and bigger you need to comment out the Spacer above"
            )
            .padding()
        }
    }
}

#Preview("Without Nickname") {
    VStack {
        ChatViewSpamReportingBanner(displayName: nil) { action in
            print("Reported: \(action)")
        }
        .padding()
        
        Text(verbatim: "Note: For a correct preview of XXX Large and bigger you need to comment out the Spacer above")
            .padding()
    }
    .padding(.bottom, 500)
}
