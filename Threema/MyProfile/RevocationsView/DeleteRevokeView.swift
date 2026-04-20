import SwiftUI

struct DeleteRevokeView: View {
    var alreadyDeleted = false
    var onDismiss: () -> Void
    
    @State private var successViewType: SuccessViewType = .delete
    @State private var tabSelection = 0
    
    var body: some View {
        TabView(selection: $tabSelection) {
            if !alreadyDeleted {
                DeleteRevokeOverviewView(tabSelection: $tabSelection) {
                    onDismiss()
                }
                .tag(0)
                RevokeView(tabSelection: $tabSelection, successViewType: $successViewType)
                    .tag(1)
            }
            DeleteRevokeSuccessView(successViewType: $successViewType)
                .tag(2)
        }
        .padding()
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeOut(duration: 2.0), value: tabSelection)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            UIScrollView.appearance().isScrollEnabled = false
        }
        .onDisappear {
            UIScrollView.appearance().isScrollEnabled = true
        }
        .navigationBarHidden(true)
        .dynamicTypeSize(.small ... .xxxLarge)
        .navigationBarBackButtonHidden(true)
    }
}

enum SuccessViewType {
    case delete, revoke
}

#Preview {
    DeleteRevokeView { }
        .preferredColorScheme(.dark)
}
