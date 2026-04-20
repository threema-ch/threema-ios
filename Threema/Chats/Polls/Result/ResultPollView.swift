import SwiftUI

struct ResultPollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: ResultPollViewModel
    
    @State private var showCloseConfirmation = false
    @State private var showDiscardVoteAlert = false
    
    let hasNavigationView: Bool
    
    init(poll: BallotEntity, hasNavigationView: Bool = true) {
        self.init(pollID: poll.objectID, hasNavigationView: hasNavigationView)
    }
    
    init(pollID: NSManagedObjectID, hasNavigationView: Bool = true) {
        self._viewModel = StateObject(wrappedValue: ResultPollViewModel(pollID: pollID))
        self.hasNavigationView = hasNavigationView
    }
    
    var body: some View {
        if hasNavigationView {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
        else {
            content
        }
    }
    
    @ViewBuilder
    private var content: some View {
        List {
            Section {
                pollHeader
            }
            
            if let poll = viewModel.poll {
                ForEach(
                    Array(
                        poll
                            .choices
                            .sorted { $0.votes > $1.votes }
                            .enumerated()
                    ),
                    id: \.1.id
                ) { index, choice in
                    buildChoiceGroup(choice, index: index)
                }
                
                if !poll.isSummary, !poll.nonRespondents.isEmpty {
                    buildNonRespondent(poll.nonRespondents)
                }
            }
        }
        .contentMargins(.top, 5)
        .listStyle(.insetGrouped)
        .navigationTitle(
            viewModel.navigationTitle
        )
        .navigationBarTitleDisplayMode(.inline)
        .applyIf(hasNavigationView) { view in
            view.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DoneButton {
                        dismiss()
                    }
                    .accessibilityIdentifier("ResultPollViewDoneButton")
                }
            }
        }
        .onChange(of: viewModel.isDeleted) {
            guard viewModel.isDeleted else {
                return
            }
            dismiss()
        }
        .onAppear {
            viewModel.load()
        }
    }
    
    @ViewBuilder
    private var pollHeader: some View {
        VStack(alignment: .leading) {
            Text(viewModel.headerTitle)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let headerText = viewModel.headerText {
                Text(headerText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    @ViewBuilder
    private func buildChoiceGroup(_ choice: Poll.Choice, index: Int) -> some View {
        let maxVotes = viewModel.poll?.choices.map(\.votes).max() ?? 0
        let isMostVoted = choice.votes == maxVotes && maxVotes > 0
        
        Section {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { viewModel.expandedStates[choice.id] ?? false },
                    set: { viewModel.expandedStates[choice.id] = $0 }
                )
            ) {
                ForEach(choice.voters) { voter in
                    buildVoterRow(voter)
                        .listRowInsets(EdgeInsets(top: 8, leading: -4, bottom: 8, trailing: 20))
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(choice.text)
                            .font(.subheadline)
                        
                        Text(
                            String(
                                format: viewModel.pollVotesCount,
                                choice.votes
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isMostVoted {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            if index == 0 {
                Text(viewModel.choicesTitle)
            }
        }
        .listSectionSpacing(.compact)
        .disabled(choice.voters.isEmpty)
    }
    
    @ViewBuilder
    private func buildNonRespondent(_ voters: [PollVoter]) -> some View {
        Section(viewModel.noVotesTitle) {
            ForEach(voters) { voter in
                buildVoterRow(voter)
            }
        }
    }
    
    @ViewBuilder
    private func buildVoterRow(_ voter: PollVoter) -> some View {
        HStack {
            if let image = voter.profilePicture {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            }
            
            Text(voter.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
