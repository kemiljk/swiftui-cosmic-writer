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
        .commands {
            CommandGroup(after: .textFormatting) {
                Divider()
                
                Button("Italic") {
                    NotificationCenter.default.post(name: .applyItalic, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Button("Bold") {
                    NotificationCenter.default.post(name: .applyBold, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button("Strikethrough") {
                    NotificationCenter.default.post(name: .applyStrikethrough, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Link") {
                    NotificationCenter.default.post(name: .applyLink, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button("Open Settings") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Button("View Preview") {
                    NotificationCenter.default.post(name: .showPreview, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let applyItalic = Notification.Name("applyItalic")
    static let applyBold = Notification.Name("applyBold")
    static let applyStrikethrough = Notification.Name("applyStrikethrough")
    static let applyLink = Notification.Name("applyLink")
    static let openSettings = Notification.Name("openSettings")
    static let showPreview = Notification.Name("showPreview")
}
