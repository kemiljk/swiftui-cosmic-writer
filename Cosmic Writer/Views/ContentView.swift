import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import HighlightedTextEditor
import MarkdownUI
import CosmicSDK
import SwiftData
import FoundationModels

// Post cache for persistence and recently used posts
class PostCache: ObservableObject {
    @Published var posts: [Post] = []
    @Published var recentlyUsed: [Post] = []
    
    private let userDefaults = UserDefaults.standard
    private let recentlyUsedKey = "recentlyUsedPosts"
    private let maxRecentlyUsed = 10
    
    init() {
        loadRecentlyUsed()
    }
    
    func addPost(_ post: Post) {
        // Update existing post or add new one
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        } else {
            posts.append(post)
        }
        
        // Mark as recently used
        markAsUsed(post)
    }
    
    func markAsUsed(_ post: Post) {
        // Create a new post with current timestamp
        let updatedPost = Post(id: post.id, title: post.title, slug: post.slug, lastUsed: Date())
        
        // Remove from recently used if already there
        recentlyUsed.removeAll { $0.id == post.id }
        
        // Add to front of recently used
        recentlyUsed.insert(updatedPost, at: 0)
        
        // Keep only the most recent posts
        if recentlyUsed.count > maxRecentlyUsed {
            recentlyUsed = Array(recentlyUsed.prefix(maxRecentlyUsed))
        }
        
        // Update the main posts array
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updatedPost
        }
        
        saveRecentlyUsed()
    }
    
    func getPostsWithRecentFirst() -> [Post] {
        // Combine recently used with all posts, removing duplicates
        var result = recentlyUsed
        let remainingPosts = posts.filter { post in
            !recentlyUsed.contains { $0.id == post.id }
        }
        result.append(contentsOf: remainingPosts)
        return result
    }
    
    private func loadRecentlyUsed() {
        if let data = userDefaults.data(forKey: recentlyUsedKey),
           let decoded = try? JSONDecoder().decode([Post].self, from: data) {
            recentlyUsed = decoded
        }
    }
    
    private func saveRecentlyUsed() {
        if let encoded = try? JSONEncoder().encode(recentlyUsed) {
            userDefaults.set(encoded, forKey: recentlyUsedKey)
        }
    }
}



// Add PostSuggestionOverlay view before ContentView
struct PostSuggestionOverlay: View {
    let posts: [Post]
    let searchText: String
    let onSelect: (Post) -> Void
    let onDismiss: () -> Void
    let onSearchTextChange: (String) -> Void
    let isKeyboardVisible: Bool
    @State private var selectedIndex: Int = 0
    @FocusState private var focused: Bool
    
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            // Show first 3 posts when no search text
            return Array(posts.prefix(3))
        } else {
            // Filter through ALL posts when searching, but only show first 3
            let filtered = posts.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.slug.localizedCaseInsensitiveContains(searchText)
            }
            print("Searching for '\(searchText)' - found \(filtered.count) posts out of \(posts.count) total, showing first 3")
            return Array(filtered.prefix(3))
        }
    }
    
    var body: some View {
        if !filteredPosts.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                // Hidden TextField that captures navigation keys and updates search
                TextField("", text: Binding(
                    get: { searchText },
                    set: { onSearchTextChange($0) }
                ))
                    .opacity(0)
                    .frame(width: 1, height: 1)
                    .focused($focused)
                    .onKeyPress(.upArrow) {
                        let newIndex = max(0, selectedIndex - 1)
                        selectedIndex = newIndex
                        print("Up arrow pressed, selectedIndex: \(selectedIndex)")
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        let newIndex = min(filteredPosts.count - 1, selectedIndex + 1)
                        selectedIndex = newIndex
                        print("Down arrow pressed, selectedIndex: \(selectedIndex)")
                        return .handled
                    }
                    .onKeyPress(.return) {
                        print("Return pressed, selectedIndex: \(selectedIndex), filteredPosts.count: \(filteredPosts.count)")
                        if selectedIndex < filteredPosts.count {
                            let selectedPost = filteredPosts[selectedIndex]
                            print("Selecting post: \(selectedPost.title)")
                            onSelect(selectedPost)
                            return .handled
                        }
                        return .ignored
                    }
                    .onKeyPress(.escape) {
                        onDismiss()
                        return .handled
                    }
                
                ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
                    Button {
                        onSelect(post)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(post.slug)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if post.lastUsed != nil {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            if index == selectedIndex {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(index == selectedIndex ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        selectedIndex = index
                        onSelect(post)
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: 300)
            .glassEffect(in: .rect(cornerRadius: 16))
            .shadow(radius: 8)
            .onAppear {
                selectedIndex = 0
                print("PostSuggestionOverlay appeared with \(filteredPosts.count) posts (searchText: '\(searchText)', total posts: \(posts.count))")
                // Set focus to the hidden TextField for keyboard navigation
                focused = true
            }
            .onChange(of: filteredPosts.count) { _, _ in
                // Reset selection when filtered results change
                selectedIndex = 0
                print("Filtered posts changed, resetting selectedIndex to 0")
            }
        }
    }
}

struct ContentView: View {
    @Binding var document: Cosmic_WriterDocument
    
    var body: some View {
#if os(iOS)
        iOSContentView(document: $document)
#elseif os(macOS)
        MacContentView(document: $document)
#endif
    }
}

// Shared DiffView for both platforms
struct DiffView: View {
    let originalText: String
    let proposedText: String
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with file names and debug info
                HStack {
                    VStack(alignment: .leading) {
                        Text("Original")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("\(originalText.count) chars")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Modified")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("\(proposedText.count) chars")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Debug info
                if originalText == proposedText {
                    Text("⚠️ No changes detected - texts are identical")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }
                
                // Side-by-side diff view
                HStack(spacing: 0) {
                    // Left side - Original
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            AttributedDiffText(
                                text: originalText,
                                isOriginal: true,
                                diffText: proposedText
                            )
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
                    
                    // Divider
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 1)
                    
                    // Right side - Modified
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            AttributedDiffText(
                                text: proposedText,
                                isOriginal: false,
                                diffText: originalText
                            )
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Action buttons
                HStack {
                    Button("Reject") { onReject() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Accept") { onAccept() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Review Changes")
        }
    }
}

struct AttributedDiffText: View {
    let text: String
    let isOriginal: Bool
    let diffText: String
    
    var body: some View {
        Text(createDiffAttributedString())
            .textSelection(.enabled)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func createDiffAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple and reliable word-level diff
        if text == diffText {
            return attributedString
        }
        
        // Split both texts into words
        let textWords = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let diffWords = diffText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Find the first difference
        var firstDiffIndex = 0
        let minLength = min(textWords.count, diffWords.count)
        
        for i in 0..<minLength {
            if textWords[i] != diffWords[i] {
                firstDiffIndex = i
                break
            }
            firstDiffIndex = i + 1
        }
        
        // If we found differences, highlight from the first difference onwards
        if firstDiffIndex < textWords.count {
            // Calculate the character position of the first difference
            var charIndex = 0
            var wordIndex = 0
            
            for word in textWords {
                if wordIndex >= firstDiffIndex {
                    // Highlight this word and all subsequent words
                    let wordRange = text.range(of: word, range: text.index(text.startIndex, offsetBy: charIndex)..<text.endIndex)
                    if let range = wordRange {
                        let attributedRange = AttributedString(text[range]).range(of: word)
                        if let attributedRange = attributedRange {
                            if isOriginal {
                                attributedString[attributedRange].foregroundColor = .red
                                attributedString[attributedRange].backgroundColor = .red.opacity(0.1)
                            } else {
                                attributedString[attributedRange].foregroundColor = .green
                                attributedString[attributedRange].backgroundColor = .green.opacity(0.1)
                            }
                        }
                    }
                }
                charIndex += word.count + 1 // +1 for the space/newline
                wordIndex += 1
            }
        }
        
        return attributedString
    }
}
