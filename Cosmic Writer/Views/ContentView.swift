import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import HighlightedTextEditor
import MarkdownUI
import CosmicSDK
import SwiftData
import FoundationModels

// Add PostSuggestionOverlay view before ContentView
struct PostSuggestionOverlay: View {
    let posts: [Post]
    let searchText: String
    let onSelect: (Post) -> Void
    @State private var selectedIndex: Int = 0
    
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return Array(posts.prefix(5))
        } else {
            return posts.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.slug.localizedCaseInsensitiveContains(searchText)
            }.prefix(5).map { $0 }
        }
    }
    
    var body: some View {
        if !filteredPosts.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                    Button {
                        onSelect(post)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(post.slug)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: 300)
            .glassEffect(in: .rect(cornerRadius: 16))
            .shadow(radius: 8)
        }
    }
}

struct ContentView: View {
    @Binding var document: Cosmic_WriterDocument
    
    var body: some View {
#if os(iOS)
        iOSContentView(document: $document)
#elseif os(macOS)
        MacContentView(document: $document)
#endif
    }
}

#if os(iOS)
// Move ImageShelf before iOSContentView
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
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { url in
                onImageDropped(url)
            }
        }
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
    @State private var showEditInput: Bool = false
    @State private var editText: String = ""
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var showImagePicker = false
    
    // Add state for scheduled date
    @State private var scheduledDate: Date? = nil
    @State private var showScheduleDatePicker = false
    
    // Add state for inline suggestions
    @State private var showPostSuggestions = false
    @State private var atSymbolPosition: Int? = nil
    @State private var postSearchText = ""
    @State private var allPosts: [Post] = []
    @State private var suggestionPosition: CGPoint = .zero
    
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
    
    private var instructions: String {
        """
        You are Karl Emil James Koch, you craft compelling content, weaving a narrative centred on AI, product development, and occasionally the fusion of design and engineering when it's relevant. Your job is to convey ideas with clarity and engage readers without dividing the content into sections with headings.
        
        Guidelines to follow:
        1. Adopt a conversational yet insightful tone, balancing depth with clarity.
        2. Dive into the overlap of design and engineering, especially AI and search products, only when it naturally fits.
        3. Prioritise taste and human judgement in discussions about design.
        4. Explore how code democratization breaks down the barriers between design and development.
        5. Emphasise real-world applications, steering clear of theoretical discussions.
        6. Use crisp, precise language, maintaining British English spellings.
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
        
        The content should be a continuation of your existing body of work, fitting seamlessly into your established opinions and views on AI and product development. Always use Markdown for formatting.
        """
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
                        editorModel: $editorModel
                    )
                    .overlay(alignment: .topLeading) {
                        if showPostSuggestions {
                            PostSuggestionOverlay(
                                posts: allPosts,
                                searchText: postSearchText,
                                onSelect: { post in
                                    insertPostReference(post)
                                }
                            )
                            .offset(x: suggestionPosition.x, y: suggestionPosition.y)
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
                            errorMessage: imageError
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
                .onChange(of: editorModel.text) { _, newValue in
                    if document.text != newValue {
                        document.text = newValue
                    }
                }
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                // Edit input field
                if showEditInput {
                    VStack(spacing: 8) {
                        TextField("Describe your edits...", text: $editText, axis: .vertical)
                            .padding()
                            .glassEffect(
                                in: .rect(cornerRadius: 24, style: .continuous)
                            )
                        
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                showEditInput = false
                                editText = ""
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Apply Edit") {
                                showEditInput = false
                                
                                generationTask = Task {
                                    do {
                                        isGeneratingContent = true
                                        
                                        let editPrompt = Prompt(
                                            """
                                            Instruction: \(editText)
                                            Content to edit: \(editorModel.text)
                                            Apply the instruction to the content. If there is selected text, focus on editing only that part.
                                            Selected text: \(selectedText)
                                            Return only the edited content. Do not include any other text, explanation, narrative, or markdown formatting like '---'.
                                            """
                                        )
                                        
                                        let session = LanguageModelSession(
                                            instructions: instructions
                                        )
                                        let stream = session.streamResponse(to: editPrompt)
                                        
                                        for try await partial in stream {
                                            if Task.isCancelled {
                                                break
                                            }
                                            self.document.text = partial
                                            self.editorModel.text = partial
                                        }
                                        
                                        editText = ""
                                    } catch {
                                        print("Generation error: \(error.localizedDescription)")
                                    }
                                    
                                    isGeneratingContent = false
                                    generationTask = nil
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(editText.isEmpty)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
                }
            }
            .animation(.spring(response: 0.3), value: showEditInput)
            
            if !showEditInput {
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
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showEditInput.toggle()
                        }
                    } label: {
                        Image(systemName: "character.textbox")
                    }
                    .disabled(isGeneratingContent)
                    .controlSize(.extraLarge)
                    .buttonStyle(.glass)
                    Button {
                        if isGeneratingContent {
                            // Stop generation
                            generationTask?.cancel()
                            generationTask = nil
                            isGeneratingContent = false
                        } else {
                            // Start generation
                            generationTask = Task {
                                do {
                                    isGeneratingContent = true
                                    
                                    let prompt = Prompt("Using title: \(document.title)\n\nand any existing content:\n\(editorModel.text)\n\nPlease generate enhanced content that builds upon this foundation while maintaining its core message and style.")
                                    
                                    let session = LanguageModelSession(
                                        instructions: instructions
                                    )
                                    let stream = session.streamResponse(to: prompt)
                                    
                                    for try await partial in stream {
                                        if Task.isCancelled {
                                            break
                                        }
                                        self.document.text = partial
                                        self.editorModel.text = partial
                                    }
                                } catch {
                                    print("Generation error: \(error.localizedDescription)")
                                }
                                
                                isGeneratingContent = false
                                generationTask = nil
                            }
                        }
                    } label: {
                        Image( systemName: isGeneratingContent ? "stop.fill" : "sparkle")
                    }
                    .controlSize(.extraLarge)
                    .buttonStyle(.glass)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    // Add scheduled date section
                    Section {
                        if let date = scheduledDate {
                            Label("Scheduled: \(date.formatted(date: .abbreviated, time: .shortened))", 
                                  systemImage: "calendar.badge.clock")
                                .font(.caption)
                        }
                        
                        Button {
                            showScheduleDatePicker = true
                        } label: {
                            Label(scheduledDate == nil ? "Schedule Post" : "Change Schedule", 
                                  systemImage: "calendar")
                        }
                        
                        if scheduledDate != nil {
                            Button(role: .destructive) {
                                scheduledDate = nil
                            } label: {
                                Label("Remove Schedule", systemImage: "calendar.badge.minus")
                            }
                        }
                    }
                    
                    Divider()
                    
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
                        Label(tag.capitalized, systemImage: "tag")
                    }
                    
                    Button {
                        openSettings = true
                        modal.impactOccurred()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    self.isSending = true
                    Task {
                        await uploadPost()
                    }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up")
                    }
                }
                .frame(width: 24, height: 24)
            }
        }
        .sheet(isPresented: $openPreview) {
            PreviewView(document: document)
                .padding(.top, 24)
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { url in
                uploadImage(url)
            }
        }
        .sheet(isPresented: $showScheduleDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Schedule for", 
                              selection: Binding(
                                get: { scheduledDate ?? Date() },
                                set: { scheduledDate = $0 }
                              ),
                              in: Date()...,
                              displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("Schedule Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showScheduleDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if scheduledDate == nil {
                                scheduledDate = Date()
                            }
                            showScheduleDatePicker = false
                        }
                    }
                }
            }
        }

        .onAppear {
            setupNotificationObservers()
            setupPasteInterceptor()
            loadPosts()
        }
        .onDisappear {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
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

    private func setupNotificationObservers() {
        // Create a reference to self that can be captured
        let view = self
        
        // Store observers so we can remove them later
        observers = [
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
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                self.document.text = partial
                self.editorModel.text = partial
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

    func uploadPost() async {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        do {
            // Generate AI content
            let summaryPrompt = "Summarise this text in a clear and concise way that captures the main points and key ideas:\n\n\(document.text). Use British English always."
            let snippetPrompt = "Create a compelling 120-character or less snippet that captures the essence of this text and entices readers to read more:\n\n\(document.text). Do not include quotation marks. Use British English always."
            
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
                        self.toastMessage = "Failed to submit post"
                        self.showToast = true
                        print(error)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.toastMessage = "Failed to generate AI content"
                self.showToast = true
                self.isSending = false
                print("AI Generation Error:", error)
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
        
        ContentGenerationService.generateContent(title: document.title, content: document.text) { result in
            Task { @MainActor in
                switch result {
                case .success(let generatedContent):
                    document.text = generatedContent
                    showToastMessage("Content generated successfully")
                case .failure(let error):
                    showToastMessage(error.localizedDescription)
                }
                isGeneratingContent = false
                showGeneratingToast = false
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
                        return
                    }
                }
            }
            // If we get here, the mention context is invalid
            showPostSuggestions = false
            atSymbolPosition = nil
            postSearchText = ""
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
                    
                    // Calculate position for overlay (simplified for now)
                    suggestionPosition = CGPoint(x: 20, y: 40)
                }
            }
        }
    }

    private func insertPostReference(_ post: Post) {
        guard let textView = textView,
              let atPosition = atSymbolPosition else { return }
        
        // Calculate the range to replace (from @ to current position)
        let replaceRange = NSRange(location: atPosition, length: cursorPosition - atPosition)
        
        // Create the markdown link
        let markdownLink = "[\(post.title)](https://karlkoch.com/writings/\(post.slug))"
        
        // Replace the @ and any text typed after it with the markdown link
        if let start = textView.position(from: textView.beginningOfDocument, offset: replaceRange.location),
           let end = textView.position(from: start, offset: replaceRange.length),
           let textRange = textView.textRange(from: start, to: end) {
            
            textView.replace(textRange, withText: markdownLink)
            
            // Update document
            document.text = textView.text
            
            // Move cursor to end of inserted link
            let newPosition = atPosition + markdownLink.count
            if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
            }
        }
        
        // Reset
        showPostSuggestions = false
        atSymbolPosition = nil
        postSearchText = ""
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

extension String {
    func substring(with nsrange: NSRange) -> String? {
        let nsString = self as NSString
        let textLength = nsString.length
        let isValid = nsrange.location >= 0 && nsrange.length >= 0 && nsrange.location <= textLength && (nsrange.location + nsrange.length) <= textLength
        if !isValid {
    #if DEBUG
            print("[String.substring(with:)] Invalid range: \(nsrange), text length: \(textLength)")
    #endif
            return nil
        }
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
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
                    try? imageData.write(to: tempFileURL)
                    parent.onImagePicked(tempFileURL)
                }
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
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

#if os(macOS)
// Add ImageShelf component before MacContentView
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
#if os(iOS)
                        showImagePicker = true
#else
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
#endif
                    }
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        
                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                            guard let url = url, error == nil else { return }
                            
#if os(macOS)
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
#endif
                            
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
    #if os(iOS)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { url in
                onImageDropped(url)
            }
        }
    #endif
    }
}

#if os(iOS)
struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
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
                    try? imageData.write(to: tempFileURL)
                    parent.onImagePicked(tempFileURL)
                }
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

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
    
    // Add state for scheduled date
    @State private var scheduledDate: Date? = nil
    @State private var showPostPicker = false
    
    // Add state for inline suggestions
    @State private var showPostSuggestions = false
    @State private var atSymbolPosition: Int? = nil
    @State private var postSearchText = ""
    @State private var allPosts: [Post] = []
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
        6. Use crisp, precise language, maintaining British English spellings.
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
        
        The content should be a continuation of your existing body of work, fitting seamlessly into your established opinions and views on AI and product development. Always use Markdown for formatting.
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
                    
                    // Preview pane
                    if !focusMode {
                        PreviewView(document: document)
                            .frame(minWidth: 400)
                            .padding()
                    }
                }
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
            
            if isGeneratingContent {
                VStack {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.primary)
                        
                        Text("Generating content...")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(document.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text(statsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Add scheduled date items
            ToolbarItem(placement: .automatic) {
                if let date = scheduledDate {
                    Text("Scheduled: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                DatePicker("", 
                          selection: Binding(
                            get: { scheduledDate ?? Date() },
                            set: { scheduledDate = $0 }
                          ),
                          in: Date()...,
                          displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .opacity(scheduledDate == nil ? 0.7 : 1.0)
                    .help(scheduledDate == nil ? "Schedule post" : "Change scheduled time")
            }
            
            ToolbarItem(placement: .automatic) {
                if scheduledDate != nil {
                    Button {
                        scheduledDate = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .help("Remove schedule")
                }
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
                    Text(tag.capitalized)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: "eye")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    showEditInput.toggle()
                } label: {
                    Image(systemName: "character.textbox")
                }
                .disabled(isGeneratingContent)
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
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 24, height: 24)
            }
        }
        .onAppear {
            setupNotificationObservers()
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
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                
                HStack {
                    Button("Cancel") {
                        showEditInput = false
                        editText = ""
                    }
                    
                    Spacer()
                    
                    Button("Apply Edit") {
                        Task {
                            showEditInput = false
                            await performEdit()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editText.isEmpty)
                }
            }
            .padding()
            .frame(width: 400, height: 200)
        }
        .sheet(isPresented: $showPostPicker) {
            PostPicker(isPresented: $showPostPicker) { post in
                insertPostReference(post)
            }
            .frame(width: 500, height: 600)
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
            let snippetPrompt = "Create a compelling 120-character or less snippet that captures the essence of this text and entices readers to read more:\n\n\(document.text). Do not include quotation marks. Use British English always."
            
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
            let session = LanguageModelSession()
            let stream = session.streamResponse(to: prompt)
            
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }
                self.document.text = partial
                self.editorModel.text = partial
            }
            
            showToastMessage("Content generated successfully")
        } catch {
            showToastMessage("Failed to generate content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        showGeneratingToast = false
        generationTask = nil
    }
    
    private func performEdit() async {
        isGeneratingContent = true
        
        let editPrompt = """
        Instruction: \(editText)
        Content to edit: \(editorModel.text)
        Apply the instruction to the content. If there is selected text, focus on editing only that part.
        Selected text: \(selectedText)
        Return only the edited content. Do not include any other text, explanation, narrative, or markdown formatting like '---'.
        """
        
        do {
            let session = LanguageModelSession(instructions: instructions)
            let stream = session.streamResponse(to: editPrompt)
            
            for try await partial in stream {
                if Task.isCancelled {
                    break
                }
                self.document.text = partial
                self.editorModel.text = partial
            }
            
            editText = ""
            showToastMessage("Content edited successfully")
        } catch {
            showToastMessage("Failed to edit content: \(error.localizedDescription)")
        }
        
        isGeneratingContent = false
        generationTask = nil
    }
    
    private func checkForAtSymbol(in text: String) {
        let currentPosition = cursorPosition
        
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
                    showPostPicker = true
                }
            }
        }
    }
    
    private func insertPostReference(_ post: Post) {
        guard let textView = textView,
              let atPosition = atSymbolPosition else { return }
        
        // Calculate the range to replace (from @ to current position)
        let replaceRange = NSRange(location: atPosition, length: cursorPosition - atPosition)
        
        // Create the markdown link
        let markdownLink = "[\(post.title)](https://karlkoch.com/writings/\(post.slug))"
        
        // Replace the @ and any text typed after it with the markdown link
        if let start = textView.position(from: textView.beginningOfDocument, offset: replaceRange.location),
           let end = textView.position(from: start, offset: replaceRange.length),
           let textRange = textView.textRange(from: start, to: end) {
            
            textView.replace(textRange, withText: markdownLink)
            
            // Update document
            document.text = textView.text
            
            // Move cursor to end of inserted link
            let newPosition = atPosition + markdownLink.count
            if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
            }
        }
        
        // Reset
        showPostSuggestions = false
        atSymbolPosition = nil
        postSearchText = ""
    }
    
    private func loadPosts() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.find(type: "writings",
                    props: "id,title,slug,type",
                    limit: "100",
                    status: .any
        ) { result in
            Task { @MainActor in
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

extension String {
    func substring(with nsrange: NSRange) -> String? {
        let nsString = self as NSString
        let textLength = nsString.length
        let isValid = nsrange.location >= 0 && nsrange.length >= 0 && nsrange.location <= textLength && (nsrange.location + nsrange.length) <= textLength
        if !isValid {
#if DEBUG
            print("[String.substring(with:)] Invalid range: \(nsrange), text length: \(textLength)")
#endif
            return nil
        }
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
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

#endif
