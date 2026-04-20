import SwiftUI

struct VotePollView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: VotePollViewModel
    
    @State private var showCloseConfirmation = false
    @State private var showDiscardVoteAlert = false
    @State private var closeAfterDiscard = false
    
    init(poll: BallotEntity) {
        self.init(pollID: poll.objectID)
    }
    
    init(pollID: NSManagedObjectID) {
        _viewModel = StateObject(wrappedValue: VotePollViewModel(pollID: pollID))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    buildPollSectionContent()
                } footer: {
                    if let footerText = viewModel.pollSectionFooterText {
                        Text(footerText)
                            .foregroundColor(.secondary)
                    }
                }
                
                if viewModel.poll?.isIntermediate == true {
                    Section {
                        buildIntermediateSectionContent()
                    }
                }
                
                if viewModel.showCloseButton {
                    buildCloseButton()
                }
            }
            .contentMargins(.top, 5)
            .listStyle(.insetGrouped)
            .frame(maxHeight: .infinity)
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    buildCancelButton()
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmationButton(title: viewModel.voteButtonTitle) {
                        viewModel.vote()
                        dismiss()
                    }
                    .disabled(!viewModel.isVoteEnabled)
                }
            }
            .onChange(of: viewModel.isDeleted) {
                guard viewModel.isDeleted else {
                    return
                }
                dismiss()
            }
            .onChange(of: viewModel.poll) {
                if viewModel.poll?.isClosed == true {
                    dismiss()
                }
            }
            .onAppear {
                viewModel.load()
            }
        }
        .interactiveDismissDisabled(true)
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder
    private func buildCancelButton() -> some View {
        CancelButton {
            if viewModel.didChangeSelection {
                showDiscardVoteAlert = true
            }
            else {
                dismiss()
            }
        }
        .alert(viewModel.cancelAlertTitle, isPresented: $showDiscardVoteAlert) {
            Button(viewModel.discardTitle, role: .destructive) {
                if closeAfterDiscard {
                    viewModel.close()
                }
                dismiss()
            }
            Button(viewModel.cancelTitle, role: .cancel) {
                // No-op
            }
        } message: {
            Text(viewModel.cancelAlertMessage)
        }
    }
    
    @ViewBuilder
    private func buildCloseButton() -> some View {
        HStack {
            Spacer()
            Button(viewModel.closeButtonTitle) {
                if viewModel.didChangeSelection {
                    showDiscardVoteAlert = true
                    closeAfterDiscard = true
                }
                else {
                    showCloseConfirmation = true
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .alert(viewModel.closeButtonTitle, isPresented: $showCloseConfirmation) {
            Button(viewModel.okTitle) {
                viewModel.close()
                dismiss()
            }
            
            Button(viewModel.cancelTitle, role: .cancel) {
                // No-op
            }
        } message: {
            Text(viewModel.closeAlertMessage)
        }
    }
    
    @ViewBuilder
    private func buildPollSectionContent() -> some View {
        VStack(alignment: .leading) {
            Text(viewModel.poll?.title ?? "")
                .font(.headline)
            Text(viewModel.pollVoteStateText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        
        if let poll = viewModel.poll {
            ForEach(poll.choices) { choice in
                let isSelected = viewModel.selectedChoices.contains(choice.id)
                Button {
                    viewModel.select(choice: choice)
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.accentColor)
                            }
                            else {
                                Image(systemName: "circle")
                                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                            }
                            Text(choice.text)
                        }
                        
                        if !poll.isSummary, poll.isIntermediate {
                            Spacer()
                            
                            Text(verbatim: "\(choice.votes)")
                                .contentTransition(.numericText())
                        }
                    }
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                }
            }
        }
    }
    
    @ViewBuilder
    private func buildIntermediateSectionContent() -> some View {
        NavigationLink(destination: ResultPollView(pollID: viewModel.pollID, hasNavigationView: false)) {
            Text(viewModel.showVotesButtonTitle)
        }
    }
}
