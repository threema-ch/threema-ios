import SwiftUI

struct ListPollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: ListPollViewModel
    
    private var onDisappear: (() -> Void)?

    init(
        entityManager: EntityManager,
        conversation: ConversationEntity,
        onDisappear: (() -> Void)? = nil,
        onDelete: (([NSManagedObjectID]) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ListPollViewModel(
            conversationID: conversation.objectID,
            entityManager: entityManager,
            onDelete: onDelete
        ))
        self.onDisappear = onDisappear
    }
    
    var body: some View {
        NavigationView {
            List {
                if !viewModel.openPollIDs.isEmpty {
                    Section(viewModel.openBallotsTitle) {
                        openSection
                    }
                }
                if !viewModel.closedPollIDs.isEmpty {
                    Section(viewModel.closedBallotsTitle) {
                        closedSection
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DoneButton {
                        dismiss()
                    }
                    .accessibilityIdentifier("ListPollViewDoneButton")
                }
            }
            .sheet(item: $viewModel.selectedPoll) {
                Task {
                    await viewModel.load()
                }
            } content: { poll in
                if poll.isClosed {
                    ResultPollView(pollID: poll.id)
                }
                else {
                    VotePollView(pollID: poll.id)
                }
            }
            .onAppear {
                Task {
                    await viewModel.load()
                }
            }
            .alert(viewModel.deleteAlertTitle, isPresented: $viewModel.showDeleteAlert) {
                Button(viewModel.deleteAlertOkButtonTitle, role: .none) {
                    // Noop
                }
            }

            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationViewStyle(.stack)
            .loadingOverlay(viewModel.isLoading)
            .onDisappear {
                onDisappear?()
            }
        }
    }
    
    @ViewBuilder
    var openSection: some View {
        ForEach($viewModel.openPollIDs) { $pollID in
            if let poll = viewModel.load(for: pollID) {
                rowForPoll(poll)
            }
        }
        .onDelete(perform: deleteOpenPoll)
    }
    
    @ViewBuilder
    var closedSection: some View {
        ForEach($viewModel.closedPollIDs) { $pollID in
            if let poll = viewModel.load(for: pollID) {
                rowForPoll(poll)
            }
        }
        .onDelete(perform: deleteClosedPoll)
    }
    
    @ViewBuilder
    private func rowForPoll(_ poll: Poll) -> some View {
        PollRowView(title: poll.title, creator: poll.creator?.label, created: poll.created) {
            viewModel.selectPoll(poll)
        }
    }
    
    func deleteClosedPoll(at offsets: IndexSet) {
        if let index = offsets.first {
            viewModel.deletePoll(at: index, closedPoll: true)
        }
    }
    
    func deleteOpenPoll(at offsets: IndexSet) {
        if let index = offsets.first {
            viewModel.deletePoll(at: index, closedPoll: false)
        }
    }
}
