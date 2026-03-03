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
import ThreemaFramework
import ThreemaMacros

@MainActor
final class CreatePollViewModel: ObservableObject {
    
    // MARK: - Constants
    
    private enum Constants {
        static let minChoicesCount = 2
    }
    
    // MARK: - Internal type
    
    public struct Choice: Identifiable {
        let id = UUID()
        var text: String
        var date: Date = .now
    }
    
    // MARK: - State
    
    @Published var title = "" {
        didSet {
            onTitleChanged()
        }
    }

    @Published var choices: [Choice] = [] {
        didSet {
            choicesChanged()
        }
    }

    @Published var allowMultipleSelection = false
    @Published var showIntermediateResult = true
    @Published var isSendEnabled = false
    @Published var isLoading = false
    @Published var isCloneEnabled = true
    @Published var isEditEnabled = false

    // MARK: - Public properties
    
    var pollType: BallotEntity.BallotType {
        showIntermediateResult ? .intermediate : .closed
    }
    
    var pollAssessmentType: BallotEntity.BallotAssessmentType {
        allowMultipleSelection ? .multi : .single
    }
    
    let titleSectionHeaderTitle = #localize("poll_title_section_header")
    let titlePlaceholder = #localize("ballot_placeholder_title")
    let choicesSectionHeaderTitle = #localize("ballot_options")
    let choicePlaceholder = #localize("ballot_placeholder_choice")
    let choicesEditTitle = #localize("edit")

    let intermediateResultLabelText = #localize("ballot_show_intermediate_results")
    let multipleChoiceLabelText = #localize("ballot_multiple_choice")

    let cloneTitle = #localize("ballot_clone")
    let cloneFooterText = #localize("poll_clone_footer")

    let cancelText = #localize("cancel")
    let sendText = #localize("send")
    
    let navigationTitle = #localize("ballot_create")

    // MARK: - Private properties

    private let conversationID: NSManagedObjectID

    private lazy var messageSender = BusinessInjector.ui.messageSender
    private lazy var entityManager = BusinessInjector.ui.entityManager
    private lazy var manager = BallotManager(entityManager: entityManager)
    
    // MARK: - Lifecycle
    
    init(conversationID: NSManagedObjectID) {
        self.conversationID = conversationID
        self.choices = (0..<Constants.minChoicesCount).map { _ in Choice(text: "") }
    }
    
    // MARK: - Public functions
    
    func create() async {
        guard validate() else {
            return
        }
        
        defer {
            isLoading = false
        }
        
        isLoading = true
        
        await entityManager.performSave { [weak self] in
            guard let self else {
                return
            }
            
            let trimmedChoices = choices.map {
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let poll = manager.create(
                with: title.trimmingCharacters(in: .whitespacesAndNewlines),
                choices: trimmedChoices.filter { !$0.isEmpty },
                type: pollType,
                assessmentType: pollAssessmentType,
                conversation: conversationID
            )
            
            messageSender.sendBallotMessage(for: poll)
        }
    }
    
    func clone(_ poll: Poll) {
        title = poll.title ?? ""
        choices = poll
            .choices
            .sorted { $0.order < $1.order }
            .map { Choice(text: $0.text) }
        
        showIntermediateResult = poll.isIntermediate
        allowMultipleSelection = poll.isMultiSelection
    }
    
    func deleteChoice(at index: Int) {
        withAnimation {
            choices.remove(atOffsets: IndexSet(integer: index))
            
            // Always keep 2 choices
            if choices.count < 2 {
                choices.append(Choice(text: ""))
            }
        }
    }

    func removeChoice(at index: Int) {
        // Always keep 2 choices
        if choices.count <= 2 || index == choices.count - 1 {
            return
        }
        
        withAnimation {
            choices.remove(atOffsets: IndexSet(integer: index))
        }
    }
    
    func relocate(from source: IndexSet, to destination: Int) {
        withAnimation {
            choices.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    // MARK: - Private functions
    
    private func validate() -> Bool {
        if title.isEmpty {
            return false
        }

        let validChoices = choices.filter { !$0.text.isEmpty }
        if validChoices.count < Constants.minChoicesCount {
            return false
        }

        return true
    }
    
    private func setCloneEnabled() -> Bool {
        title.isEmpty && choices.allSatisfy(\.text.isEmpty)
    }
    
    private func setEditEnabled() -> Bool {
        !choices.allSatisfy(\.text.isEmpty)
    }

    private func choicesChanged() {
        isSendEnabled = validate()
        isCloneEnabled = setCloneEnabled()
        isEditEnabled = setEditEnabled()
        
        Task { @MainActor in
            guard choices.allSatisfy({ !$0.text.isEmpty }) else {
                return
            }
            
            withAnimation {
                choices.append(Choice(text: ""))
            }
        }
    }

    private func onTitleChanged() {
        isSendEnabled = validate()
        isCloneEnabled = setCloneEnabled()
    }
}
