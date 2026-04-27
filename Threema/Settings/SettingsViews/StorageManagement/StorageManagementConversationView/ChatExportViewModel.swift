import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaMacros
import ZipArchive

final class ChatExportViewModel: ObservableObject {
    
    // MARK: - Types
    
    enum ExportViewState {
        case ready
        case exporting
        case zipping
        case error(text: String)
        case done
        
        var cancelButtonTitle: String {
            switch self {
            case .exporting, .zipping:
                #localize("cancel")
            case .ready, .error, .done:
                #localize("close")
            }
        }
    }
    
    enum ExportError: Error {
        case creatingExportDirectoryFailed
        case creatingConversationDirectoryFailed
        case encodingConversationFailed
        case unknownConversationType
        case extendingJSONFailed
        case encodingMessageFailed

        var errorMessage: String {
            switch self {
            case .creatingExportDirectoryFailed:
                "Creating export directory failed."
            case .creatingConversationDirectoryFailed:
                "Creating conversation directory failed."
            case .encodingConversationFailed:
                "Encoding conversation failed."
            case .unknownConversationType:
                "Unknown conversation type."
            case .extendingJSONFailed:
                "Extending JSON failed."
            case .encodingMessageFailed:
                "Encoding message failed."
            }
        }
    }
    
    // MARK: - Published properties
    
    @Published var viewState: ExportViewState = .ready
    @Published var startDate: Date? = nil
    @Published var endDate: Date? = nil
    @Published var url: URL? = nil
    
    @Published var progress = 0.0
    @Published var totalConversationCount = 0
    @Published var indexOfCurrentConversation = 0
    @Published var displayNameOfCurrentConversation: String?
    
    var exportSize: Double? {
        guard let url, let size = fileUtility.fileSizeInBytes(fileURL: url) else {
            return nil
        }
        
        return Double(size) / 1024.0 / 1024.0
    }

    private var exportTask: Task<Void, Never>? = nil
    private let businessInjector: BusinessInjectorProtocol
    private let fileUtility: FileUtilityProtocol
    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private lazy var exportDirectoryName =
        "\(TargetManager.appName.replacingOccurrences(of: " ", with: "_"))_Export_\(businessInjector.profileStore.profile.myIdentity.rawValue)_\(DateFormatter.getDateForExport(.now))"
    
    private lazy var exportDirectoryURL: URL = fileUtility.appTemporaryUnencryptedDirectory
        .appending(path: exportDirectoryName)
    
    private lazy var zipPath: String = {
        let exportDirectoryPath = exportDirectoryURL.path()
        return exportDirectoryPath + ".zip"
    }()
    
    // Localizable
    let navigationTitle = #localize("chat_export_title")
    let exportButtonTitle = #localize("chat_export_export_button_title")
    let shareButtonTitle = #localize("chat_export_share_button_title")
    let readyTitle = #localize("chat_export_title")
    let readyDescription = #localize("chat_export_ready_description")
    let errorTitle = #localize("chat_export_error_title")
    let errorDescription = #localize("chat_export_error_description")
    let conversationText = #localize("chat_export_conversation_count")
    let timerLabel = #localize("chat_export_timer_label")
    let memoryLabel = #localize("chat_export_memory")
    let zippingText = #localize("chat_export_zipping")
    let durationLabel = #localize("chat_export_duration")
    let peakMemoryLabel = #localize("chat_export_peak_memory")
    let exportSizeLabel = #localize("chat_export_size_label")
    let doneTitle = #localize("chat_export_done_title")
    let doneMessage = #localize("chat_export_done_message")

    // MARK: - Lifecycle
    
    init(businessInjector: BusinessInjectorProtocol, fileUtility: FileUtilityProtocol = FileUtility()) {
        self.businessInjector = businessInjector
        self.fileUtility = fileUtility
    }
    
    // MARK: - Public funcitons

    func export() {
        exportTask = Task {
            do {
                DDLogNotice("[ChatExport] Starting export.")
                
                Task { @MainActor in
                    startDate = .now
                    viewState = .exporting
                }
                
                // 1. Create directory to export chats to
                DDLogNotice("[ChatExport] Creating export directory.")
                try createExportDirectory()
                
                // 2. Get all conversation object IDS
                DDLogNotice("[ChatExport] Gathering conversation IDs to export.")
                let conversationObjectIDs: [NSManagedObjectID] = try businessInjector.entityManager.entityFetcher
                    .conversationIDsForExport()
                
                // 3. Export conversations
                DDLogNotice("[ChatExport] Exporting conversations. Count: \(conversationObjectIDs.count)")
                try exportConversations(conversationObjectIDs)
                
                // 4. Zip directory
                Task { @MainActor in
                    viewState = .zipping
                }
                DDLogNotice("[ChatExport] Started zipping.")
                let zipURL = createZip()
                
                // Remove data once zip is created
                fileUtility.deleteIfExists(at: exportDirectoryURL)
                
                // 5. Done
                Task { @MainActor in
                    url = zipURL
                    endDate = .now
                    viewState = .done
                }
                DDLogNotice("[ChatExport] Export completed.")
                exportTask = nil
            }
            catch {
                DDLogError("[ChatExport] Error: \(error)")
                
                // Cancel Task
                if exportTask != nil {
                    exportTask?.cancel()
                    exportTask = nil
                }
                
                // Update view
                let errorText: String =
                    if let exportError = error as? ExportError {
                        exportError.errorMessage
                    }
                    else {
                        "An unexpected error occurred: \(error.localizedDescription)"
                    }
                viewState = .error(text: errorText)
                
                // Delete files
                fileUtility.deleteIfExists(at: exportDirectoryURL)
                if let url {
                    fileUtility.deleteIfExists(at: url)
                }

                // Reset
                progress = 0.0
                startDate = nil
                endDate = nil
                url = nil
                totalConversationCount = 0
                indexOfCurrentConversation = 0
                displayNameOfCurrentConversation = nil
            }
        }
    }
    
    func share() {
        guard let url else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
    }
    
    func dismiss() {
        // Cancel task if still running
        exportTask?.cancel()
        
        // Remove created directory
        fileUtility.deleteIfExists(at: exportDirectoryURL)
        if let url {
            fileUtility.deleteIfExists(at: url)
        }
    }
    
    // MARK: - Private functions
  
    // MARK: Path handling

    private func createExportDirectory() throws {
        if fileUtility.fileExists(at: exportDirectoryURL) {
            DDLogNotice("[ChatExport] Remove existing files in export directory.")
            fileUtility.deleteIfExists(at: exportDirectoryURL)
        }
        
        do {
            DDLogNotice("[ChatExport] Creating export directory.")
            try fileUtility.mkDir(at: exportDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            throw ExportError.creatingExportDirectoryFailed
        }
    }
    
    private func createConversationDirectory(
        conversation: ConversationEntity
    ) throws -> URL {
        let dirName = try directoryName(for: conversation)
        let conversationDirectory = exportDirectoryURL.appending(path: dirName)
        
        guard !fileUtility.fileExists(at: conversationDirectory) else {
            DDLogError("[ChatExport] A directory already exists at the path: \(conversationDirectory.path). Aborting.")
            throw ExportError.creatingConversationDirectoryFailed
        }
        
        do {
            try fileUtility.mkDir(
                at: conversationDirectory,
                withIntermediateDirectories: false,
                attributes: nil
            )
        }
        catch {
            throw ExportError.creatingConversationDirectoryFailed
        }
        
        return conversationDirectory
    }
    
    private func directoryName(for conversation: ConversationEntity) throws -> String {
        // To mitigate identical group, distribution list and contact names, we add the ID to the directory name
        let dirName: String
        if conversation.isGroup, let groupID = conversation.groupID {
            if let groupName = conversation.groupName, !groupName.isEmpty {
                dirName = "\(groupName) ID \(groupID.hexString)"
            }
            else {
                dirName = "Unknown Group ID \(groupID.hexString)"
            }
        }
        else if let distributionList = conversation.distributionList {
            if let name = distributionList.name {
                dirName = "\(name) ID: \(distributionList.id)"
            }
            else {
                dirName = "Unknown DistributionList ID \(distributionList.id)"
            }
        }
        else if let contact = conversation.contact {
            dirName = "\(contact.displayName) ID \(contact.identity)"
        }
        else {
            throw ExportError.unknownConversationType
        }
        
        // We remove slashes
        let cleanName = dirName.replacingOccurrences(of: "/", with: "_")
        var cleanAndUniqueName = cleanName
        // We make sure such a dir does not exist
        var conversationDirectory = exportDirectoryURL.appending(path: cleanAndUniqueName)
        var int = 1
        while fileUtility.fileExists(at: conversationDirectory) {
            cleanAndUniqueName = cleanName + " (\(int))"
            int += 1
            conversationDirectory = exportDirectoryURL.appending(path: cleanAndUniqueName)
        }
        
        return cleanAndUniqueName
    }
    
    // MARK: - Export

    private func exportConversations(_ conversationObjectIDs: [NSManagedObjectID]) throws {
        
        // Update UI
        Task { @MainActor in
            totalConversationCount = conversationObjectIDs.count
        }
        
        // Iterate over all conversations
        for (index, conversationObjectID) in conversationObjectIDs.enumerated() {
            
            // Check if task has been cancelled
            guard let exportTask, !exportTask.isCancelled else {
                return
            }
            
            // Update progress
            Task { @MainActor in
                progress = min(Double(index) / Double(conversationObjectIDs.count), 99)
                indexOfCurrentConversation = index + 1
            }

            // Export
            try export(conversationID: conversationObjectID)
        }
        
        // Exporting done, update progress
        Task { @MainActor in
            progress = 1
            displayNameOfCurrentConversation = nil
        }
    }
    
    private func export(conversationID: NSManagedObjectID) throws {
        let entityManager = businessInjector.entityManager
       
        let (metaData, conversationDirectoryURL) = try entityManager.performAndWait {
            // 1. Fetch conversation
            guard let conversation = entityManager.entityFetcher
                .existingObject(with: conversationID) as? ConversationEntity else {
                throw ExportError.encodingConversationFailed
            }
            
            // 2. Create directory for conversation
            let conversationDirectoryURL = try self.createConversationDirectory(conversation: conversation)
            
            // 3. Create conversation object containing meta data
            let metaData = try ExportableConversation(
                conversation: conversation,
                ownIdentity: self.businessInjector.profileStore.profile.myIdentity.rawValue
            )
            
            return (metaData, conversationDirectoryURL)
        }
        
        // Update UI with current name
        Task { @MainActor in
            if let contactName = metaData.conversationMetadata?.contactName {
                displayNameOfCurrentConversation = contactName
            }
            else if let groupName = metaData.groupMetadata?.groupName {
                displayNameOfCurrentConversation = groupName
            }
            else {
                assertionFailure()
                displayNameOfCurrentConversation = "Unknown"
            }
        }
        
        // 4. Serialize
        let data: Data?
        do {
            data = try encoder.encode(metaData)
        }
        catch {
            throw ExportError.encodingConversationFailed
        }
        
        // 5. Write conversation info to file
        let chatContentsURL = conversationDirectoryURL.appending(path: "Messages")
        let mediaURL = conversationDirectoryURL.appendingPathComponent("Media")
        fileUtility.write(contents: data, to: chatContentsURL)
        
        // 6. Export Messages
        try exportMessages(conversationID: conversationID, chatContentsURL: chatContentsURL, mediaURL: mediaURL)
    }
    
    private func exportMessages(conversationID: NSManagedObjectID, chatContentsURL: URL, mediaURL: URL) throws {
        // Note:
        // We have to edit the JSON manually since we do not want to keep all messages of a conversation in memory at
        // once. The solution below aims at extending the JSON with conversation in a pretty printed format, but its not
        // 100% clean.
        
        let newline = "\n".data(using: .utf8)!
        let indent = "  ".data(using: .utf8)!
        
        let fileHandle = try FileHandle(forUpdating: chatContentsURL)
        defer { try? fileHandle.close() }
            
        // 1. Find the final '}' of the root object
        let fileSize = try fileHandle.seekToEnd()
        var offset: UInt64 = 1
        var foundBraceOffset: UInt64?
            
        while offset <= fileSize, offset < 100 {
            try fileHandle.seek(toOffset: fileSize - offset)
            if let byte = fileHandle.readData(ofLength: 1).first, byte == UInt8(ascii: "}") {
                foundBraceOffset = fileSize - offset
                break
            }
            offset += 1
        }
            
        guard let bracePos = foundBraceOffset else {
            DDLogError("[ChatExport] Brace position not found")
            throw ExportError.extendingJSONFailed
        }
            
        do {
            // 2. Prepare to insert the new key
            try fileHandle.seek(toOffset: bracePos)
            fileHandle.write(",".data(using: .utf8)!)
            fileHandle.write(newline)
            fileHandle.write(indent)
            fileHandle.write("\"messages\": [".data(using: .utf8)!)
        }
        catch {
            DDLogError("[ChatExport] Message array insertion failed")
            throw ExportError.extendingJSONFailed
        }
            
        // 3. Write the messages
        var isFirstItem = true
        try businessInjector.entityManager.performAndWait {
            
            // This provides the messages on by one in the closure
            try self.businessInjector.entityManager.entityFetcher
                .messagesForExport(inConversationsWithID: conversationID) { message in
                    
                    // We encode the message, if it has media, we will get the needed info in the closure, where it will
                    // be handled separately
                    let exportableMessage = try ExportableMessage(
                        businessInjector: self.businessInjector,
                        message: message,
                        ownIdentity: self.businessInjector.profileStore.profile.myIdentity.rawValue
                    ) { [weak self] data, name in
                        try self?.addMedia(url: mediaURL, data: data, fileName: name)
                    }
                            
                    let data = try self.encoder.encode(exportableMessage)
                            
                    guard let jsonString = String(data: data, encoding: .utf8) else {
                        DDLogError("[ChatExport] Encoding message failed.")
                        throw ExportError.encodingMessageFailed
                    }
                            
                    // Add a comma for all items except the first
                    if !isFirstItem {
                        fileHandle.write(",".data(using: .utf8)!)
                    }
                            
                    fileHandle.write(newline)
                            
                    // Re-indent every line of the encoded record
                    let indentation = "    " // 4 spaces
                    let indentedRecord = jsonString.components(separatedBy: "\n")
                        .map { indentation + $0 }
                        .joined(separator: "\n")
                            
                    guard let indentedData = indentedRecord.data(using: .utf8) else {
                        DDLogError("[ChatExport] Indenting message failed.")
                        throw ExportError.encodingMessageFailed
                    }
                    
                    fileHandle.write(indentedData)
                    isFirstItem = false
                }
        }
            
        // 4. Seal the array and the root object
        fileHandle.write(newline)
        fileHandle.write(indent)
        fileHandle.write("]".data(using: .utf8)!)
        fileHandle.write(newline)
        fileHandle.write("}".data(using: .utf8)!)
    }
    
    private func addMedia(url: URL, data: Data, fileName: String) throws {
        // We create the media directory if it does not exist yet
        if !fileUtility.fileExists(at: url) {
            try fileUtility.mkDir(at: url, withIntermediateDirectories: false, attributes: nil)
        }
        
        fileUtility.write(contents: data, to: url.appendingPathComponent(fileName))
    }
    
    // MARK: - Zipping
    
    private func createZip() -> URL {
        let exportDirectoryPath = exportDirectoryURL.path()
        SSZipArchive.createZipFile(atPath: zipPath, withContentsOfDirectory: exportDirectoryPath)
        
        return URL(fileURLWithPath: zipPath)
    }
    
    // MARK: - Exportable types
    
    fileprivate struct ExportableConversation: Encodable {
        let userIdentity: String
        var conversationType: String
        var groupMetadata: GroupMetadata?
        var conversationMetadata: ConversationMetadata?
        
        init(conversation: ConversationEntity, ownIdentity: String) throws {
            self.userIdentity = ownIdentity
            
            if conversation.isGroup {
                self.groupMetadata = GroupMetadata(conversation: conversation, ownIdentity: ownIdentity)
                self.conversationType = "Group"
            }
            else if conversation.distributionList != nil {
                assertionFailure()
                self.conversationType = "DistributionList"
            }
            else {
                self.conversationMetadata = ConversationMetadata(conversation: conversation, ownIdentity: ownIdentity)
                self.conversationType = "Direct"
            }
        }
        
        fileprivate struct GroupMetadata: Encodable {
            let creator: String
            let groupName: String
            let members: [String]
            
            init(conversation: ConversationEntity, ownIdentity: String) {
                guard conversation.isGroup else {
                    fatalError()
                }
                
                if let contact = conversation.contact {
                    self.creator = contact.identity
                }
                else {
                    self.creator = ownIdentity
                }
                
                self.groupName = conversation.displayName
                
                self.members = conversation.unwrappedMembers.map(\.identity) + [ownIdentity]
            }
        }
        
        fileprivate struct ConversationMetadata: Encodable {
            let contactIdentity: String
            let contactName: String
            
            init(conversation: ConversationEntity, ownIdentity: String) {
                guard !conversation.isGroup, let contact = conversation.contact else {
                    fatalError()
                }
                
                self.contactIdentity = contact.identity
                self.contactName = contact.displayName
            }
        }
    }
    
    fileprivate struct ExportableMessage: Encodable {
        let id: String
        let senderIdentity: String
        let timestamps: ExportableTimeStamps?
        let type: String
        let isStarred: Bool
        
        // Text
        var text: String?
        var replyTo: String?
        
        // File
        var caption: String?
        var consumed: Date?
        var fileDataAvailable: Bool?
        var filename: String?
        
        // Call
        var callDuration: String?
        
        // Location
        var accuracy: Double?
        var locationName: String?
        var locationAddress: String?
        var longitude: Double?
        var latitude: Double?
        
        // Poll
        var poll: ExportablePollMessage?
        
        // Edits
        var edits: [ExportableMessageEdit]?
        
        // Reactions
        var reactions: [ExportableMessageReaction]?
        
        init(
            businessInjector: BusinessInjectorProtocol,
            message: BaseMessageEntity,
            ownIdentity: String,
            dataExporter: (Data, String) throws -> Void
        ) throws {
            self.id = message.id.hexString
            
            // Sender
            if message.isOwnMessage {
                self.senderIdentity = ownIdentity
            }
            else if message.conversation.isGroup {
                self.senderIdentity = message.sender?.identity ?? "Unknown"
            }
            else {
                self.senderIdentity = message.conversation.contact?.identity ?? "Unknown"
            }
            
            // Timestamps
            self.timestamps = ExportableTimeStamps(message: message)
                        
            // Edits
            if let edits = message.historyEntries, !edits.isEmpty {
                var exportableEdits: [ExportableMessageEdit] = []
                for edit in edits {
                    exportableEdits.append(ExportableMessageEdit(edit: edit))
                }
                self.edits = exportableEdits
            }
            
            self.isStarred = message.hasMarkers
            
            // Reactions
            if let reactions = message.reactions, !reactions.isEmpty {
                var exportableReactions: [ExportableMessageReaction] = []
                for reaction in reactions {
                    exportableReactions.append(ExportableMessageReaction(reaction: reaction, ownIdentity: ownIdentity))
                }
                self.reactions = exportableReactions
            }
            
            // MARK: Types

            // Voice
            if let audioMessage = message as? AudioMessageEntity {
                self.type = "old_voice"
                self.caption = audioMessage.caption
                self.filename = audioMessage.blobExportFilename
                
                if let blobData = audioMessage.blobData {
                    self.fileDataAvailable = true
                    try dataExporter(blobData, audioMessage.blobExportFilename)
                }
                else {
                    self.fileDataAvailable = false
                }
            }
            // Poll
            else if let ballotMessage = message as? BallotMessageEntity, let poll = ballotMessage.ballot {
                self.type = "poll"
                self.poll = ExportablePollMessage(poll: poll, ownIdentity: ownIdentity)
            }
            
            // File
            else if let fileMessage = message as? FileMessageEntity {
                switch fileMessage.fileMessageType {
                case .voice:
                    self.type = "voice"
                case .image:
                    self.type = "image"
                case .file:
                    self.type = "file"
                case .video:
                    self.type = "video"
                case .animatedImage, .animatedSticker:
                    self.type = "gif"
                case .sticker:
                    self.type = "sticker"
                }
                
                self.caption = fileMessage.caption
                self.consumed = fileMessage.consumed
                self.filename = fileMessage.blobExportFilename
                
                if let blobData = fileMessage.blobData {
                    self.fileDataAvailable = true
                    try dataExporter(blobData, fileMessage.blobExportFilename)
                }
                else {
                    self.fileDataAvailable = false
                }
            }
            
            // Image
            else if let imageMessage = message as? ImageMessageEntity {
                self.type = "old_image"
                self.caption = imageMessage.caption
                self.filename = imageMessage.blobExportFilename

                if let blobData = imageMessage.blobData {
                    self.fileDataAvailable = true
                    try dataExporter(blobData, imageMessage.blobExportFilename)
                }
                else {
                    self.fileDataAvailable = false
                }
            }
            
            // Location
            else if let locationMessage = message as? LocationMessageEntity {
                self.type = "location"
                self.accuracy = locationMessage.accuracy?.doubleValue
                self.locationName = locationMessage.poiName
                self.locationAddress = locationMessage.poiAddress
                self.longitude = locationMessage.longitude.doubleValue
                self.latitude = locationMessage.latitude.doubleValue
            }
            
            // System
            else if let systemMessage = message as? SystemMessageEntity {
                switch systemMessage.systemMessageType {
                case let .callMessage(type: type):
                    self.type = "call"
                    self.text = type.localizedMessage
                    
                    if case let .endedIncomingSuccessful(duration: duration) = type {
                        self.callDuration = duration
                    }
                    if case let .endedOutgoingSuccessful(duration: duration) = type {
                        self.callDuration = duration
                    }
                    
                case let .systemMessage(type: type):
                    self.type = "status"
                    self.text = type.localizedMessage(businessInjector: businessInjector)
                    
                case let .workConsumerInfo(type: type):
                    self.type = "status"
                    self.text = type.localizedMessage
                }
            }
            
            // Text
            else if let textMessage = message as? TextMessageEntity {
                self.type = "text"
                self.text = textMessage.text
                self.replyTo = textMessage.quotedMessageID?.hexString
            }
            
            // Video
            else if let videoMessage = message as? VideoMessageEntity {
                self.type = "old_video"
                self.caption = videoMessage.caption
                self.filename = videoMessage.blobExportFilename

                if let blobData = videoMessage.blobData {
                    self.fileDataAvailable = true
                    try dataExporter(blobData, videoMessage.blobExportFilename)
                }
                else {
                    self.fileDataAvailable = false
                }
            }
            else {
                assertionFailure()
                self.type = "Unknown"
            }
        }
        
        fileprivate struct ExportableMessageEdit: Encodable {
            let editDate: Date?
            let text: String?
            
            init(edit: MessageHistoryEntryEntity) {
                self.editDate = edit.editDate
                self.text = edit.text
            }
        }
        
        fileprivate struct ExportableMessageReaction: Encodable {
            let date: Date?
            let reaction: String?
            let senderIdentity: String?
            
            init(reaction: MessageReactionEntity, ownIdentity: String) {
                self.date = reaction.date
                self.reaction = reaction.reaction
                self.senderIdentity = reaction.creator?.identity ?? ownIdentity
            }
        }
        
        fileprivate struct ExportablePollMessage: Encodable {
            let senderIdentity: String
            var createDate: Date?
            var choices: [ExportablePollChoice]?
            let isClosed: Bool
            let isIntermediate: Bool
            let isMultipleChoice: Bool
            let isSummary: Bool
            var participants: [String]?
            var title: String?
            
            init(poll: BallotEntity, ownIdentity: String) {
                self.senderIdentity = poll.creatorID ?? "Unknown"
                self.createDate = poll.createDate
               
                if let choices = poll.choices {
                    var exportableChoices = [ExportablePollChoice]()
                    for choice in choices {
                        exportableChoices.append(ExportablePollChoice(choice: choice))
                    }
                    self.choices = exportableChoices
                }
                
                self.isClosed = poll.isClosed
                self.isMultipleChoice = poll.isMultipleChoice
                self.isIntermediate = poll.isIntermediate
                self.isSummary = poll.isSummary
                    
                if let participants = poll.participants {
                    self.participants = Array(participants).map(\.identity)
                }
                
                if poll.localIdentityDidVote(myIdentity: ownIdentity) {
                    participants?.append(ownIdentity)
                }
                
                self.title = poll.title
            }
            
            fileprivate struct ExportablePollChoice: Encodable {
                let createDate: Date?
                let id: Int
                let modifyDate: Date?
                let name: String
                var orderPosition: Int?
                var totalVotes: Int?
                var votes: [ExportablePollVote]?
                
                init(choice: BallotChoiceEntity) {
                    self.createDate = choice.createDate
                    self.id = choice.id.intValue
                    self.modifyDate = choice.modifyDate
                    self.name = choice.name ?? "Unknown"
                    self.orderPosition = choice.orderPosition?.intValue
                    self.totalVotes = choice.totalVotes?.intValue
                    
                    if let votes = choice.result {
                        var exportableVotes: [ExportablePollVote] = []
                        for vote in votes {
                            exportableVotes.append(ExportablePollVote(vote: vote))
                        }
                        self.votes = exportableVotes
                    }
                }
            }
            
            fileprivate struct ExportablePollVote: Encodable {
                let createDate: Date?
                let modifyDate: Date?
                let value: Int
                let voterID: String
                
                init(vote: BallotResultEntity) {
                    self.createDate = vote.createDate
                    self.modifyDate = vote.modifyDate
                    self.value = vote.value?.intValue ?? 0
                    self.voterID = vote.participantID
                }
            }
        }
    
        fileprivate struct ExportableTimeStamps: Encodable {
            let createdAt: Date
            let sentAt: Date?
            var receivedAt: Date?
            var readAt: Date?
            var deletedAt: Date?
            var lastEditedAt: Date?
            
            init(message: BaseMessageEntity) {
                self.createdAt = message.date ?? Date(timeIntervalSince1970: 0)
                self.sentAt = message.date(for: .sent)
                self.receivedAt = message.date(for: .delivered)
                self.readAt = message.date(for: .read)
                self.deletedAt = message.deletedAt
                self.lastEditedAt = message.lastEditedAt
            }
        }
    }
}
