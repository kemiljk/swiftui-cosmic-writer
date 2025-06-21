//
//  Cosmic_WriterApp.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI
import SwiftData

@main
struct Cosmic_WriterApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: ShelfImage.self)
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        DocumentGroup(newDocument: Cosmic_WriterDocument()) { file in
            ContentView(document: file.$document)
                .modelContainer(container)
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
    static let applyHeading = Notification.Name("applyHeading")
    static let applyCode = Notification.Name("applyCode")
    static let applyCodeBlock = Notification.Name("applyCodeBlock")
    static let applyImage = Notification.Name("applyImage")
    static let openSettings = Notification.Name("openSettings")
    static let showPreview = Notification.Name("showPreview")
    static let uploadImage = Notification.Name("uploadImage")
}
