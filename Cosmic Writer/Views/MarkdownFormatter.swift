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
            
            let formattedText: String
            switch format {
            case .heading:
                formattedText = "# \(selectedText)"
            case .image:
                formattedText = "![\(selectedText)]()"
            case .link:
                formattedText = "[\(selectedText)]()"
            case .italic:
                formattedText = "_\(selectedText)_"
            case .bold:
                formattedText = "**\(selectedText)**"
            case .code:
                formattedText = "`\(selectedText)`"
            case .codeBlock:
                formattedText = "```\n\(selectedText)\n```"
            case .strikethrough:
                formattedText = "~~\(selectedText)~~"
            }
            
            document.text.replaceSubrange(swiftRange, with: formattedText)
            textView.selectedTextRange = nil
            completion(cursorPosition)
        } else {
            let insertion: String
            let cursorOffset: Int
            
            switch format {
            case .heading:
                insertion = "# "
                cursorOffset = 2
            case .image:
                insertion = "![]()"
                cursorOffset = 2
            case .link:
                insertion = "[]()"
                cursorOffset = 1
            case .italic:
                insertion = "__"
                cursorOffset = 1
            case .bold:
                insertion = "****"
                cursorOffset = 2
            case .code:
                insertion = "``"
                cursorOffset = 1
            case .codeBlock:
                insertion = "```\n\n```"
                cursorOffset = 4
            case .strikethrough:
                insertion = "~~"
                cursorOffset = 1
            }
            
            document.text.insert(contentsOf: insertion, at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
            completion(min(cursorPosition + cursorOffset, document.text.utf16.count))
        }
    }
}
#endif
