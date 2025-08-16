//
//  MacContentView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 16/08/2025.
//

#if os(macOS)
import SwiftUI
import AppKit
import HighlightedTextEditor
import MarkdownUI
import CosmicSDK
import SwiftData
import FoundationModels

@MainActor
struct MacContentView: View {
    @Binding var document: Cosmic_WriterDocument
    @Environment(\.modelContext) private var modelContext
    @Query private var shelfImages: [ShelfImage]
    
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @State private var openSettings: Bool = false
    @State private var tag = PostTag.design.rawValue
    @State private var focusMode: Bool = true
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var textView: NSTextView? = nil
    @State private var observers: [NSObjectProtocol] = []
    @State private var isSending: Bool = false
    @State private var showToast: Bool = false
    @State private var toastOffset: CGFloat = 100
    @State private var isUploading: Bool = false
    @State private var imageError: String?
    @State private var toastMessage: String = ""
    @State private var isGeneratingContent: Bool = false
    @State private var showGeneratingToast: Bool = false
    @State private var editorModel = HighlightedTextModel()
    @State private var showEditInput: Bool = false
    @State private var editText: String = ""
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var pendingAIText: String? = nil
    @State private var showReviewSheet: Bool = false
    
    // Add state for scheduled date
    @State private var scheduledDate: Date? = nil
    @State private var showScheduleDatePicker = false

    
    // Add state for inline suggestions
    @State private var showPostSuggestions = false
    @State private var atSymbolPosition: Int? = nil
    @State private var postSearchText = ""
    @StateObject private var postCache = PostCache()
    @State private var suggestionPosition: CGPoint = .zero
    
    // Filter images for current document
    private var documentImages: [ShelfImage] {
        shelfImages.filter { $0.documentID == document.filePath }
    }
    
    // Add these computed properties to both iOSContentView and MacContentView
    private var characterCount: Int {
        document.text.count
    }
    
    private var wordCount: Int {
        document.text.wordCount
    }
    
    private var readingTime: Int {
        document.text.estimatedReadingTime
    }
    
    private var statsText: String {
        "\(characterCount) characters • \(wordCount) words • \(readingTime) min read"
    }
    
    private var instructions: String {
        """
        You are Karl Emil James Koch, you craft compelling content, weaving a narrative centred on AI, product development, and occasionally the fusion of design and engineering when it's relevant. Your job is to convey ideas with clarity and engage readers without dividing the content into sections with headings.
        
        Guidelines to follow:
        1. Adopt a conversational yet insightful tone, balancing depth with clarity.
        2. Dive into the overlap of design and engineering, especially AI and search products, only when it naturally fits.
        3. Prioritise taste and human judgement in discussions about design.
        4. Explore how code democratization breaks down the barriers between design and development.
        5. Emphasise real-world applications, steering clear of theoretical discussions.
        6. Use crisp, precise language, maintaining British English spellings and terminology ALWAYS (e.g., colour, centre, organisation, analyse, realise, programme, theatre, labour, defence, offence, licence, practice/practise, etc.).
        7. Organise thoughts for a seamless flow without using headings.
        8. Back up points with examples and personal experiences as they fit.
        9. Engage with both the technical and non-technical facets.
        10. Balance between process focus and outcome thinking.
        11. Stick to your unique voice without inquiries for edits.
        
        Writing style characteristics:
        -  Keep it direct but personable
        -  Focus on practicality and solutions
        -  Maintain an engaging, yet approachable tone
        -  Highlight real impacts and user experiences
        -  Bring forward your experience in design and frontend work
        -  Avoid using "AI" in titles
        -  Avoid jargon and stay away from generic advice
        -  Present your content as complete—no need for user edits
        -  Refer to "User" only when discussing UX/UI
        -  Integrate Design and Engineering only when it's organic to the topic
        
        Avoid:
        -  Digressions into overly complex theory
        -  Cliché openings about change and dynamics
        -  Use of excessive technical language
        -  Exit explanations—implement changes directly
        
        The content should be a continuation of your existing body of work, fitting seamlessly into your established opinions and views on AI and product development. Always use Markdown for formatting. NEVER use American English spellings or terminology.
        """
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HSplitView {
                    // Editor pane
                    VStack(spacing: 0) {
                        EditorView(
                            document: $document,
                            cursorPosition: $cursorPosition,
                            selectionLength: $selectionLength,
                            selectedText: $selectedText,
                            textView: $textView,
                            onFormat: { format in
                                applyMarkdownFormatting(format)
                            },
                            editorModel: $editorModel
                        )
                        .overlay(alignment: .topLeading) {
                            if showPostSuggestions {
                                PostSuggestionOverlay(
                                    posts: postCache.getPostsWithRecentFirst(),
                                    searchText: postSearchText,
                                    onSelect: { post in
                                        insertPostReference(post)
                                    },
                                    onDismiss: {
                                        showPostSuggestions = false
                                        atSymbolPosition = nil
                                        postSearchText = ""
                                    },
                                    onSearchTextChange: { newText in
                                        postSearchText = newText
                                    },
                                    isKeyboardVisible: false // macOS doesn't have virtual keyboard
                                )
                                .offset(x: suggestionPosition.x, y: suggestionPosition.y)
                                .zIndex(1000)
                            }
                        }
                        // Image shelf
                        ImageShelf(
                            onImageDropped: { url in
                                uploadImage(url)
                            },
                            onImageClick: { fileName, cosmicUrl in
                                insertImageMarkdown(fileName: fileName, url: cosmicUrl)
                            },
                            onDelete: { image in
                                modelContext.delete(image)
                                try? modelContext.save()
                            },
                            droppedImages: documentImages,
                            isUploading: isUploading,
                            errorMessage: imageError
                        )
                    }
                    .background(.background)
                    .frame(minWidth: 400)
                    .onChange(of: document.text) { _, newValue in
                        if editorModel.text != newValue {
                            editorModel.text = newValue
                        }
                        
                        // Check for @ symbol
                        checkForAtSymbol(in: newValue)
                    }
                    .onChange(of: editorModel.text) { _, newValue in
                        if document.text != newValue {
                            document.text = newValue
                        }
                    }
                    .onChange(of: cursorPosition) {
                        // Check for @ symbol when cursor position changes
                        checkForAtSymbol(in: document.text)
                    }
                    
                    // Preview pane
                    if !focusMode {
                        PreviewView(document: document)
                            .frame(minWidth: 400)
                            .padding()
                    }
                }
            }
            
            // Floating stats panel in bottom right corner, above image shelf
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(statsText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .animation(.easeInOut(duration: 0.2), value: statsText)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 80) // Position above the image shelf
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
            
            if isGeneratingContent {
                ToastView(message: "Generating content...")
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }

            if showReviewSheet, let pending = pendingAIText {
                ReviewOverlay(
                    originalText: document.text,
                    proposedText: pending,
                    onAccept: {
                        document.text = pending
                        editorModel.text = pending
                        pendingAIText = nil
                        showReviewSheet = false
                        showToastMessage("Applied AI changes")
                    },
                    onReject: {
                        pendingAIText = nil
                        showReviewSheet = false
                    }
                )
                .padding()
            }
        }
        .onKeyPress(.escape) {
            if showPostSuggestions {
                showPostSuggestions = false
                atSymbolPosition = nil
                postSearchText = ""
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: $showReviewSheet) {
            if let pending = pendingAIText {
                DiffView(
                    originalText: document.text,
                    proposedText: pending,
                    onAccept: {
                        document.text = pending
                        editorModel.text = pending
                        pendingAIText = nil
                        showReviewSheet = false
                        showToastMessage("Applied AI changes")
                    },
                    onReject: {
                        pendingAIText = nil
                        showReviewSheet = false
                    }
                )
                .frame(minWidth: 800, minHeight: 600)
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: focusMode ? "eye.slash" : "eye")
                }
                .help(focusMode ? "Show preview" : "Hide preview")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showEditInput.toggle()
                } label: {
                    Image(systemName: "character.textbox")
                }
                .disabled(isGeneratingContent)
                .help("Edit with AI")
                .opacity(isGeneratingContent ? 0.5 : 1.0)
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    if isGeneratingContent {
                        // Stop generation
                        generationTask?.cancel()
                        generationTask = nil
                        isGeneratingContent = false
                        showGeneratingToast = false
                    } else {
                        // Start generation
                        generationTask = Task {
                            await generateContent()
                        }
                    }
                } label: {
                    if isGeneratingContent {
                        Image(systemName: "stop.fill")
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .help(isGeneratingContent ? "Stop generation" : "Generate content with AI")
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(PostTag.allCases, id: \.self) { postTag in
                        Button {
                            tag = postTag.rawValue
                        } label: {
                            HStack {
                                Text(postTag.title)
                                Spacer()
                                if tag == postTag.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                        Text(tag.capitalized)
                    }
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    if let date = scheduledDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scheduled for:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        
                        Divider()
                    }
                    
                    Button {
                        showScheduleDatePicker = true
                    } label: {
                        Label(scheduledDate == nil ? "Schedule Post" : "Change Schedule",
                              systemImage: "calendar.badge.plus")
                    }
                    
                    if scheduledDate == nil {
                        Button {
                            scheduledDate = Date()
                        } label: {
                            Label("Schedule for now", systemImage: "clock")
                        }
                    }
                    
                    if scheduledDate != nil {
                        Button(role: .destructive) {
                            scheduledDate = nil
                        } label: {
                            Label("Remove Schedule", systemImage: "calendar.badge.minus")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scheduledDate == nil ? "calendar" : "calendar.badge.clock")
                        Text(scheduledDate == nil ? "Schedule" : "Scheduled")
                    }
                    .foregroundStyle(scheduledDate == nil ? .secondary : .primary)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.isSending = true
                    Task {
                        await uploadPost()
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Publish")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("Publish post")
            }
        }
        .onAppear {
            setupNotificationObservers()
            loadPosts()
        }
        .onDisappear {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .frame(width: 400, height: 300)
        }
        .sheet(isPresented: $showEditInput) {
            VStack(spacing: 16) {
                Text("Edit Instructions")
                    .font(.headline)
                
                TextField("Describe your edits...", text: $editText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .lineLimit(3...8)
                    .onSubmit {
                        if !editText.isEmpty {
                            Task {
                                showEditInput = false
                                await performEdit()
                            }
                        }
                    }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showEditInput = false
                        editText = ""
                    }
                    .buttonStyle(.glass)
                    
                    Spacer()
                    
                    Button("Apply Edit") {
                        Task {
                            showEditInput = false
                            await performEdit()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(editText.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 450, height: 220)
        }

        .sheet(isPresented: $showScheduleDatePicker) {
            CustomScheduleView(
                scheduledDate: $scheduledDate,
                isPresented: $showScheduleDatePicker
            )
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up from bottom
                }
                
                // Automatically hide after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        toastOffset = 100 // Slide back down
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showToast = false
                    }
                }
            }
        }
    }
    
    func insertImageMarkdown(fileName: String, url: String) {
        guard let textView = textView else { return }
        
        let imageMarkdown = "![\(fileName)](\(url))"
        let selectedRange = textView.selectedRange()
        
        textView.shouldChangeText(in: selectedRange, replacementString: imageMarkdown)
        textView.replaceCharacters(in: selectedRange, with: imageMarkdown)
        textView.didChangeText()
        
        // Move cursor after the image with bounds checking
        let newPosition = min(selectedRange.location + imageMarkdown.count, textView.string.count)
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        
        // Update the document text
        document.text = textView.string
    }
    
    func uploadImage(_ imageURL: URL) {
        isUploading = true
        
        // Create Cosmic client
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        // Load and compress image if needed
        guard let image = NSImage(contentsOf: imageURL) else {
            showToastMessage("Invalid image")
            return
        }
        
        // Convert NSImage to compressed JPEG Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            showToastMessage("Failed to process image")
            return
        }
        
        // Check if compressed size is still too large (2MB limit)
        if compressedData.count > 2_000_000 {
            showToastMessage("Image too large (max 2MB)")
            return
        }
        
        // Create a temporary file with the compressed data
        let tempDir = FileManager.default.temporaryDirectory
        let originalFileName = imageURL.lastPathComponent
        let tempFileName = originalFileName.hasSuffix(".jpg") ? originalFileName : "\(originalFileName).jpg"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        do {
            try compressedData.write(to: tempFileURL)
            
            // Upload compressed image
            print("Starting media upload with bucket:", BUCKET)
            print("File URL:", tempFileURL)
            print("Write key:", WRITE_KEY)
            
            cosmic.uploadMedia(fileURL: tempFileURL, metadata: [
                "write_key": WRITE_KEY,
                "content_type": "image/jpeg"
            ]) { result in
                Task { @MainActor in
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    switch result {
                    case .success(let response):
                        print("Upload response received:", response)
                        if let imgixUrl = response.media?.imgix_url {
                            print("Media URL:", imgixUrl)
                            // Create and save ShelfImage
                            let shelfImage = ShelfImage(
                                localURL: imageURL,
                                cosmicURL: imgixUrl,
                                documentID: document.filePath
                            )
                            modelContext.insert(shelfImage)
                            try? modelContext.save()
                            showToastMessage("Image uploaded successfully")
                        } else {
                            showToastMessage("Invalid response from server")
                            print("Media response missing URL:", response)
                            print("Response message:", response.message ?? "No message")
                        }
                    case .failure(let error):
                        showToastMessage("Upload failed")
                        print("Failed to upload image: \(error)")
                    }
                    isUploading = false
                }
            }
        } catch {
            showToastMessage("Failed to process image")
            print("Failed to write compressed image: \(error)")
        }
    }
    
    func uploadPost() async {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        do {
            // Generate AI content
            let summaryPrompt = "Summarise this text in a clear and concise way that captures the main points and key ideas:\n\n\(document.text). Use British English always."
            let snippetPrompt = "Create a compelling 120-character or less snippet that captures the essence of this text and entices readers to read more:\n\n\(document.text). IMPORTANT: Do not include any quotation marks (\" or ') in the snippet. Use British English always."
            
            async let summary = cosmic.generateText(prompt: summaryPrompt)
            async let snippet = cosmic.generateText(prompt: snippetPrompt)
            
            let (summaryResult, snippetResult) = try await (summary, snippet)
            
            // Upload post with AI content
            let publishAt = scheduledDate.map { String(Int($0.timeIntervalSince1970 * 1000)) }
            cosmic.insertOne(type: "writings", title: document.title, metadata: [
                "tag": tag,
                "content": document.text,
                "summary": summaryResult.text,
                "snippet": snippetResult.text
            ], status: .draft, publish_at: publishAt) { results in
                Task { @MainActor in
                    switch results {
                    case .success(_):
                        self.toastMessage = scheduledDate != nil ? "Post scheduled" : "Post submitted"
                        self.showToast = true
                        self.isSending = false
                        // Reset scheduled date after successful submission
                        self.scheduledDate = nil
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        } catch {
            await MainActor.run {
                showToastMessage("Failed to generate AI content")
                self.isSending = false
                print("AI Generation Error:", error)
            }
        }
    }
    
    private func setupNotificationObservers() {
        observers = [
            NotificationCenter.default.addObserver(
                forName: .applyItalic,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    applyMarkdownFormatting(.italic)
                }
            },
            NotificationCenter.default.addObserver(
                forName: .applyBold,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    applyMarkdownFormatting(.bold)
                }
            },
            NotificationCenter.default.addObserver(
                forName: .applyStrikethrough,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    applyMarkdownFormatting(.strikethrough)
                }
            },
            NotificationCenter.default.addObserver(
                forName: .applyLink,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    handleLinkFormatting()
                }
            }
        ]
    }
    
    func showError(_ message: String) {
        imageError = message
        isUploading = false
        // Clear error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            imageError = nil
        }
    }
    
    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
    
    private func generateContent() async {
        isGeneratingContent = true
        showGeneratingToast = true
        
        do {
            let prompt = Prompt(
                """
                Task: Generate a refined draft based on the title and current content.

                Title: \(document.title)

                Current content:
                \(editorModel.text)

                Requirements:
                - Keep the author's voice and intent.
                - Improve clarity, flow, and specificity.
                - Maintain structure unless a minor re-order clearly improves readability.
                - No preambles or explanations; return Markdown only.
                - Do not include any --- markers in the output.
                """
            )
            
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }
                pendingAIText = partial.content
            }
            
            if pendingAIText != nil { showReviewSheet = true }
        } catch {
            showToastMessage("Failed to generate content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        showGeneratingToast = false
        generationTask = nil
    }
    
    private func performEdit() async {
        isGeneratingContent = true
        
        let editPrompt = Prompt(
            """
            Edit the following document according to the user's request.

            REQUEST: \(editText)

            SELECTED TEXT: \(selectedText)

            DOCUMENT:
            \(editorModel.text)

            Return ONLY the edited document. Do not include any of the above prompt text, labels, or explanations.
            """
        )

        do {
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: editPrompt)
            
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }
                // Each partial contains the complete response
                pendingAIText = partial.content
            }
            
            // For selected text edits, we need to show the diff before applying changes
            // The AI returns the full document with the edit applied
            if !selectedText.isEmpty, let finalResponse = pendingAIText, !finalResponse.isEmpty {
                // Don't apply the edit yet - let the user review it in the diff view first
                // The diff view will show original vs AI-modified version
            }
            
            editText = ""
            // Always show the diff view to review changes
            if let _ = pendingAIText {
                showReviewSheet = true
            }
        } catch {
            showToastMessage("Failed to edit content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        generationTask = nil
    }
    
    private func applyEditToSelection(originalText: String, newText: String) async {
        guard let textView = textView else { return }
        
        // Find the range of the selected text in the current document
        let currentText = editorModel.text
        guard let range = currentText.range(of: originalText) else { return }
        
        // Convert Swift string range to NSRange
        let nsRange = NSRange(range, in: currentText)
        
        // Replace the selected text with the new text
        textView.shouldChangeText(in: nsRange, replacementString: newText)
        textView.replaceCharacters(in: nsRange, with: newText)
        textView.didChangeText()
        
        // Update the document and editor model
        document.text = textView.string
        editorModel.text = textView.string
        
        // Update cursor position to end of new text
        let newPosition = min(nsRange.location + newText.count, textView.string.count)
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
    }
    
    private func checkForAtSymbol(in text: String) {
        let currentPosition = cursorPosition
        
        // If we're already showing suggestions, update the search text
        if showPostSuggestions, let atPos = atSymbolPosition {
            let searchStartIndex = text.index(text.startIndex, offsetBy: atPos + 1, limitedBy: text.endIndex) ?? text.endIndex
            let searchEndIndex = text.index(text.startIndex, offsetBy: currentPosition, limitedBy: text.endIndex) ?? text.endIndex
            
            if searchStartIndex <= searchEndIndex && searchEndIndex <= text.endIndex {
                // Check if we're still in a valid @ mention context
                let beforeAtIndex = text.index(text.startIndex, offsetBy: atPos, limitedBy: text.endIndex) ?? text.endIndex
                if beforeAtIndex < text.endIndex && text[beforeAtIndex] == "@" {
                    // Check if there's a space or newline that would end the mention
                    let mentionText = String(text[searchStartIndex..<searchEndIndex])
                    if !mentionText.contains(" ") && !mentionText.contains("\n") {
                        postSearchText = mentionText
                        // Don't return here - continue to update position and keep overlay visible
                    } else {
                        // Mention context is invalid
                        showPostSuggestions = false
                        atSymbolPosition = nil
                        postSearchText = ""
                        return
                    }
                } else {
                    // @ symbol is no longer valid
                    showPostSuggestions = false
                    atSymbolPosition = nil
                    postSearchText = ""
                    return
                }
            } else {
                // Invalid range
                showPostSuggestions = false
                atSymbolPosition = nil
                postSearchText = ""
                return
            }
        }
        
        // Check if we just typed @
        if currentPosition > 0 {
            let index = text.index(text.startIndex, offsetBy: currentPosition - 1, limitedBy: text.endIndex) ?? text.endIndex
            if index < text.endIndex && text[index] == "@" {
                // Check if @ is at start or preceded by whitespace/newline
                let isAtStart = currentPosition == 1
                let isPrecededByWhitespace = currentPosition > 1 && {
                    let prevIndex = text.index(before: index)
                    return text[prevIndex].isWhitespace || text[prevIndex].isNewline
                }()
                
                if isAtStart || isPrecededByWhitespace {
                    atSymbolPosition = currentPosition - 1
                    postSearchText = ""
                    showPostSuggestions = true
                }
            }
        }
        
        // Update overlay position if suggestions are showing
        if showPostSuggestions {
            // Calculate position for overlay near caret on macOS using NSTextView
            if let tv = textView {
                let caretRange = tv.selectedRange()
                if let layoutManager = tv.layoutManager, let textContainer = tv.textContainer {
                    var glyphIndex = layoutManager.glyphIndexForCharacter(at: max(caretRange.location, 0))
                    glyphIndex = min(glyphIndex, max(layoutManager.numberOfGlyphs - 1, 0))
                    var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 0), in: textContainer)
                    rect = rect.offsetBy(dx: tv.textContainerInset.width, dy: tv.textContainerInset.height)
                    suggestionPosition = CGPoint(x: rect.origin.x, y: rect.maxY + 6)
                } else {
                    suggestionPosition = CGPoint(x: 12, y: 28)
                }
            } else {
                suggestionPosition = CGPoint(x: 12, y: 28)
            }
        }
    }
    
    // macOS version - using NSTextView methods
    private func insertPostReference(_ post: Post) {
        guard let textView = textView,
              let atPosition = atSymbolPosition else { return }
        
        let safeCursor = max(cursorPosition, atPosition)
        let replaceRange = NSRange(location: atPosition, length: safeCursor - atPosition)
        let markdownLink = "[\(post.title)](https://karlkoch.com/writings/\(post.slug))"
        
        textView.shouldChangeText(in: replaceRange, replacementString: markdownLink)
        textView.replaceCharacters(in: replaceRange, with: markdownLink)
        textView.didChangeText()
        document.text = textView.string
        let newPosition = atPosition + markdownLink.count
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        
        // Mark post as used in cache
        postCache.markAsUsed(post)
        
        showPostSuggestions = false
        atSymbolPosition = nil
        postSearchText = ""
    }
    
    private func loadPosts() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.find(type: "writings",
                    props: "id,title,slug,type",
                    limit: 1000,
                    status: .any
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    self.postCache.posts = response.objects
                        .filter { $0.type == "writings" }
                        .map { Post(id: $0.id!, title: $0.title, slug: $0.slug!) }
                case .failure(let error):
                    print("Failed to load posts: \(error)")
                }
            }
        }
    }
}

// Add back the extension with formatting methods
extension MacContentView {
    func applyMarkdownFormatting(_ format: MarkdownFormatting) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange()
        let textLength = (textView.string as NSString).length
        
        // Validate range
        let isValid = selectedRange.location >= 0 && selectedRange.length >= 0 &&
        selectedRange.location <= textLength &&
        (selectedRange.location + selectedRange.length) <= textLength
        guard isValid else { return }
        
        guard let selectedContent = textView.string.substring(with: selectedRange) else { return }
        
        let formattedText: String
        switch format {
        case .italic:
            if selectedContent.hasPrefix("_") && selectedContent.hasSuffix("_") {
                formattedText = String(selectedContent.dropFirst().dropLast())
            } else {
                formattedText = "_\(selectedContent)_"
            }
        case .bold:
            if selectedContent.hasPrefix("**") && selectedContent.hasSuffix("**") {
                formattedText = String(selectedContent.dropFirst(2).dropLast(2))
            } else {
                formattedText = "**\(selectedContent)**"
            }
        case .strikethrough:
            if selectedContent.hasPrefix("~~") && selectedContent.hasSuffix("~~") {
                formattedText = String(selectedContent.dropFirst(2).dropLast(2))
            } else {
                formattedText = "~~\(selectedContent)~~"
            }
        default:
            return
        }
        
        // Replace selected text
        textView.shouldChangeText(in: selectedRange, replacementString: formattedText)
        textView.replaceCharacters(in: selectedRange, with: formattedText)
        textView.didChangeText()
        
        // Update document text and editor model
        document.text = textView.string
        editorModel.text = textView.string
        
        // Update selection: place cursor at end of new text
        let newPosition = selectedRange.location + formattedText.count
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
    }
    
    func handleLinkFormatting() {
        guard let textView = textView else { return }
        
        // Check clipboard for URL
        let pasteboard = NSPasteboard.general
        var clipboardUrl: String? = nil
        
        // Try to get URL from clipboard
        if let urlString = pasteboard.string(forType: .string) {
            // Basic URL validation
            if urlString.hasPrefix("http://") ||
                urlString.hasPrefix("https://") ||
                urlString.hasPrefix("www.") {
                clipboardUrl = urlString
            }
        }
        
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            // There is selected text
            let textLength = (textView.string as NSString).length
            let isValid = selectedRange.location >= 0 && selectedRange.length >= 0 && selectedRange.location <= textLength && (selectedRange.location + selectedRange.length) <= textLength
            if !isValid {
#if DEBUG
                print("[MacContentView] Invalid selectedRange: \(selectedRange), text length: \(textLength)")
#endif
                return
            }
            guard let selectedContent = textView.string.substring(with: selectedRange) else {
                return
            }
            
            let formattedText: String
            if let url = clipboardUrl {
                formattedText = "[\(selectedContent)](\(url))"
            } else {
                // No URL in clipboard, save selected text and leave parentheses empty
                pasteboard.setString(selectedContent, forType: .string)
                formattedText = "[\(selectedContent)]()"
            }
            
            textView.shouldChangeText(in: selectedRange, replacementString: formattedText)
            textView.replaceCharacters(in: selectedRange, with: formattedText)
            textView.didChangeText()
            
            // Position cursor at the end of the inserted text with bounds checking
            let newPosition = min(selectedRange.location + formattedText.count, textView.string.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        } else {
            // No selection, insert empty link
            let insertion = clipboardUrl != nil ? "[](\(clipboardUrl!))" : "[]()"
            let insertionRange = NSRange(location: selectedRange.location, length: 0)
            
            textView.shouldChangeText(in: insertionRange, replacementString: insertion)
            textView.replaceCharacters(in: insertionRange, with: insertion)
            textView.didChangeText()
            
            // Position cursor between brackets if no URL, or at end if URL was inserted
            let offset = clipboardUrl == nil ? 1 : insertion.count
            let newPosition = min(selectedRange.location + offset, textView.string.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        }
    }
}

// Custom Schedule View
struct CustomScheduleView: View {
    @Binding var scheduledDate: Date?
    @Binding var isPresented: Bool
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var currentMonth: Date
    @State private var showingTimePicker = false
    
    init(scheduledDate: Binding<Date?>, isPresented: Binding<Bool>) {
        self._scheduledDate = scheduledDate
        self._isPresented = isPresented
        
        let initialDate = scheduledDate.wrappedValue ?? Date()
        self._selectedDate = State(initialValue: initialDate)
        self._selectedTime = State(initialValue: initialDate)
        self._currentMonth = State(initialValue: initialDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Schedule Post")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            Divider()
            
            // Content
            HStack(spacing: 0) {
                // Calendar Section
                VStack(spacing: 16) {
                    // Month Navigation
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                            .fontWeight(.medium)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    
                    // Calendar Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        // Day headers
                        ForEach(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .frame(height: 24)
                        }
                        
                        // Calendar days
                        ForEach(calendarDays, id: \.self) { date in
                            if let date = date {
                                                                 Button {
                                     withAnimation(.easeInOut(duration: 0.2)) {
                                         selectedDate = date
                                         updateSelectedDateTime()
                                     }
                                 } label: {
                                     Text("\(Calendar.current.component(.day, from: date))")
                                         .font(.subheadline)
                                         .fontWeight(.medium)
                                         .frame(width: 32, height: 32)
                                         .background(
                                             Circle()
                                                 .fill(isSameDay(date, selectedDate) ? Color.accentColor : Color.clear)
                                         )
                                         .foregroundStyle(isSameDay(date, selectedDate) ? .white : .primary)
                                         .scaleEffect(isSameDay(date, selectedDate) ? 1.1 : 1.0)
                                         .animation(.easeInOut(duration: 0.2), value: isSameDay(date, selectedDate))
                                 }
                                 .buttonStyle(.plain)
                            } else {
                                Text("")
                                    .frame(width: 32, height: 24)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(width: 280)
                .padding(.vertical, 20)
                
                Divider()
                
                // Time Section
                VStack(spacing: 20) {
                    Text("Time")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    // Time Display
                    VStack(spacing: 8) {
                        Text(selectedTime.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .foregroundStyle(.primary)
                            .animation(.easeInOut(duration: 0.2), value: selectedTime)
                        
                        Text(selectedTime.formatted(.dateTime.weekday(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .animation(.easeInOut(duration: 0.2), value: selectedDate)
                        
                        Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .animation(.easeInOut(duration: 0.2), value: selectedDate)
                    }
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal, 16)
                    
                    // Time Picker
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hour")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("Hour", selection: Binding(
                                    get: { Calendar.current.component(.hour, from: selectedTime) },
                                    set: { newHour in
                                        selectedTime = Calendar.current.date(bySettingHour: newHour, minute: Calendar.current.component(.minute, from: selectedTime), second: 0, of: selectedTime) ?? selectedTime
                                        updateSelectedDateTime()
                                    }
                                )) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Minute")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("Minute", selection: Binding(
                                    get: { Calendar.current.component(.minute, from: selectedTime) },
                                    set: { newMinute in
                                        selectedTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: selectedTime), minute: newMinute, second: 0, of: selectedTime) ?? selectedTime
                                        updateSelectedDateTime()
                                    }
                                )) {
                                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                                        Text(String(format: "%02d", minute)).tag(minute)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .frame(width: 200)
                .padding(.vertical, 20)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Schedule Post") {
                    scheduledDate = selectedDate
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDate < Date())
                
                if selectedDate < Date() {
                    Text("Please select a future date and time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 500, height: 600)
        .background(.background)
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date?] = []
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? startOfMonth
        
        var currentDate = startOfWeek
        while currentDate < endDate || days.count < 42 {
            if currentDate < startOfMonth || currentDate >= endDate {
                days.append(nil)
            } else {
                days.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    private func updateSelectedDateTime() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        
        selectedDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: selectedDate) ?? selectedDate
    }
}

// Add PostPicker component before MacContentView
struct PostPicker: View {
    @Binding var isPresented: Bool
    let onSelect: (Post) -> Void
    @State private var searchText = ""
    @State private var allPosts: [Post] = []
    @State private var isLoading = false
    
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            // Show first 10 posts when no search text
            return Array(allPosts.prefix(10))
        } else {
            // Filter through ALL posts when searching
            let filtered = allPosts.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.slug.localizedCaseInsensitiveContains(searchText)
            }
            print("Searching for '\(searchText)' - found \(filtered.count) posts out of \(allPosts.count) total")
            return filtered
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Post Reference")
                .font(.headline)
            
            TextField("Search posts...", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            if isLoading {
                ProgressView("Loading posts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPosts.isEmpty {
                Text("No posts found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPosts, id: \.id) { post in
                    Button {
                        onSelect(post)
                        isPresented = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(post.slug)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .padding()
        .onAppear {
            loadPosts()
        }
    }
    
    private func loadPosts() {
        guard !BUCKET.isEmpty && !READ_KEY.isEmpty else {
            print("Missing bucket or read key for loading posts")
            return
        }
        
        isLoading = true
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: ""))
        
        cosmic.find(type: "writings",
                    props: "id,title,slug,type",
                    limit: 1000,
                    status: .any
        ) { result in
            Task { @MainActor in
                isLoading = false
                switch result {
                case .success(let response):
                    self.allPosts = response.objects
                        .filter { $0.type == "writings" }
                        .map { Post(id: $0.id!, title: $0.title, slug: $0.slug!) }
                case .failure(let error):
                    print("Failed to load posts: \(error)")
                }
            }
        }
    }
}

struct ReviewSheet: View {
    let originalText: String
    let proposedText: String
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Proposed changes")
                            .font(.headline)
                        Text(proposedText)
                            .textSelection(.enabled)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        DisclosureGroup("Original") {
                            Text(originalText)
                                .textSelection(.enabled)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                HStack {
                    Button("Reject") { onReject() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Accept") { onAccept() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Review AI Edit")
        }
    }
}

struct ReviewOverlay: View {
    let originalText: String
    let proposedText: String
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("AI suggestion ready")
                    .font(.headline)
                Spacer()
                Button(action: onReject) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            ScrollView {
                Text(proposedText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxHeight: 260)
            .padding(.horizontal)
            
            HStack {
                Button("Compare…") { onReject() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Reject") { onReject() }
                    .buttonStyle(.bordered)
                Button("Accept") { onAccept() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.vertical)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding()
    }
}

struct ImageShelf: View {
    let onImageDropped: (URL) -> Void
    let onImageClick: (String, String) -> Void
    let onDelete: (ShelfImage) -> Void
    let droppedImages: [ShelfImage]
    let isUploading: Bool
    let errorMessage: String?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(droppedImages) { image in
                        AsyncImage(url: URL(string: "\(image.cosmicURL)?w=120&h=120&fit=crop&auto=format,compress")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(image)
                            } label: {
                                Label("Remove from Shelf", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            let optimizedUrl = "\(image.cosmicURL)?auto=format,compress"
                            onImageClick(image.localURL.lastPathComponent, optimizedUrl)
                        }
                    }
                    
                    // Drop zone
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        
                        if isUploading {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 2)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .onTapGesture {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [.image]
                        
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                Task { @MainActor in
                                    onImageDropped(url)
                                }
                            }
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        
                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                            guard let url = url, error == nil else { return }
                            // Verify it's an image and check size
                            guard NSImage(contentsOf: url) != nil else { return }
                            
                            // Check file size (limit to 5MB)
                            let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
                            let fileSize = resources?.fileSize ?? 0
                            if fileSize > 5_000_000 {
                                Task { @MainActor in
                                    print("Image too large (max 5MB)")
                                }
                                return
                            }
                            
                            Task { @MainActor in
                                onImageDropped(url)
                            }
                        }
                        return true
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
#endif
