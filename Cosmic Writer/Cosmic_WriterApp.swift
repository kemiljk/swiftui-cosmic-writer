//
//  Cosmic_WriterApp.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI

@main
struct Cosmic_WriterApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Cosmic_WriterDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
