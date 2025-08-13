import Foundation
import SwiftData
import CosmicSDK
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@Model
final class ShelfImage {
    var id: UUID
    var fileName: String
    var cosmicURL: String
    var localURL: URL
    var documentID: String
    var thumbnailData: Data?
    
    init(localURL: URL, cosmicURL: String, documentID: String) {
        self.id = UUID()
        self.fileName = localURL.lastPathComponent
        self.cosmicURL = cosmicURL
        self.localURL = localURL
        self.documentID = documentID
        
        #if os(iOS)
        if let image = UIImage(contentsOfFile: localURL.path) {
            self.thumbnailData = image.jpegData(compressionQuality: 0.7)
        }
        #else
        if let image = NSImage(contentsOf: localURL) {
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage!)
            self.thumbnailData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        }
        #endif
    }
    
    #if os(iOS)
    var thumbnail: UIImage {
        if let data = thumbnailData {
            return UIImage(data: data) ?? UIImage(systemName: "photo")!
        }
        return UIImage(systemName: "photo")!
    }
    #else
    var thumbnail: NSImage {
        if let data = thumbnailData {
            return NSImage(data: data) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
        }
        return NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
    }
    #endif
}

// Add this new struct for posts
struct Post: Identifiable, Codable {
    let id: String
    let title: String
    let slug: String
    let lastUsed: Date?
    
    init(id: String, title: String, slug: String, lastUsed: Date? = nil) {
        self.id = id
        self.title = title
        self.slug = slug
        self.lastUsed = lastUsed
    }
} 
