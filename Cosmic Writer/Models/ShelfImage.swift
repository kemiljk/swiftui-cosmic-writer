import Foundation
import SwiftData

@Model
final class ShelfImage {
    var localURL: URL
    var cosmicURL: String
    var documentID: String // To associate images with specific documents
    var createdAt: Date
    
    init(localURL: URL, cosmicURL: String, documentID: String) {
        self.localURL = localURL
        self.cosmicURL = cosmicURL
        self.documentID = documentID
        self.createdAt = Date()
    }
} 