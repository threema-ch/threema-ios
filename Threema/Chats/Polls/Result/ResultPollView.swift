//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
                ForEach(Array(poll.choices.enumerated()), id: \.1.id) { index, choice in
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.doneTitle) {
                        dismiss()
                    }
                    .accessibilityIdentifier("ResultPollViewDoneButton")
                }
            }
        }
        .onChange(of: viewModel.isDeleted) { value in
            guard value else {
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
    private func buildNonRespondent(_ voters: [Poll.Voter]) -> some View {
        Section(viewModel.noVotesTitle) {
            ForEach(voters) { voter in
                buildVoterRow(voter)
            }
        }
    }
    
    @ViewBuilder
    private func buildVoterRow(_ voter: Poll.Voter) -> some View {
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
