import SwiftUI
import ThreemaMacros

struct LinkEmailDeciderView: View {
    @ObservedObject var viewModel = LinkEmailViewModel()

    var body: some View {
        VStack {
            switch viewModel.linkingState {
            case .determing:
                ProgressView()
            case .unlinked:
                LinkEmailUnlinkedView(viewModel: viewModel)
            case .verifying:
                LinkEmailVerifyView(viewModel: viewModel)
            case .linked:
                LinkEmailLinkedView(viewModel: viewModel)
            }
        }
        .navigationTitle(#localize("profile_linked_email"))
    }
}

#Preview {
    LinkEmailDeciderView()
}
