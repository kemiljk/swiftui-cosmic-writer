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
    
    var body: some View {
        HighlightedTextEditor(text: $document.text, highlightRules: .markdown)
            .onSelectionChange { (range: NSRange) in
                cursorPosition = range.location
                selectionLength = range.length
            }
            .introspect { editor in
                DispatchQueue.main.async {
                    textView = editor.textView
                    textView?.autocorrectionType = .no
                    editor.textView.backgroundColor = UIColor(named: "bg")
                    editor.textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                    
                    // Add paste interceptor
                    editor.textView.delegate = PasteInterceptor.shared
                    PasteInterceptor.shared.textView = editor.textView
                    PasteInterceptor.shared.onFormat = onFormat
                    
                    // Create toolbar
                    let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
                    var toolbarItems: [UIBarButtonItem] = []

                    // Store the formatting callback
                    editor.textView.onFormat = onFormat

                    // Create a custom divider view
                    func createDivider() -> UIBarButtonItem {
                        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 17, height: 24))
                        let dividerView = UIView(frame: CGRect(x: 8, y: 0, width: 1, height: 24))
                        dividerView.backgroundColor = .separator
                        containerView.addSubview(dividerView)
                        return UIBarButtonItem(customView: containerView)
                    }

                    // Define groups of formatting options
                    let textGroup = [MarkdownFormatting.heading, .bold, .italic, .strikethrough]
                    let linkGroup = [MarkdownFormatting.link, .image]
                    let codeGroup = [MarkdownFormatting.code, .codeBlock]

                    // Add text formatting group
                    for format in textGroup {
                        let formatButton = UIBarButtonItem(
                            image: UIImage(systemName: format.icon),
                            style: .plain,
                            target: editor.textView,
                            action: #selector(UITextView.handleMarkdownFormatting(_:))
                        )
                        formatButton.accessibilityIdentifier = format.id
                        toolbarItems.append(formatButton)
                    }

                    // Add first divider
                    toolbarItems.append(createDivider())

                    // Add link group
                    for format in linkGroup {
                        let formatButton = UIBarButtonItem(
                            image: UIImage(systemName: format.icon),
                            style: .plain,
                            target: editor.textView,
                            action: #selector(UITextView.handleMarkdownFormatting(_:))
                        )
                        formatButton.accessibilityIdentifier = format.id
                        toolbarItems.append(formatButton)
                    }

                    // Add second divider
                    toolbarItems.append(createDivider())

                    // Add code group
                    for format in codeGroup {
                        let formatButton = UIBarButtonItem(
                            image: UIImage(systemName: format.icon),
                            style: .plain,
                            target: editor.textView,
                            action: #selector(UITextView.handleMarkdownFormatting(_:))
                        )
                        formatButton.accessibilityIdentifier = format.id
                        toolbarItems.append(formatButton)
                    }

                    // Add final flexible space and keyboard dismiss button
                    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                    toolbarItems.append(flexSpace)

                    let focusButton = UIBarButtonItem(
                        image: UIImage(systemName: "keyboard.chevron.compact.down"),
                        style: .plain,
                        target: editor.textView,
                        action: #selector(UITextView.resignFirstResponder)
                    )
                    toolbarItems.append(focusButton)

                    toolbar.items = toolbarItems
                    toolbar.sizeToFit()

                    editor.textView.inputAccessoryView = toolbar
                    
                    if let range = textView?.selectedTextRange {
                        selectedText = textView?.text(in: range) ?? ""
                    }
                }
            }
    }
}

private var formatKey: UInt8 = 0

extension UITextView {
    // Add property to store the formatting callback
    var onFormat: ((MarkdownFormatting) -> Void)? {
        get {
            objc_getAssociatedObject(self, &formatKey) as? ((MarkdownFormatting) -> Void)
        }
        set {
            objc_setAssociatedObject(self, &formatKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    @objc func handleMarkdownFormatting(_ sender: UIBarButtonItem) {
        guard let formatId = sender.accessibilityIdentifier,
              let format = MarkdownFormatting.allCases.first(where: { $0.id == formatId }) else {
            return
        }
        
        onFormat?(format)
    }
}

class PasteInterceptor: NSObject, UITextViewDelegate {
    static let shared = PasteInterceptor()
    weak var textView: UITextView?
    var onFormat: ((MarkdownFormatting) -> Void)?
    
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
                    if textView.shouldChangeText(in: range, replacementString: formattedText) {
                        textView.replace(range, withText: formattedText)
                        textView.didChangeText()
                        return false
                    }
                }
            }
        }
        return true
    }
}
#endif
