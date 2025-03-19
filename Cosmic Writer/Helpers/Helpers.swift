//
//  Helpers.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 02/12/2024.
//

import SwiftUI

enum PostTag: String, CaseIterable {
    case design = "design"
    case development = "development"
    case opinion = "opinion"
    case journal = "journal"
    case designEngineering = "design engineering"
    case product = "product"
    
    var title: String {
        switch self {
        case .designEngineering:
            return "Design Engineering"
        default:
            return rawValue.capitalized
        }
    }
}


enum MarkdownFormatting: CaseIterable, Identifiable {
    case heading, image, link, italic, bold, code, codeBlock, strikethrough, table, taskList, blockquote, horizontalRule
    
    var id: String { title }
    
    var title: String {
        switch self {
        case .heading: return "Heading"
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .strikethrough: return "Strikethrough"
        case .link: return "Link"
        case .image: return "Image"
        case .code: return "Code"
        case .codeBlock: return "Code Block"
        case .table: return "Table"
        case .taskList: return "Task List"
        case .blockquote: return "Blockquote"
        case .horizontalRule: return "Horizontal Rule"
        }
    }
    
    var icon: String {
        switch self {
        case .heading: return "number"
        case .bold: return "bold"
        case .italic: return "italic"
        case .strikethrough: return "strikethrough"
        case .link: return "link"
        case .image: return "photo"
        case .code: return "terminal"
        case .codeBlock: return "curlybraces.square"
        case .table: return "tablecells"
        case .taskList: return "checklist"
        case .blockquote: return "text.quote"
        case .horizontalRule: return "minus"
        }
    }
}

extension String {
    var wordCount: Int {
        let words = self.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    var estimatedReadingTime: Int {
        // Average reading speed is 200-250 words per minute
        let wordsPerMinute = 225
        let minutes = Double(wordCount) / Double(wordsPerMinute)
        return Int(ceil(minutes))
    }
}
