import SwiftUI
import ThreemaMacros

struct LinkPhoneNumberDeciderView: View {
    @ObservedObject var viewModel = LinkPhoneNumberViewModel()

    var body: some View {
        VStack {
            switch viewModel.linkingState {
            case .determing:
                ProgressView()
            case .unlinked:
                LinkPhoneNumberUnlinkedView(viewModel: viewModel)
            case .verifying:
                LinkPhoneNumberVerifyView(viewModel: viewModel)
            case .linked:
                LinkPhoneNumberLinkedView(viewModel: viewModel)
            }
        }
        .navigationTitle(#localize("profile_linked_phone"))
    }
}
