//
//  MarkdownFormatter.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 02/12/2024.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
class MarkdownFormatter {
    static let shared = MarkdownFormatter()
    
    func applyMarkdownFormatting(
        format: MarkdownFormatting,
        document: inout Cosmic_WriterDocument,
        selectedText: String,
        cursorPosition: Int,
        textView: UITextView?,
        completion: @escaping (Int) -> Void
    ) {
        if !selectedText.isEmpty {
            guard let textView = textView,
                  let range = textView.selectedTextRange else { return }
            
            let startLocation = textView.offset(from: textView.beginningOfDocument, to: range.start)
            let endLocation = textView.offset(from: textView.beginningOfDocument, to: range.end)
            
            let start = document.text.index(document.text.startIndex, offsetBy: startLocation)
            let end = document.text.index(document.text.startIndex, offsetBy: endLocation)
            let swiftRange = start..<end
            
            // Check clipboard for URL if needed
            var clipboardUrl: String? = nil
            if format == .link || format == .image {
                if let clipboardString = UIPasteboard.general.string {
                    if clipboardString.hasPrefix("http://") ||
                       clipboardString.hasPrefix("https://") ||
                       clipboardString.hasPrefix("www.") {
                        clipboardUrl = clipboardString
                    }
                }
            }
            
            let formattedText: String
            var newCursorPosition = cursorPosition
            
            switch format {
            case .heading:
                formattedText = "# \(selectedText)"
                newCursorPosition = startLocation + formattedText.count
            case .image:
                if let url = clipboardUrl {
                    formattedText = "![\(selectedText)](\(url))"
                    newCursorPosition = startLocation + formattedText.count
                } else {
                    formattedText = "![\(selectedText)]()"
                    newCursorPosition = startLocation + selectedText.count + 4
                    UIPasteboard.general.string = selectedText
                }
            case .link:
                if let url = clipboardUrl {
                    formattedText = "[\(selectedText)](\(url))"
                    newCursorPosition = startLocation + formattedText.count
                } else {
                    formattedText = "[\(selectedText)]()"
                    newCursorPosition = startLocation + selectedText.count + 3
                    UIPasteboard.general.string = selectedText
                }
            case .italic:
                if selectedText.hasPrefix("_") && selectedText.hasSuffix("_") {
                    formattedText = String(selectedText.dropFirst().dropLast())
                    newCursorPosition = startLocation + formattedText.count
                } else {
                    formattedText = "_\(selectedText)_"
                    newCursorPosition = startLocation + formattedText.count
                }
            case .bold:
                if selectedText.hasPrefix("**") && selectedText.hasSuffix("**") {
                    formattedText = String(selectedText.dropFirst(2).dropLast(2))
                    newCursorPosition = startLocation + formattedText.count
                } else {
                    formattedText = "**\(selectedText)**"
                    newCursorPosition = startLocation + formattedText.count
                }
            case .code:
                formattedText = "`\(selectedText)`"
                newCursorPosition = startLocation + formattedText.count
            case .codeBlock:
                // Check if the selected text already has a language specified
                if selectedText.hasPrefix("```") {
                    let lines = selectedText.components(separatedBy: .newlines)
                    if lines.count >= 2 {
                        let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
                        let language = firstLine.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                        if !language.isEmpty {
                            formattedText = "```\(language)\n\(selectedText.dropFirst(firstLine.count + 1).trimmingCharacters(in: .whitespaces))\n```"
                        } else {
                            formattedText = "```\n\(selectedText.trimmingCharacters(in: .whitespaces))\n```"
                        }
                    } else {
                        formattedText = "```\n\(selectedText)\n```"
                    }
                } else {
                    formattedText = "```\n\(selectedText)\n```"
                }
                newCursorPosition = startLocation + formattedText.count
            case .strikethrough:
                if selectedText.hasPrefix("~~") && selectedText.hasSuffix("~~") {
                    formattedText = String(selectedText.dropFirst(2).dropLast(2))
                    newCursorPosition = startLocation + formattedText.count
                } else {
                    formattedText = "~~\(selectedText)~~"
                    newCursorPosition = startLocation + formattedText.count
                }
            case .table:
                // Create a 2x2 table with the selected text in the first cell
                let lines = selectedText.components(separatedBy: .newlines)
                let cellContent = lines.first ?? selectedText
                formattedText = """
                | Header 1 | Header 2 |
                |:--------|:---------|
                | \(cellContent) | Cell 2 |
                | Cell 3 | Cell 4 |
                """
                newCursorPosition = startLocation + formattedText.count
            case .taskList:
                // Convert each line to a task list item
                let lines = selectedText.components(separatedBy: .newlines)
                formattedText = lines.map { "- [ ] \($0)" }.joined(separator: "\n")
                newCursorPosition = startLocation + formattedText.count
            case .blockquote:
                // Convert each line to a blockquote
                let lines = selectedText.components(separatedBy: .newlines)
                formattedText = lines.map { "> \($0)" }.joined(separator: "\n")
                newCursorPosition = startLocation + formattedText.count
            case .horizontalRule:
                formattedText = "\n---\n"
                newCursorPosition = startLocation + formattedText.count
            }
            
            document.text.replaceSubrange(swiftRange, with: formattedText)
            
            // Update selection to cover new text
            if let newStart = textView.position(from: textView.beginningOfDocument, offset: startLocation),
               let newEnd = textView.position(from: textView.beginningOfDocument, offset: startLocation + formattedText.count),
               let newRange = textView.textRange(from: newStart, to: newEnd) {
                textView.selectedTextRange = newRange
            }
            
            completion(newCursorPosition)
        } else {
            // Rest of the code for no selection case remains the same
            // ... existing code ...
        }
    }
}
#endif
