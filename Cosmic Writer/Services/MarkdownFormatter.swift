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
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        let fullText = textView.text ?? ""
        let textLength = fullText.count
        
        // Ensure range is within bounds
        let safeRange = NSRange(
            location: min(selectedRange.location, textLength),
            length: min(selectedRange.length, max(0, textLength - selectedRange.location))
        )
        
        if safeRange.length > 0 && safeRange.location + safeRange.length <= textLength {
            // There is selected text
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
                formattedText = selectedText.hasPrefix("```\n") && selectedText.hasSuffix("\n```") ?
                    String(selectedText.dropFirst(4).dropLast(4)) :
                    "```\n\(selectedText)\n```"
            case .image:
                formattedText = "![](\(selectedText))"
            case .link:
                formattedText = "[\(selectedText)]()"
            case .strikethrough:
                formattedText = selectedText.hasPrefix("~~") && selectedText.hasSuffix("~~") ?
                    String(selectedText.dropFirst(2).dropLast(2)) :
                    "~~\(selectedText)~~"
            default:
                return
            }
            
            // Update the text view and document
            if let textRange = textView.selectedTextRange {
                textView.replace(textRange, withText: formattedText)
                document.text = textView.text
                
                // Update cursor position with bounds checking
                let newPosition = min(safeRange.location + formattedText.count, (textView.text ?? "").count)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
                
                completion(newPosition)
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
            case .strikethrough:
                insertion = "~~~~"
                cursorOffset = 2
            default:
                return
            }
            
            // Update the text view and document
            if let textRange = textView.selectedTextRange {
                textView.replace(textRange, withText: insertion)
                document.text = textView.text
                
                // Update cursor position with bounds checking
                let newPosition = min(safeRange.location + cursorOffset, (textView.text ?? "").count)
                if let position = textView.position(from: textView.beginningOfDocument, offset: newPosition) {
                    textView.selectedTextRange = textView.textRange(from: position, to: position)
                }
                
                completion(newPosition)
            }
        }
    }
}
#endif
