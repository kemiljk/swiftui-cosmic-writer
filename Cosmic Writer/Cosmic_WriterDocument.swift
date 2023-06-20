//
//  Cosmic_WriterDocument.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI
import UniformTypeIdentifiers

struct Cosmic_WriterDocument: FileDocument {
    var text: String
    var title: String
    var filePath: String

    init(text: String = "", title: String = "", filePath: String = "") {
        self.text = text
        self.title = title
        self.filePath = filePath
    }

    static var readableContentTypes: [UTType] = [UTType.plainText]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let titleData = configuration.file.filename
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let regex = /\.txt/
        title = titleData.replacing(regex, with: "")
        text = string
        filePath = titleData
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
