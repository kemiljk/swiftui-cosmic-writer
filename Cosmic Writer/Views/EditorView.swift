//
//  EditorView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 02/12/2024.
//
import SwiftUI
import HighlightedTextEditor

#if os(iOS)
struct EditorView: View {
    @Binding var document: Cosmic_WriterDocument
    @Binding var cursorPosition: Int
    @Binding var selectionLength: Int
    @Binding var selectedText: String
    @Binding var textView: UITextView?
    var onFormat: (MarkdownFormatting) -> Void
    @Binding var editorModel: HighlightedTextModel
    var showEditInput: Bool
    @Binding var highlightedRange: NSRange?
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor
            HighlightedTextEditorObservable(model: editorModel, highlightRules: .markdown)
                .onSelectionChange { (range: NSRange) in
                    Task { @MainActor in
                        safeUIKitToSwiftUIUpdate(textView) {
                            cursorPosition = range.location
                            selectionLength = range.length
                            
                            // Only update selectedText if we're not in edit mode
                            // This prevents the selection from being cleared when the overlay appears
                            if !showEditInput {
                                if range.length > 0 {
                                    let nsString = editorModel.text as NSString
                                    let safeRange = NSRange(
                                        location: min(range.location, nsString.length),
                                        length: min(range.length, nsString.length - range.location)
                                    )
                                    if safeRange.location >= 0 && safeRange.length > 0 && safeRange.location + safeRange.length <= nsString.length {
                                        selectedText = nsString.substring(with: safeRange)
                                    } else {
                                        selectedText = ""
                                    }
                                } else {
                                    selectedText = ""
                                }
                            }
                            // When in edit mode, preserve the current selection by not updating selectedText
                        }
                    }
                }
                .onTextChange { newText in
                    document.text = newText
                }
                .introspect { editor in
                    Task { @MainActor in
                        textView = editor.textView
                        editor.textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 64, right: 16)
                        editor.textView.allowsEditingTextAttributes = false
                        editor.textView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.5)
                        editor.textView.layer.cornerRadius = 24
                        let toolbarView = ToolbarView {
                            editor.textView.resignFirstResponder()
                        }
                        let hostingController = UIHostingController(rootView: toolbarView)
                        hostingController.view.frame = CGRect(
                            x: 0,
                            y: 0,
                            width: max((editor.textView.window?.windowScene?.screen.bounds.width ?? 375) - 32, 320),
                            height: 44
                        )
                        hostingController.view.backgroundColor = .systemBackground
                        editor.textView.inputAccessoryView = hostingController.view
                        editor.scrollView?.contentInset.bottom = 16

                        // Apply custom highlighting if range is set
                        applyCustomHighlighting(to: editor.textView)
                    }
                }
                .onChange(of: highlightedRange) { _, _ in
                    // Update highlighting when range changes
                    if let tv = textView {
                        applyCustomHighlighting(to: tv)
                    }
                }
        }
        .padding(8)
        .onAppear {
            editorModel.text = document.text
        }
        .dropDestination(for: Data.self) { items, location in
            for item in items {
                if let image = UIImage(data: item),
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "dropped_image_\(Date().timeIntervalSince1970).jpg"
                    NotificationCenter.default.post(
                        name: .uploadImage,
                        object: nil,
                        userInfo: [
                            "imageData": imageData,
                            "fileName": fileName
                        ]
                    )
                    return true
                }
            }
            return false
        }
    }

    // Apply custom highlighting to the text view
    private func applyCustomHighlighting(to textView: UITextView) {
        guard let range = highlightedRange,
              range.location >= 0,
              range.length > 0,
              range.location + range.length <= textView.text.count else {
            // Clear any existing background color
            if let existingText = textView.attributedText {
                let mutableText = NSMutableAttributedString(attributedString: existingText)
                let fullRange = NSRange(location: 0, length: mutableText.length)
                mutableText.removeAttribute(.backgroundColor, range: fullRange)

                let currentSelection = textView.selectedRange
                textView.attributedText = mutableText
                textView.selectedRange = currentSelection
            }
            return
        }

        // Get existing attributed text or create from plain text
        let attributedString: NSMutableAttributedString
        if let existingText = textView.attributedText {
            attributedString = NSMutableAttributedString(attributedString: existingText)
        } else {
            attributedString = NSMutableAttributedString(string: textView.text)
        }

        // Apply background color to the highlighted range
        attributedString.addAttribute(.backgroundColor,
                                      value: UIColor.systemBlue.withAlphaComponent(0.2),
                                      range: range)

        // Preserve the selection
        let currentSelection = textView.selectedRange

        // Update text view
        textView.attributedText = attributedString

        // Restore selection
        textView.selectedRange = currentSelection
    }
}

// Add the ToolbarView
struct ToolbarView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Heading
            Button {
                NotificationCenter.default.post(name: .applyHeading, object: nil)
            } label: {
                Image(systemName: "number")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Bold
            Button {
                NotificationCenter.default.post(name: .applyBold, object: nil)
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Italic
            Button {
                NotificationCenter.default.post(name: .applyItalic, object: nil)
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Code
            Button {
                NotificationCenter.default.post(name: .applyCode, object: nil)
            } label: {
                Image(systemName: "terminal")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Code Block
            Button {
                NotificationCenter.default.post(name: .applyCodeBlock, object: nil)
            } label: {
                Image(systemName: "curlybraces.square")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Image
            Button {
                NotificationCenter.default.post(name: .applyImage, object: nil)
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .medium))
            }
            
            // Link
            Button {
                NotificationCenter.default.post(name: .applyLink, object: nil)
            } label: {
                Image(systemName: "link")
                    .font(.system(size: 22, weight: .medium))
            }
            
            Spacer()
            
            // Dismiss keyboard
            Button(action: onDismiss) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 22, weight: .medium))
            }
        }
        .padding(.horizontal)
        .frame(height: 44)
        .background(Color(uiColor: .systemBackground))
    }
}

class PasteInterceptor: NSObject, UITextViewDelegate {
    static let shared = PasteInterceptor()
    weak var textView: UITextView?
    var onFormat: ((MarkdownFormatting) -> Void)?
    private var observers: [NSObjectProtocol] = []
    
    override init() {
        super.init()
        setupPasteInterceptor()
        setupFormatObservers()
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func setupFormatObservers() {
        // Heading
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyHeading,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .heading)
            }
        )
        
        // Bold
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyBold,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .bold)
            }
        )
        
        // Italic
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyItalic,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .italic)
            }
        )
        
        // Code
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyCode,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .code)
            }
        )
        
        // Code Block
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyCodeBlock,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .codeBlock)
            }
        )
        
        // Image
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyImage,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyFormatting(format: .image)
            }
        )
        
        // Link
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .applyLink,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleLinkFormatting()
            }
        )
    }
    
    private func applyFormatting(format: MarkdownFormatting) {
        guard let textView = textView else { return }
        guard textView.markedTextRange == nil else { return }
        let selectedRange = textView.selectedRange
        let fullText = textView.text ?? ""
        let textLength = (fullText as NSString).length
        let isValid = selectedRange.location >= 0 && selectedRange.length >= 0 && selectedRange.location + selectedRange.length <= textLength
        guard isValid else { return }
        let safeRange = NSRange(
            location: min(selectedRange.location, textLength),
            length: min(selectedRange.length, max(0, textLength - selectedRange.location))
        )
        if safeRange.length > 0 {
            print("[DEBUG] About to substring: safeRange=\(safeRange), textLength=\(textLength), function=\(#function)")
            let selectedText = (fullText as NSString).substring(with: safeRange)
            let formattedText: String
            switch format {
            case .heading:
                formattedText = selectedText.hasPrefix("# ") ?
                String(selectedText.dropFirst(2)) :
                "# \(selectedText)"
            case .bold:
                formattedText = selectedText.hasPrefix("**") && selectedText.hasSuffix("**") ?
                String(selectedText.dropFirst(2).dropLast(2)) :
                "**\(selectedText)**"
            case .italic:
                formattedText = selectedText.hasPrefix("_") && selectedText.hasSuffix("_") ?
                String(selectedText.dropFirst().dropLast()) :
                "_\(selectedText)_"
            case .code:
                formattedText = selectedText.hasPrefix("`") && selectedText.hasSuffix("`") ?
                String(selectedText.dropFirst().dropLast()) :
                "`\(selectedText)`"
            case .codeBlock:
                formattedText = selectedText.hasPrefix("```") && selectedText.hasSuffix("\n```") ?
                String(selectedText.dropFirst(4).dropLast(4)) :
                "```\(selectedText)\n```"
            case .image:
                formattedText = "![\(selectedText)]()"
            case .link:
                formattedText = "[\(selectedText)]()"
            default:
                return
            }
            if let start = textView.position(from: textView.beginningOfDocument, offset: safeRange.location),
               let end = textView.position(from: start, offset: safeRange.length),
               let textRange = textView.textRange(from: start, to: end) {
                textView.replace(textRange, withText: formattedText)
            }
            Task { @MainActor in
                let newPosition = min(safeRange.location + formattedText.count, (textView.text as NSString).length)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
            }
        } else {
            // No selection, insert placeholder
            let insertion: String
            let cursorOffset: Int
            switch format {
            case .heading:
                insertion = "# "
                cursorOffset = 2
            case .bold:
                insertion = "****"
                cursorOffset = 2
            case .italic:
                insertion = "__"
                cursorOffset = 1
            case .code:
                insertion = "``"
                cursorOffset = 1
            case .codeBlock:
                insertion = "```\n\n```"
                cursorOffset = 4
            case .image:
                insertion = "![]()"
                cursorOffset = 2
            case .link:
                insertion = "[]()"
                cursorOffset = 1
            default:
                return
            }
            if let textRange = textView.selectedTextRange {
                textView.replace(textRange, withText: insertion)
                Task { @MainActor in
                    let newPosition = min(safeRange.location + cursorOffset, (textView.text as NSString).length)
                    if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                        textView.selectedTextRange = textView.textRange(from: position, to: position)
                    }
                }
            }
        }
    }
    
    private func handleLinkFormatting() {
        guard let textView = textView else { return }
        guard textView.markedTextRange == nil else { return }
        let selectedRange = textView.selectedRange
        let fullText = textView.text ?? ""
        let textLength = (fullText as NSString).length
        let isValid = selectedRange.location >= 0 && selectedRange.length >= 0 && selectedRange.location + selectedRange.length <= textLength
        guard isValid else { return }
        let safeRange = NSRange(
            location: min(selectedRange.location, textLength),
            length: min(selectedRange.length, max(0, textLength - selectedRange.location))
        )
        let pasteboard = UIPasteboard.general
        var clipboardUrl: String? = nil
        if let urlString = pasteboard.string {
            if urlString.hasPrefix("http://") ||
                urlString.hasPrefix("https://") ||
                urlString.hasPrefix("www.") {
                clipboardUrl = urlString
            }
        }
        if safeRange.length > 0 {
            print("[DEBUG] About to substring: safeRange=\(safeRange), textLength=\(textLength), function=\(#function)")
            let selectedText = (fullText as NSString).substring(with: safeRange)
            let formattedText: String
            if let url = clipboardUrl {
                formattedText = "[\(selectedText)](\(url))"
            } else {
                pasteboard.string = selectedText
                formattedText = "[\(selectedText)]()"
            }
            if let start = textView.position(from: textView.beginningOfDocument, offset: safeRange.location),
               let end = textView.position(from: start, offset: safeRange.length),
               let textRange = textView.textRange(from: start, to: end) {
                textView.replace(textRange, withText: formattedText)
            }
            Task { @MainActor in
                let newPosition = min(safeRange.location + formattedText.count, (textView.text as NSString).length)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
            }
        } else {
            let insertion = clipboardUrl != nil ? "[](\(clipboardUrl!))" : "[]()"
            if let textRange = textView.selectedTextRange {
                textView.replace(textRange, withText: insertion)
                Task { @MainActor in
                    let offset = clipboardUrl == nil ? 1 : insertion.count
                    let newPosition = min(safeRange.location + offset, (textView.text as NSString).length)
                    if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                        textView.selectedTextRange = textView.textRange(from: position, to: position)
                    }
                }
            }
        }
    }
    
    private func setupPasteInterceptor() {
        let pasteObserver = NotificationCenter.default.addObserver(
            forName: UIPasteboard.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePaste()
        }
        observers.append(pasteObserver)
    }
    
    private func handlePaste() {
        let pasteboard = UIPasteboard.general
        guard let textView = textView else { return }
        
        // Handle image paste
        if let image = pasteboard.image {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let fileName = "pasted_image_\(Date().timeIntervalSince1970).jpg"
                NotificationCenter.default.post(
                    name: .uploadImage,
                    object: nil,
                    userInfo: [
                        "imageData": imageData,
                        "fileName": fileName
                    ]
                )
            }
            return
        }
        
        // Handle URL paste for markdown links
        if let url = pasteboard.url?.absoluteString {
            if url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("www.") {
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
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Check if this is a paste operation
        if text.count > 1 {
            // Check if we have selected text
            if let selectedRange = textView.selectedTextRange,
               let selectedText = textView.text(in: selectedRange),
               !selectedText.isEmpty {
                
                // Check if the pasted text is a URL
                if text.hasPrefix("http://") ||
                    text.hasPrefix("https://") ||
                    text.hasPrefix("www.") {
                    // Create markdown link
                    let formattedText = "[\(selectedText)](\(text))"
                    
                    // Replace selected text with formatted text
                    textView.replace(selectedRange, withText: formattedText)
                    return false
                }
            }
        }
        return true
    }
}
#endif

#if os(macOS)
struct EditorView: View {
    @Binding var document: Cosmic_WriterDocument
    @Binding var cursorPosition: Int
    @Binding var selectionLength: Int
    @Binding var selectedText: String
    @Binding var textView: NSTextView?
    var onFormat: (MarkdownFormatting) -> Void
    @Binding var editorModel: HighlightedTextModel
    var showEditInput: Bool
    
    var body: some View {
        HighlightedTextEditorObservable(model: editorModel, highlightRules: .markdown)
            .onSelectionChange { (range: NSRange) in
                Task { @MainActor in
                    cursorPosition = range.location
                    selectionLength = range.length
                    
                    // Only update selectedText if we're not in edit mode
                    // This prevents the selection from being cleared when the overlay appears
                    if !showEditInput {
                        if range.length > 0 {
                            let nsString = editorModel.text as NSString
                            let safeRange = NSRange(
                                location: min(range.location, nsString.length),
                                length: min(range.length, nsString.length - range.location)
                            )
                            if safeRange.location >= 0 && safeRange.length > 0 && safeRange.location + safeRange.length <= nsString.length {
                                selectedText = nsString.substring(with: safeRange)
                            } else {
                                selectedText = ""
                            }
                        } else {
                            selectedText = ""
                        }
                    }
                    // When in edit mode, preserve the current selection by not updating selectedText
                }
            }
            .onTextChange { newText in
                document.text = newText
            }
            .introspect { editor in
                DispatchQueue.main.async {
                    textView = editor.textView
                    // Optionally configure the NSTextView here
                }
            }
            .onAppear {
                editorModel.text = document.text
            }
            .padding()
            .background(Color.secondary.opacity(0.01))
    }
}
#endif

