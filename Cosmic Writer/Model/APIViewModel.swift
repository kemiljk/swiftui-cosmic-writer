//
//  APIViewModel.swift
//  Cosmic Writer
//
//  Created by Personal on 18/06/2023.
//

import SwiftUI
import CoreData

final class APIViewModel: ObservableObject {
    @AppStorage("savedAPIKey") var SavedAPIKey: String = "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"
    @AppStorage("savedAssistantType") var AssistantType: String = "Act as a helpful AI assistant\n\n- Read everything carefully and make sure you answer the question correctly\n- Reply with helpful detail and even provide links to useful information if you can"
    
    init() {
        self.SavedAPIKey = SavedAPIKey
        self.AssistantType = AssistantType
    }
}
