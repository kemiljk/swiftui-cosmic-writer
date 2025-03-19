import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import HighlightedTextEditor
import MarkdownUI
import CosmicSDK

struct ContentView: View {
    @Binding var document: Cosmic_WriterDocument
    
    var body: some View {
        #if os(iOS)
        iOSContentView(document: $document)
        #else
        MacContentView(document: $document)
        #endif
    }
}

#if os(iOS)
@MainActor
struct iOSContentView: View {
    @Binding var document: Cosmic_WriterDocument
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
    
    let device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
    
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
        VStack(spacing: 0) {
            if device == .pad {
                HStack(spacing: 16) {
                    EditorView(
                        document: $document,
                        cursorPosition: $cursorPosition,
                        selectionLength: $selectionLength,
                        selectedText: $selectedText,
                        textView: $textView,
                        onFormat: { format in
                            applyMarkdownFormatting(format)
                        }
                    )
                    if !focusMode {
                        Divider()
                        PreviewView(document: document)
                    }
                }
            } else {
                EditorView(
                    document: $document,
                    cursorPosition: $cursorPosition,
                    selectionLength: $selectionLength,
                    selectedText: $selectedText,
                    textView: $textView,
                    onFormat: { format in
                        applyMarkdownFormatting(format)
                    }
                )
            }
            if showToast {
                ToastView(message: "Post submitted")
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up to visible position
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
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // iPad toolbar
            if device == .pad {
                ToolbarItem(placement: .topBarLeading) {
                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Menu {
                            Button { tag = "design" } label: { Text("Design") }
                            Button { tag = "development" } label: { Text("Development") }
                            Button { tag = "opinion" } label: { Text("Opinion") }
                            Button { tag = "journal" } label: { Text("Journal") }
                        } label: {
                            Image(systemName: "tag")
                        }
                        
                        Button {
                            withAnimation {
                                focusMode.toggle()
                            }
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "eye")
                        }
                        
                        Button {
                            openSettings = true
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isSending {
                        ProgressView()
                            .frame(width: 24)
                    } else {
                        Button {
                            self.isSending = true
                            uploadPost()
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                    }
                }
            }
            
            // iPhone toolbar
            if device == .phone {
                ToolbarItem(placement: .topBarLeading) {
                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu {
                            ForEach(PostTag.allCases, id: \.self) { postTag in
                                Button {
                                    tag = postTag.rawValue
                                } label: {
                                    Text(postTag.title)
                                }
                            }
                        } label: {
                            Label("Tag", systemImage: "tag")
                        }
                        
                        Divider()
                        
                        Button {
                            withAnimation {
                                openPreview.toggle()
                                modal.impactOccurred()
                            }
                        } label: {
                            Label("Preview", systemImage: "eye")
                        }
                        
                        Button {
                            openSettings = true
                            modal.impactOccurred()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        self.isSending = true
                        uploadPost()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                    }
                    .frame(width: 24, height: 24)
                }
            }
        }
        .background(Color("bg"))
        .sheet(isPresented: $openPreview) {
            PreviewView(document: document)
                .padding(.top, 24)
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
    
    func uploadPost() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.insertOne(type: "writings", title: document.title, metadata: [
            "tag": tag,
            "content": document.text,
        ], status: .draft) { results in
            Task { @MainActor in
                switch results {
                case .success(_):
                    self.showToast = true
                    self.isSending = false
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    func setCursorPosition(to position: Int) {
        DispatchQueue.main.async {
            guard let textView = self.textView else {
                print("TextView not found")
                return
            }
            #if os(iOS)
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: position) {
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
}
#endif

#if os(macOS)
@MainActor
struct MacContentView: View {
    @Binding var document: Cosmic_WriterDocument
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
        HSplitView {
            // Editor pane
            VStack {
                HighlightedTextEditor(text: $document.text, highlightRules: .markdown)
                    .onSelectionChange { (range: NSRange) in
                        cursorPosition = range.location
                        selectionLength = range.length
                    }
                    .introspect { editor in
                        DispatchQueue.main.async {
                            textView = editor.textView
                            
                            if let selectedRange = textView?.selectedRange() {
                                selectedText = textView?.string.substring(with: selectedRange) ?? ""
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if showToast {
                    ToastView(message: "Post submitted")
                        .offset(y: toastOffset)
                        .animation(.spring(response: 0.3), value: toastOffset)
                }
            }
            .background(.background)
            .frame(minWidth: 400)
            
            // Preview pane
            if !focusMode {
                PreviewView(document: document)
                    .frame(minWidth: 400)
                    .padding()
            }
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up to visible position
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text(statsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(PostTag.allCases, id: \.self) { postTag in
                        Button {
                            tag = postTag.rawValue
                        } label: {
                            Text(postTag.title)
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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.isSending = true
                    uploadPost()
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
        .navigationTitle(document.title)
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .frame(width: 400, height: 300)
        }
    }
    
    private func updateCursorPosition() {
       guard let textView = textView else { return }
       textView.selectedRange = NSRange(location: cursorPosition, length: 0)
   }
    
    @MainActor
    func uploadPost() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.insertOne(type: "writings", title: document.title, metadata: [
            "content": document.text,
            "tag": tag,
        ], status: .draft) { results in
            Task { @MainActor in
                switch results {
                case .success(_):
                    self.showToast = true
                    self.isSending = false
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Create a reference to self that can be captured
        let view = self
        
        // Store observers so we can remove them later
        observers = [
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
}

extension MacContentView {
    func applyMarkdownFormatting(_ format: MarkdownFormatting) {
        guard let textView = textView else {
            return
        }
        
        let selectedRange = textView.selectedRange()
        
        if selectedRange.length > 0 {
            // There is selected text
            guard let selectedContent = textView.string.substring(with: selectedRange) else {
                return
            }
            
            let formattedText: String
            switch format {
            case .italic:
                if selectedContent.hasPrefix("_") && selectedContent.hasSuffix("_") {
                    // Remove italic formatting
                    formattedText = String(selectedContent.dropFirst().dropLast())
                } else {
                    formattedText = "_\(selectedContent)_"
                }
            case .bold:
                if selectedContent.hasPrefix("**") && selectedContent.hasSuffix("**") {
                    // Remove bold formatting
                    formattedText = String(selectedContent.dropFirst(2).dropLast(2))
                } else {
                    formattedText = "**\(selectedContent)**"
                }
            case .strikethrough:
                if selectedContent.hasPrefix("~~") && selectedContent.hasSuffix("~~") {
                    // Remove strikethrough formatting
                    formattedText = String(selectedContent.dropFirst(2).dropLast(2))
                } else {
                    formattedText = "~~\(selectedContent)~~"
                }
            default:
                return
            }
            
            textView.replaceCharacters(in: selectedRange, with: formattedText)
            document.text = textView.string
            
            // Update selection to cover new text
            let newLength = formattedText.count
            textView.setSelectedRange(NSRange(location: selectedRange.location, length: newLength))
        } else {
            // No selection, insert at cursor
            let insertion: String
            let cursorOffset: Int
            
            switch format {
            case .italic:
                insertion = "__"
                cursorOffset = 1
            case .bold:
                insertion = "****"
                cursorOffset = 2
            case .strikethrough:
                insertion = "~~~~"
                cursorOffset = 2
            default:
                return
            }
            
            let insertionRange = NSRange(location: selectedRange.location, length: 0)
            textView.shouldChangeText(in: insertionRange, replacementString: insertion)
            textView.replaceCharacters(in: insertionRange, with: insertion)
            textView.didChangeText()
            
            // Update cursor position
            let newPosition = selectedRange.location + cursorOffset
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        }
    }
    
    func handleLinkFormatting() {
        guard let textView = textView else { return }
        
        // Check clipboard for URL
        let pasteboard = NSPasteboard.general
        var clipboardUrl: String? = nil
        
        // Try to get URL from clipboard
        if let clipboardString = pasteboard.string(forType: .string) {
            // Basic URL validation
            if clipboardString.hasPrefix("http://") ||
               clipboardString.hasPrefix("https://") ||
               clipboardString.hasPrefix("www.") {
                clipboardUrl = clipboardString
            }
        }
        
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            // There is selected text
            if let selectedContent = textView.string.substring(with: selectedRange) {
                // Store selected text for potential later use
                let tempSelected = selectedContent
                
                let formattedText: String
                if let url = clipboardUrl {
                    formattedText = "[\(selectedContent)](\(url))"
                } else {
                    // No URL in clipboard, save selected text and leave parentheses empty
                    pasteboard.clearContents()
                    pasteboard.setString(selectedContent, forType: .string)
                    formattedText = "[\(selectedContent)]()"
                }
                
                textView.shouldChangeText(in: selectedRange, replacementString: formattedText)
                textView.replaceCharacters(in: selectedRange, with: formattedText)
                textView.didChangeText()
                
                // Position cursor appropriately
                let newPosition: Int
                if clipboardUrl != nil {
                    // Place cursor at end if we inserted a URL
                    newPosition = selectedRange.location + formattedText.count
                } else {
                    // Place cursor between parentheses if no URL
                    newPosition = selectedRange.location + tempSelected.count + 3
                }
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
                
                // Update the document text
                document.text = textView.string
            }
        } else {
            // No selection, insert empty link
            let insertion: String
            if let url = clipboardUrl {
                insertion = "[]("+url+")"
            } else {
                insertion = "[]()"
            }
            let insertionRange = NSRange(location: selectedRange.location, length: 0)
            
            textView.shouldChangeText(in: insertionRange, replacementString: insertion)
            textView.replaceCharacters(in: insertionRange, with: insertion)
            textView.didChangeText()
            
            // Position cursor between brackets if no URL, or at end if URL was inserted
            let newPosition = selectedRange.location + (clipboardUrl == nil ? 1 : insertion.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        }
    }
}

extension String {
    func substring(with nsrange: NSRange) -> String? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
}

#endif
