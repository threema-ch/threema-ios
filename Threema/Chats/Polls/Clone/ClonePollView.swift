import SwiftUI
import ThreemaMacros

struct ClonePollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = ClonePollViewModel()
    
    var onPollSelected: (Poll) -> Void
    
    var body: some View {
        List {
            ForEach($viewModel.pollIDs) { $pollID in
                if let poll = viewModel.load(for: pollID) {
                    PollRowView(title: poll.title, creator: poll.creator?.label, created: poll.created) {
                        onPollSelected(poll)
                        dismiss()
                    }
                }
            }
        }
        .contentMargins(.top, 5)
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle(#localize("ballot_choose_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }
}
