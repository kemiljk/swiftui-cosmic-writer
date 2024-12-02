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
    @State private var submitSuccessful: Bool = false
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var textView: UITextView? = nil
    
    let device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
    
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
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // iPad toolbar
            if device == .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    Button {
                        uploadPost()
                        modal.impactOccurred(intensity: 1.0)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
            }
            
            // iPhone toolbar
            if device == .phone {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                        uploadPost()
                        modal.impactOccurred(intensity: 1.0)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
            }
        }
        .background(Color("bg"))
        .alert(isPresented: $submitSuccessful) {
            Alert(
                title: Text("Submitted!"),
                message: Text("Submitted draft post successfully"),
                dismissButton: .default(Text("Got it!"))
            )
        }
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
                    self.submitSuccessful = true
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
    @State private var submitSuccessful: Bool = false
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var textView: NSTextView? = nil
    @State private var observers: [NSObjectProtocol] = []
    
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
            }
            .background(.background)
            .frame(minWidth: 400)
            
            // Preview pane
            if !focusMode {
                PreviewView(document: document)
                    .frame(minWidth: 400)
            }
        }
        .toolbar {
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
                    uploadPost()
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle")
                }
                .tint(.accentColor)
            }
            
            
            ToolbarItem(placement: .navigation) {
                Button {
                    openSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        .navigationTitle(document.title)
        .alert(isPresented: $submitSuccessful) {
            Alert(
                title: Text("Submitted!"),
                message: Text("Submitted draft post successfully"),
                dismissButton: .default(Text("Got it!"))
            )
        }
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
                    self.submitSuccessful = true
                    print("Uploaded \(self.document.title)")
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
        
        // Print current selection info
        let selectedRange = textView.selectedRange()
        
        if selectedRange.length > 0 {
            // There is selected text
            guard let selectedContent = textView.string.substring(with: selectedRange) else {
                return
            }
            
            let formattedText: String
            switch format {
            case .italic:
                formattedText = "_\(selectedContent)_"
            case .bold:
                formattedText = "**\(selectedContent)**"
            case .strikethrough:
                formattedText = "~~\(selectedContent)~~"
            default:
                return
            }
            
            textView.replaceCharacters(in: selectedRange, with: formattedText)
            
            document.text = textView.string
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
