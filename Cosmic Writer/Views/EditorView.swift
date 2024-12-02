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
                    
                    // Create toolbar
                    let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
                    var toolbarItems: [UIBarButtonItem] = []
                    
                    // Store the formatting callback
                    editor.textView.onFormat = onFormat
                    
                    // Add formatting buttons
                    for format in MarkdownFormatting.allCases {
                        let formatButton = UIBarButtonItem(
                            image: UIImage(systemName: format.icon),
                            style: .plain,
                            target: editor.textView,
                            action: #selector(UITextView.handleMarkdownFormatting(_:))
                        )
                        
                        formatButton.accessibilityIdentifier = format.id
                        
                        toolbarItems.append(formatButton)
                    }
                    
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
#endif
