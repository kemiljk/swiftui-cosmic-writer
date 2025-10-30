//
//  iOSContentView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 16/08/2025.
//

#if os(iOS)
import SwiftUI
import UIKit
import HighlightedTextEditor
import MarkdownUI
import CosmicSDK
import SwiftData
import FoundationModels



struct ImageShelf: View {
    let onImageDropped: (URL) -> Void
    let onImageClick: (String, String) -> Void
    let onDelete: (ShelfImage) -> Void
    let droppedImages: [ShelfImage]
    let isUploading: Bool
    let errorMessage: String?
    @Binding var showImagePicker: Bool
    
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
                    
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack(spacing: 4) {
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
                            
                            Text("Add Image")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        showImagePicker = true
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

@MainActor
struct iOSContentView: View {
    @Binding var document: Cosmic_WriterDocument
    @Environment(\.modelContext) private var modelContext
    @Query private var shelfImages: [ShelfImage]
    
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @State private var openSettings: Bool = false
    @State private var openPreview: Bool = false
    @State private var tag = PostTag.design.rawValue
    @State private var focusMode: Bool = true
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var textView: UITextView? = nil
    @State private var isSending: Bool = false
    @State private var showToast: Bool = false
    @State private var toastOffset: CGFloat = 100
    @State private var isUploading: Bool = false
    @State private var toastMessage: String = ""
    @State private var observers: [NSObjectProtocol] = []
    @State private var droppedImages: [ShelfImage] = []
    @State private var imageError: String? = nil
    @State private var isKeyboardVisible: Bool = false
    @State private var isGeneratingContent: Bool = false
    @State private var showGeneratingToast: Bool = false
    @State private var editorModel = HighlightedTextModel()
    @State private var pendingAIText: String? = nil
    @State private var showReviewSheet: Bool = false
    @State private var showEditInput: Bool = false
    @State private var editText: String = ""
    @FocusState private var editInputIsFocused: Bool
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var showImagePicker = false
    @State private var originalTextBeforeAI: String = ""
    @State private var highlightedRange: NSRange? = nil

    // Add state for scheduled date
    @State private var scheduledDate: Date? = nil
    @State private var showScheduleDatePicker = false
    
    // Add state for inline suggestions
    @State private var showPostSuggestions = false
    @State private var atSymbolPosition: Int? = nil
    @State private var postSearchText = ""
    @StateObject private var postCache = PostCache()
    @State private var suggestionPosition: CGPoint = .zero
    @StateObject private var writingService: WritingService = {
        // Defer reading AppStorage until the view's storage is initialized
        let defaults = UserDefaults.standard
        let bucket = defaults.string(forKey: "bucketName") ?? ""
        let readKey = defaults.string(forKey: "readKey") ?? ""
        return WritingService(bucket: bucket, readKey: readKey)
    }()
    
    let device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
    
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
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Editor pane
                VStack {
                    EditorView(
                        document: $document,
                        cursorPosition: $cursorPosition,
                        selectionLength: $selectionLength,
                        selectedText: $selectedText,
                        textView: $textView,
                        onFormat: { format in
                            applyMarkdownFormatting(format)
                        },
                        editorModel: $editorModel,
                        showEditInput: showEditInput,
                        highlightedRange: $highlightedRange
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
                                isKeyboardVisible: isKeyboardVisible
                            )
                            .offset(x: suggestionPosition.x, y: suggestionPosition.y)
                            .zIndex(1000) // Ensure it appears above other content
                        }
                    }
                    
                    // Image shelf
                    if !showEditInput && !documentImages.isEmpty {
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
                            errorMessage: imageError,
                            showImagePicker: $showImagePicker
                        )
                    }
                }
                .onChange(of: document.text) { _, newValue in
                    if editorModel.text != newValue {
                        editorModel.text = newValue
                    }
                    
                    // Check for @ symbol
                    checkForAtSymbol(in: newValue)
                }
                .onChange(of: isKeyboardVisible) { _, _ in
                    // Update overlay position when keyboard visibility changes
                    if showPostSuggestions {
                        suggestionPosition = caretRelativePosition(in: document.text)
                    }
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
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }


            
            // Edit input overlay (appears above content, not affected by keyboard)
            if showEditInput {
                VStack(spacing: 12) {
                    TextField("Describe your edits...", text: $editText, axis: .vertical)
                        .focused($editInputIsFocused)
                        .padding()
                        .glassEffect(
                            in: .rect(cornerRadius: 24, style: .continuous)
                        )

                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showEditInput = false
                            editText = ""
                            highlightedRange = nil

                            // Restore focus to the text view
                            if let textView = textView {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    textView.becomeFirstResponder()
                                }
                            }

                            // Clear stored selection after a moment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                selectedText = ""
                                selectedRange = NSRange(location: 0, length: 0)
                            }
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .animation(.spring(response: 0.3), value: showEditInput)
                .onAppear {
                    // Keep the text view's selection visible
                    if let textView = textView, selectedRange.length > 0 {
                        // Ensure text view keeps first responder to show selection
                        textView.selectedRange = selectedRange

                        // Delay focusing the edit input so selection is visible first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            editInputIsFocused = true
                        }
                    } else {
                        // No selection, focus immediately
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            editInputIsFocused = true
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Main toolbar buttons (always visible)
            HStack {
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo")
                }
                .controlSize(.extraLarge)
                .buttonStyle(.glass)
                Button {
                    withAnimation {
                        openPreview.toggle()
                        modal.impactOccurred()
                    }
                } label: {
                    Image(systemName: "eye")
                }
                .controlSize(.extraLarge)
                .buttonStyle(.glass)
                .keyboardShortcut("p", modifiers: .command)
                Spacer()
                Button {
                    // Capture current selection before showing edit input
                    if let textView = textView {
                        let currentSelectedRange = textView.selectedRange
                        print("DEBUG: Edit button pressed - current selection: \(currentSelectedRange)")
                        
                        if currentSelectedRange.length > 0 {
                            let fullText = textView.text ?? ""
                            let nsString = fullText as NSString
                            let safeRange = NSRange(
                                location: min(currentSelectedRange.location, nsString.length),
                                length: min(currentSelectedRange.length, nsString.length - currentSelectedRange.location)
                            )
                            if safeRange.location >= 0 && safeRange.length > 0 && safeRange.location + safeRange.length <= nsString.length {
                                selectedText = nsString.substring(with: safeRange)
                                selectedRange = safeRange
                                print("DEBUG: Captured selection - text: '\(selectedText)', range: \(selectedRange)")
                            }
                        } else {
                            selectedText = ""
                            selectedRange = NSRange(location: 0, length: 0)
                            print("DEBUG: No selection captured")
                        }
                    }
                    
                    withAnimation(.spring(response: 0.3)) {
                        showEditInput.toggle()

                        // Set highlighted range when showing edit input
                        if selectedRange.length > 0 {
                            highlightedRange = selectedRange
                        }
                    }
                } label: {
                    Image(systemName: "character.textbox")
                }
                .disabled(isGeneratingContent)
                .controlSize(.extraLarge)
                .buttonStyle(.glass)
                .keyboardShortcut("e", modifiers: .command)
                Button {
                    if isGeneratingContent {
                        // Stop generation
                        generationTask?.cancel()
                        generationTask = nil
                        isGeneratingContent = false
                    } else {
                        // Start generation
                        generationTask = Task {
                            await generateContent()
                        }
                    }
                } label: {
                    Image( systemName: isGeneratingContent ? "stop.fill" : "sparkle")
                }
                .controlSize(.extraLarge)
                .buttonStyle(.glass)
                .keyboardShortcut("g", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            if showReviewSheet {
                GenerateAcceptDialog(
                    onAccept: {
                        // Keep the generated content (it's already in the editor)
                        pendingAIText = nil
                        showReviewSheet = false
                        originalTextBeforeAI = ""
                        showToastMessage("Changes applied")
                    },
                    onReject: {
                        // Restore original text
                        document.text = originalTextBeforeAI
                        editorModel.text = originalTextBeforeAI
                        pendingAIText = nil
                        showReviewSheet = false
                        originalTextBeforeAI = ""
                        showToastMessage("Changes reverted")
                    }
                )
                .padding()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { url in
                uploadImage(url)
            }
        }
        .sheet(isPresented: $openPreview) {
            NavigationStack {
                PreviewView(document: document)
            }
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .frame(width: 400, height: 300)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
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
            
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        self.isSending = true
                        Task {
                            await uploadPost(asDraft: true)
                        }
                    } label: {
                        Label("Draft", systemImage: "doc.badge.plus")
                    }
                    .disabled(isSending)

                    Button {
                        self.isSending = true
                        Task {
                            await uploadPost(asDraft: false)
                        }
                    } label: {
                        Label("Publish", systemImage: "arrow.up.circle.fill")
                    }
                    .disabled(isSending)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc")
                        Text("Post")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("Post as draft or publish")
                .disabled(isSending)
            }
        }
        .onAppear {
            setupNotificationObservers()
            loadPosts()
        }
        .onDisappear {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        .onChange(of: BUCKET) { _, newBucket in
            // Update writing service configuration when bucket changes
            writingService.updateConfig(bucket: newBucket, readKey: READ_KEY)
        }
        .onChange(of: READ_KEY) { _, newReadKey in
            // Update writing service configuration when read key changes
            writingService.updateConfig(bucket: BUCKET, readKey: newReadKey)
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up from bottom
                }

                // Don't auto-hide if we're currently sending/publishing
                if !isSending {
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
        .onChange(of: isSending) { _, newValue in
            // When publishing completes, auto-hide the toast after a delay
            if !newValue && showToast {
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
        .onKeyPress(.escape) {
            if showPostSuggestions {
                showPostSuggestions = false
                atSymbolPosition = nil
                postSearchText = ""
                return .handled
            }
            return .ignored
        }
    }

    private func setupNotificationObservers() {
        // Create a reference to self that can be captured
        let view = self

        // Store observers so we can remove them later
        observers = [
            NotificationCenter.default.addObserver(
                forName: .postDraft,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    if !view.isSending {
                        view.isSending = true
                        await view.uploadPost(asDraft: true)
                    }
                }
            },
            NotificationCenter.default.addObserver(
                forName: .publishPost,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    if !view.isSending {
                        view.isSending = true
                        await view.uploadPost(asDraft: false)
                    }
                }
            },
            // Add keyboard observers
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    withAnimation {
                        view.isKeyboardVisible = true
                    }
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    withAnimation {
                        view.isKeyboardVisible = false
                    }
                }
            },
            
            // Existing observers
            NotificationCenter.default.addObserver(
                forName: .applyHeading,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.heading)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyItalic,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.italic)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyBold,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.bold)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyStrikethrough,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.strikethrough)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyLink,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.handleLinkFormatting()
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyCode,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.code)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyCodeBlock,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.codeBlock)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyImage,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.image)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .openSettings,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    openSettings = true
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .showPreview,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    focusMode.toggle()
                }
            }
        ]
    }

    private func generate(document: Cosmic_WriterDocument, title: String, content: String) async {
        let prompt = Prompt("""
            Using title: \(title)\n\nand any existing content:\n\(content)\n\nPlease generate enhanced content that builds upon this foundation while maintaining its core message and style.
            """
        )

        do {
            let session = LanguageModelSession(instructions: writingService.instructions)
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                self.document.text = partial.content
                self.editorModel.text = partial.content
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    private func setupPasteInterceptor() {
        let pasteObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                handlePaste()
            }
        }
        observers.append(pasteObserver)
    }

    private func handlePaste() {
        let pasteboard = UIPasteboard.general
        
        // Handle image paste
        if let image = pasteboard.image {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let fileName = "pasted_image_\(Date().timeIntervalSince1970).jpg"
                Task {
                    await uploadImage(imageData: imageData, fileName: fileName)
                }
            }
            return
        }
        
        // Handle URL paste for markdown links
        if let url = pasteboard.url?.absoluteString {
            if url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("www.") {
                guard let textView = textView else { return }
                let selectedRange = textView.selectedRange
                
                if selectedRange.length > 0 {
                    // Selected text becomes link text
                    if let textRange = textView.selectedTextRange,
                       let selectedText = textView.text(in: textRange) {
                        let markdownLink = "[\(selectedText)](\(url))"
                        textView.replace(textRange, withText: markdownLink)
                    }
                } else {
                    // No selection, just insert the URL
                    if let textRange = textView.selectedTextRange {
                        let markdownLink = "[](\(url))"
                        textView.replace(textRange, withText: markdownLink)
                        
                        // Move cursor between brackets with bounds checking
                        Task { @MainActor in
                            let newPosition = min(selectedRange.location + 1, (textView.text ?? "").count)
                            if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                                textView.selectedTextRange = textView.textRange(from: position, to: position)
                            }
                        }
                    }
                }
            }
        }
    }

    func uploadPost(asDraft: Bool = true) async {
        // Show publishing toast
        await MainActor.run {
            showToastMessage("Publishing...")
        }

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
            let status: CosmicStatus = asDraft ? .draft : .published
            cosmic.insertOne(type: "writings", title: document.title, metadata: [
                "tag": tag,
                "content": document.text,
                "summary": summaryResult.text,
                "snippet": snippetResult.text
            ], status: status, publish_at: publishAt) { results in
                Task { @MainActor in
                    switch results {
                    case .success(_):
                        if scheduledDate != nil {
                            self.toastMessage = "Post scheduled"
                        } else if asDraft {
                            self.toastMessage = "Draft saved"
                        } else {
                            self.toastMessage = "Post published"
                        }
                        self.showToast = true
                        self.isSending = false
                        // Reset scheduled date after successful submission
                        self.scheduledDate = nil
                    case .failure(let error):
                        self.toastMessage = "Failed to publish"
                        self.showToast = true
                        self.isSending = false
                        print(error)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.toastMessage = "Failed to generate content"
                self.showToast = true
                self.isSending = false
                print("Content Generation Error:", error)
            }
        }
    }

    func uploadImage(imageData: Data, fileName: String) async {
        isUploading = true
        
        // Create temporary URL for the image data
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: tempFileURL)
            uploadImage(tempFileURL)
            try? FileManager.default.removeItem(at: tempFileURL)
        } catch {
            showToastMessage("Failed to process image")
            isUploading = false
        }
    }

    private func uploadImage(_ imageURL: URL) {
        isUploading = true
        
        // Create Cosmic client
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        // Load and compress image
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            showToastMessage("Invalid image")
            isUploading = false
            return
        }
        
        // Convert UIImage to compressed JPEG Data
        guard let compressedData = image.jpegData(compressionQuality: 0.7) else {
            showToastMessage("Failed to process image")
            isUploading = false
            return
        }
        
        // Check if compressed size is still too large (2MB limit)
        if compressedData.count > 2_000_000 {
            showToastMessage("Image too large (max 2MB)")
            isUploading = false
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
            cosmic.uploadMedia(fileURL: tempFileURL, metadata: [
                "write_key": WRITE_KEY,
                "content_type": "image/jpeg"
            ]) { result in
                Task { @MainActor in
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    switch result {
                    case .success(let response):
                        if let imgixUrl = response.media?.imgix_url {
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
            isUploading = false
        }
    }

    func insertImageMarkdown(fileName: String, url: String) {
        guard let textView = textView else { return }
        
        let imageMarkdown = "![\(fileName)](\(url))"
        let selectedRange = textView.selectedRange
        
        if let textRange = textView.selectedTextRange ?? textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument) {
            textView.replace(textRange, withText: imageMarkdown)
            
            // Move cursor to the end of the inserted markdown with bounds checking
            Task { @MainActor in
                let newPosition = min(selectedRange.location + imageMarkdown.count, (textView.text ?? "").count)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
            }
        }
    }

    func setCursorPosition(to position: Int) {
        Task { @MainActor in
            guard let textView = self.textView else {
                print("TextView not found")
                return
            }
    #if os(iOS)
            let safePosition = min(max(position, 0), (textView.text ?? "").count)
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: safePosition) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
    #endif
        }
    }

    func applyMarkdownFormatting(_ format: MarkdownFormatting) {
        MarkdownFormatter.shared.applyMarkdownFormatting(
            format: format,
            document: &document,
            selectedText: selectedText,
            cursorPosition: cursorPosition,
            textView: textView
        ) { newPosition in
            cursorPosition = newPosition
            setCursorPosition(to: newPosition)
        }
    }

    private func handleLinkFormatting() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        let textLength = (textView.text as NSString).length
        let isValid = selectedRange.location >= 0 && selectedRange.length >= 0 && selectedRange.location <= textLength && (selectedRange.location + selectedRange.length) <= textLength
        if !isValid {
    #if DEBUG
            print("[ContentView] Invalid selectedRange: \(selectedRange), text length: \(textLength)")
    #endif
            return
        }
        // Check clipboard for URL
        let pasteboard = UIPasteboard.general
        var clipboardUrl: String? = nil
        if let urlString = pasteboard.string {
            if urlString.hasPrefix("http://") ||
                urlString.hasPrefix("https://") ||
                urlString.hasPrefix("www.") {
                clipboardUrl = urlString
            }
        }
        if selectedRange.length > 0 {
            guard let selectedContent = String(textView.text).substring(with: selectedRange) else {
                return
            }
            let formattedText: String
            if let url = clipboardUrl {
                formattedText = "[\(selectedContent)](\(url))"
            } else {
                pasteboard.string = selectedContent
                formattedText = "[\(selectedContent)]()"
            }
            // Replace selected text using UITextRange
            if let start = textView.position(from: textView.beginningOfDocument, offset: selectedRange.location),
               let end = textView.position(from: start, offset: selectedRange.length),
               let textRange = textView.textRange(from: start, to: end) {
                textView.replace(textRange, withText: formattedText)
            }
            // Position cursor appropriately with bounds checking
            Task { @MainActor in
                let newPosition = min(selectedRange.location + formattedText.count, (textView.text as NSString).length)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
            }
        } else {
            // No selection, insert empty link
            if let textRange = textView.selectedTextRange {
                let insertion = clipboardUrl != nil ? "[](\(clipboardUrl!))" : "[]()"
                textView.replace(textRange, withText: insertion)
                // Position cursor between brackets if no URL, or at end if URL was inserted
                Task { @MainActor in
                    let offset = clipboardUrl == nil ? 1 : insertion.count
                    let newPosition = min(selectedRange.location + offset, (textView.text as NSString).length)
                    if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                        textView.selectedTextRange = textView.textRange(from: position, to: position)
                    }
                }
            }
        }
    }

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        toastOffset = -32
        
        // Automatically hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                toastOffset = 100
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showToast = false
            }
        }
    }
    
    private func generateContent() async {
        isGeneratingContent = true
        showGeneratingToast = true

        // Store original text for comparison and potential reversion
        originalTextBeforeAI = document.text
        let originalText = originalTextBeforeAI

        // Debug: Check writing examples
        print("DEBUG: Writing examples count: \(writingService.writingExamples.count)")
        print("DEBUG: Instructions length: \(writingService.instructions.count) chars")

        do {
            let session = LanguageModelSession(instructions: writingService.instructions)
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
                - Make meaningful improvements to the content.
                """
            )

            let stream = session.streamResponse(to: prompt)
            
            // Stream the response in real-time to the editor
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }
                
                // Update the editor in real-time with each partial response
                await MainActor.run {
                    editorModel.text = partial.content
                    document.text = partial.content
                }
                
                // Store the latest content for potential review
                pendingAIText = partial.content
            }
            
            // After streaming completes, check if there are meaningful changes
            if let aiText = pendingAIText, !aiText.isEmpty {
                let originalTextTrimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
                let aiTextTrimmed = aiText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if originalTextTrimmed != aiTextTrimmed {
                    // Show review sheet to let user accept/reject changes
                    showReviewSheet = true
                } else {
                    // AI returned same text, revert to original and show message
                    await MainActor.run {
                        editorModel.text = originalText
                        document.text = originalText
                        pendingAIText = nil
                    }
                    showToastMessage("No changes generated - content is already optimal")
                }
            } else {
                // No response, revert to original
                await MainActor.run {
                    editorModel.text = originalText
                    document.text = originalText
                    pendingAIText = nil
                }
                showToastMessage("No response generated")
            }
        } catch {
            // On error, revert to original text
            await MainActor.run {
                editorModel.text = originalText
                document.text = originalText
                pendingAIText = nil
            }
            showToastMessage("Failed to generate content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        showGeneratingToast = false
        generationTask = nil
    }
    
    private func performEdit() async {
        isGeneratingContent = true

        // Store original text for comparison and potential reversion
        originalTextBeforeAI = document.text
        let originalText = originalTextBeforeAI

        // Determine if we're editing a selection or the full document
        let isSelectionEdit = !selectedText.isEmpty

        // Debug logging for prompt content
        print("DEBUG: === EDIT PROMPT DEBUG ===")
        print("DEBUG: User's edit request: '\(editText)'")
        print("DEBUG: Is selection edit: \(isSelectionEdit)")
        print("DEBUG: Selected text length: \(selectedText.count)")
        print("DEBUG: Selected text: '\(selectedText)'")
        print("DEBUG: Selected range: \(selectedRange)")
        print("DEBUG: Document text length: \(editorModel.text.count)")
        print("DEBUG: Document text preview: '\(String(editorModel.text.prefix(200)))...'")
        print("DEBUG: =========================")

        let editPrompt: Prompt
        
        if !selectedText.isEmpty {
            // Edit only the selected text
            editPrompt = Prompt(
                """
                You MUST edit the following text according to the user's request. The user is asking for changes - you need to ACTUALLY MAKE THEM.

                EDITING REQUEST (what the user wants changed):
                \(editText)

                ORIGINAL TEXT (what needs to be edited):
                \(selectedText)

                CRITICAL REQUIREMENTS:
                - IMPLEMENT the requested changes - do NOT just return the original text
                - Make ACTUAL modifications based on what the user asked for
                - If the user asks to make it shorter, SHORTEN it
                - If the user asks to add something, ADD it
                - If the user asks to rewrite, REWRITE it
                - If the user asks to change tone, CHANGE the tone
                - Maintain British English spelling ALWAYS (colour, centre, organise, analyse, realise, etc.)
                - Keep the author's conversational yet insightful voice
                - Return ONLY the edited text - no labels, explanations, or meta-commentary
                - Do NOT return the original unchanged text unless absolutely identical to what was requested
                """
            )
        } else {
            // Edit the entire document
            editPrompt = Prompt(
                """
                You MUST edit the following document according to the user's request. The user is asking for changes - you need to ACTUALLY MAKE THEM.

                EDITING REQUEST (what the user wants changed):
                \(editText)

                ORIGINAL DOCUMENT (what needs to be edited):
                \(editorModel.text)

                CRITICAL REQUIREMENTS:
                - IMPLEMENT the requested changes - do NOT just return the original text
                - Make ACTUAL modifications based on what the user asked for
                - If the user asks to make it shorter, SHORTEN it
                - If the user asks to add something, ADD it
                - If the user asks to rewrite, REWRITE it
                - If the user asks to change tone, CHANGE the tone
                - Maintain British English spelling ALWAYS (colour, centre, organise, analyse, realise, etc.)
                - Keep the author's conversational yet insightful voice
                - Preserve Markdown formatting
                - Return ONLY the edited document - no labels, explanations, or meta-commentary
                - Do NOT return the original unchanged text unless absolutely identical to what was requested
                """
            )
        }

        do {
            let session = LanguageModelSession(instructions: writingService.instructions)
            let stream = session.streamResponse(to: editPrompt)

            // Clear highlighting and deselect the text to show streaming changes clearly
            await MainActor.run {
                highlightedRange = nil
            }

            if let textView = textView {
                await MainActor.run {
                    textView.selectedRange = NSRange(location: 0, length: 0)
                }
            }

            // For selection edits, we need to reconstruct the document with streaming updates
            let textBeforeSelection: String
            let textAfterSelection: String

            if isSelectionEdit {
                // Capture the text before and after the selection
                let fullText = originalText
                let nsString = fullText as NSString

                if selectedRange.location >= 0 && selectedRange.location + selectedRange.length <= nsString.length {
                    textBeforeSelection = nsString.substring(to: selectedRange.location)
                    textAfterSelection = nsString.substring(from: selectedRange.location + selectedRange.length)
                } else {
                    textBeforeSelection = ""
                    textAfterSelection = originalText
                }
            } else {
                textBeforeSelection = ""
                textAfterSelection = ""
            }

            // Stream the response in real-time
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }

                if isSelectionEdit {
                    // For selection edits, reconstruct document with streaming AI response replacing the selection
                    let reconstructedText = textBeforeSelection + partial.content + textAfterSelection
                    await MainActor.run {
                        editorModel.text = reconstructedText
                        document.text = reconstructedText
                    }
                } else {
                    // For full document edits, update the editor in real-time with the AI response
                    await MainActor.run {
                        editorModel.text = partial.content
                        document.text = partial.content
                    }
                }

                // Store the latest content for potential review
                pendingAIText = partial.content

                print("DEBUG: AI Response received - Length: \(partial.content.count)")
                print("DEBUG: First 100 chars: \(String(partial.content.prefix(100)))")
            }
            
            editText = ""

            if let finalResponse = pendingAIText, !finalResponse.isEmpty {
                // For selection edits, the document has already been updated via streaming with the correct reconstruction
                // For full edits, the document has the full AI response
                // Just check if there are actual changes

                let originalTextTrimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentTextTrimmed = document.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if originalTextTrimmed != currentTextTrimmed {
                    print("DEBUG: Showing review dialog for edit")
                    print("DEBUG: Original text length: \(originalText.count)")
                    print("DEBUG: Current text length: \(document.text.count)")

                    // Show review sheet (document already has the correct content from streaming)
                    showReviewSheet = true

                    // Clear selection state
                    selectedText = ""
                    selectedRange = NSRange(location: 0, length: 0)
                } else {
                    // No changes, revert to original and show message
                    await MainActor.run {
                        editorModel.text = originalText
                        document.text = originalText
                        pendingAIText = nil
                    }
                    showToastMessage("No changes generated - content is already optimal")

                    // Clear selection state
                    selectedText = ""
                    selectedRange = NSRange(location: 0, length: 0)
                }
            } else {
                // No response, revert to original
                await MainActor.run {
                    editorModel.text = originalText
                    document.text = originalText
                    pendingAIText = nil
                }
                showToastMessage("No response generated")

                // Clear selection state
                selectedText = ""
                selectedRange = NSRange(location: 0, length: 0)
            }
        } catch {
            // On error, revert to original text
            await MainActor.run {
                editorModel.text = originalText
                document.text = originalText
                pendingAIText = nil
            }
            showToastMessage("Failed to edit content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        generationTask = nil
    }
    
    private func applyEditToSelection(originalText: String, newText: String) async {
        guard let textView = textView else { return }
        
        // Use the stored selection range instead of searching for text
        guard selectedRange.length > 0 else { return }
        
        // Validate the range is still valid for the current text
        let currentText = editorModel.text
        let nsString = currentText as NSString
        let safeRange = NSRange(
            location: min(selectedRange.location, nsString.length),
            length: min(selectedRange.length, max(0, nsString.length - selectedRange.location))
        )
        
        guard safeRange.location >= 0 && safeRange.length > 0 && safeRange.location + safeRange.length <= nsString.length else {
            print("DEBUG: Selection range is no longer valid")
            return
        }
        
        // Replace the selected text with the new text
        if let start = textView.position(from: textView.beginningOfDocument, offset: safeRange.location),
           let end = textView.position(from: start, offset: safeRange.length),
           let textRange = textView.textRange(from: start, to: end) {
            textView.replace(textRange, withText: newText)
            
            // Update the document and editor model
            document.text = textView.text
            editorModel.text = textView.text
            
            // Update cursor position to end of new text
            let newPosition = min(safeRange.location + newText.count, textView.text.count)
            if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
            }
        }
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
            suggestionPosition = caretRelativePosition(in: text)
        }
    }

    private func insertPostReference(_ post: Post) {
        guard let textView = textView,
              let atPosition = atSymbolPosition else { return }
        
        // Calculate the range to replace (from @ to current position)
        let safeCursor = max(cursorPosition, atPosition)
        let replaceRange = NSRange(location: atPosition, length: safeCursor - atPosition)
        
        // Create the markdown link
        let markdownLink = "[\(post.title)](https://karlkoch.com/writings/\(post.slug))"
        
        // Replace the @ and any text typed after it with the markdown link
        if let start = textView.position(from: textView.beginningOfDocument, offset: replaceRange.location),
           let end = textView.position(from: start, offset: replaceRange.length),
           let textRange = textView.textRange(from: start, to: end) {
            textView.replace(textRange, withText: markdownLink)
            document.text = textView.text
            let newPosition = atPosition + markdownLink.count
            if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
            }
        }
        
        // Mark post as used in cache
        postCache.markAsUsed(post)
        
        // Reset
        showPostSuggestions = false
        atSymbolPosition = nil
        postSearchText = ""
    }

    private func caretRelativePosition(in text: String) -> CGPoint {
        // For iOS, position the overlay intelligently to avoid keyboard
        let lineHeight: CGFloat = 24
        let x: CGFloat = 12
        
        // Estimate line number by counting newlines up to cursorPosition
        let upToCursor = String(text.prefix(cursorPosition))
        let lineIndex = upToCursor.filter { $0 == "\n" }.count
        
        // Calculate base position
        let baseY = CGFloat(lineIndex + 1) * lineHeight
        
        // If keyboard is visible, position above the current line but not too high
        if isKeyboardVisible {
            // Position above the current line with moderate offset
            let keyboardAvoidanceOffset: CGFloat = 80 // Reduced from 150
            let y = max(0, CGFloat(lineIndex) * lineHeight - keyboardAvoidanceOffset)
            
            // Ensure the overlay doesn't go too high (above the top of the screen)
            let minY: CGFloat = 120 // Increased from 80 to give more top margin
            return CGPoint(x: x, y: max(minY, y))
        } else {
            // Position below the current line when no keyboard
            return CGPoint(x: x, y: baseY)
        }
    }
    
    private func loadPosts() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))

        cosmic.find(type: "writings",
                    props: "id,title,slug,type",
                    limit: 100,
                    status: .any
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    self.postCache.posts = response.objects
                        .filter { $0.type == "writings" }
                        .map { Post(id: $0.id!, title: $0.title, slug: $0.slug!) }

                    // Load writing examples after posts are loaded
                    self.writingService.loadWritingExamples()
                case .failure(let error):
                    print("Failed to load posts: \(error)")
                }
            }
        }
    }

}


// Simple accept/reject dialog for generated content (matches macOS)
struct GenerateAcceptDialog: View {
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.accent)
                Text("Apply changes?")
                    .font(.headline)
                Spacer()
            }

            Text("You're viewing generated content. Keep these changes or revert to your original draft.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Revert") {
                    onReject()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Keep Changes") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
        .frame(maxWidth: 380)
        .shadow(radius: 8)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let imageURL = info[.imageURL] as? URL {
                parent.onImagePicked(imageURL)
            } else if let image = info[.originalImage] as? UIImage {
                // Create a temporary file for the image
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "picked_image_\(Date().timeIntervalSince1970).jpg"
                let tempFileURL = tempDir.appendingPathComponent(fileName)
                
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    do {
                        try imageData.write(to: tempFileURL)
                        parent.onImagePicked(tempFileURL)
                    } catch {
                        print("Failed to write temporary file: \(error)")
                    }
                } else {
                    print("Failed to create JPEG data from image")
                }
            } else {
                print("No image data found in picker info")
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFailWithError error: Error) {
            print("Image picker failed with error: \(error)")
            picker.dismiss(animated: true)
        }
    }
}

struct ImageDropDelegate: DropDelegate {
    let view: iOSContentView
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.image]).first else { return false }
        
        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            if let image = object as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                Task { @MainActor in
                    await view.uploadImage(imageData: imageData, fileName: fileName)
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when dragging over
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }
}
#endif

