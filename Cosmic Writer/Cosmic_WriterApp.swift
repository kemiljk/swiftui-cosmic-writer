//
//  Cosmic_WriterApp.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI

@main
struct Cosmic_WriterApp: App {
    @StateObject var aPIViewModel: APIViewModel = APIViewModel()
//    let persistenceController = PersistenceController.shared

    var body: some Scene {
        DocumentGroup(newDocument: Cosmic_WriterDocument()) { file in
            ContentView(document: file.$document)
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(aPIViewModel)
        }
    }
}
