//
//  OpenAIViewModel.swift
//  Cosmic Writer
//
//  Created by Karl on 18/06/2023.
//

import OpenAISwift
import SwiftUI

final class OpenAIViewModel: ObservableObject {
    @ObservedObject var APIKey = APIViewModel()
    private var openAPI: OpenAISwift?
    @Published var isLoading: Bool = false
    @Published var error: Bool = false

    func setup() {
        openAPI = OpenAISwift(authToken: APIKey.SavedAPIKey)
    }
    
    func updateKey() {
        openAPI = OpenAISwift(authToken: APIKey.SavedAPIKey)
    }
    
    func send(system: String, text: String, maxTokens: Int, completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        openAPI?.sendChat(with: [ChatMessage(role: .system, content: system), ChatMessage(role: .user, content: text)], model: .chat(.chatgpt0301), maxTokens: maxTokens, completionHandler: { result in
            switch result {
            case .success(let model):
                let output = model.choices?.first?.message.content ?? nil
                completion(output ?? "")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            case .failure(let error):
                print(error)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = true
                }
            }
        })
    }
}
    

