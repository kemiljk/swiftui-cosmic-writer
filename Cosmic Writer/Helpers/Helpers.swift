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
    case heading, image, link, italic, bold, code, codeBlock, strikethrough
    
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
        }
    }
}
