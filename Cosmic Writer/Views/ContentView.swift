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

struct ContentView: View {
    @Binding var document: Cosmic_WriterDocument
    
    var body: some View {
        #if os(iOS)
        iOSContentView(document: $document)
        #else
        MacContentView(document: $document)
        #endif
    }
}

#if os(iOS)
@MainActor
struct iOSContentView: View {
    @Binding var document: Cosmic_WriterDocument
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @State private var openSettings: Bool = false
    @State private var openPreview: Bool = false
    @State private var tag = PostTag.design.rawValue
    @State private var focusMode: Bool = true
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var textView: UITextView? = nil
    @State private var isSending: Bool = false
    @State private var showToast: Bool = false
    @State private var toastOffset: CGFloat = 100
    @State private var isUploading: Bool = false
    @State private var toastMessage: String = ""
    
    let device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
    
    // Add these computed properties to both iOSContentView and MacContentView
    private var characterCount: Int {
        document.text.count
    }
    
    private var wordCount: Int {
        document.text.wordCount
    }
    
    private var readingTime: Int {
        document.text.estimatedReadingTime
    }
    
    private var statsText: String {
        "\(characterCount) characters • \(wordCount) words • \(readingTime) min read"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HSplitView {
                    // Editor pane
                    VStack(spacing: 0) {
                        EditorView(
                            document: $document,
                            cursorPosition: $cursorPosition,
                            selectionLength: $selectionLength,
                            selectedText: $selectedText,
                            textView: $textView,
                            onFormat: { format in
                                applyMarkdownFormatting(format)
                            }
                        )
                        .onDrop(of: [.image], delegate: ImageDropDelegate(view: self))
                        if !focusMode {
                            Divider()
                            PreviewView(document: document)
                        }
                    }
                    .background(.background)
                    .frame(minWidth: 400)
                    
                    // Preview pane
                    if !focusMode {
                        PreviewView(document: document)
                            .frame(minWidth: 400)
                            .padding()
                    }
                }
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up from bottom
                }
                
                // Automatically hide after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        toastOffset = 100 // Slide back down
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showToast = false
                    }
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // iPad toolbar
            if device == .pad {
                ToolbarItem(placement: .topBarLeading) {
                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Menu {
                            Button { tag = "design" } label: { Text("Design") }
                            Button { tag = "development" } label: { Text("Development") }
                            Button { tag = "opinion" } label: { Text("Opinion") }
                            Button { tag = "journal" } label: { Text("Journal") }
                        } label: {
                            Image(systemName: "tag")
                        }
                        
                        Button {
                            withAnimation {
                                focusMode.toggle()
                            }
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "eye")
                        }
                        
                        Button {
                            openSettings = true
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isSending {
                        ProgressView()
                            .frame(width: 24)
                    } else {
                        Button {
                            self.isSending = true
                            uploadPost()
                            modal.impactOccurred()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                    }
                }
            }
            
            // iPhone toolbar
            if device == .phone {
                ToolbarItem(placement: .topBarLeading) {
                    Text(statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu {
                            ForEach(PostTag.allCases, id: \.self) { postTag in
                                Button {
                                    tag = postTag.rawValue
                                } label: {
                                    Text(postTag.title)
                                }
                            }
                        } label: {
                            Label("Tag", systemImage: "tag")
                        }
                        
                        Divider()
                        
                        Button {
                            withAnimation {
                                openPreview.toggle()
                                modal.impactOccurred()
                            }
                        } label: {
                            Label("Preview", systemImage: "eye")
                        }
                        
                        Button {
                            openSettings = true
                            modal.impactOccurred()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        self.isSending = true
                        uploadPost()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                    }
                    .frame(width: 24, height: 24)
                }
            }
        }
        .background(Color("bg"))
        .sheet(isPresented: $openPreview) {
            PreviewView(document: document)
                .padding(.top, 24)
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
    
    func uploadPost() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.insertOne(type: "writings", title: document.title, metadata: [
            "tag": tag,
            "content": document.text,
        ], status: .draft) { results in
            Task { @MainActor in
                switch results {
                case .success(_):
                    self.toastMessage = "Post submitted"
                    self.showToast = true
                    self.isSending = false
                case .failure(let error):
                    self.toastMessage = "Failed to submit post"
                    self.showToast = true
                    print(error)
                }
            }
        }
    }
    
    func uploadImage(_ imageData: Data, fileName: String) {
        isUploading = true
        
        // Create a temporary file with the image data
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: tempFileURL)
            
            // Create Cosmic client
            let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
            
            cosmic.uploadMedia(fileURL: tempFileURL, metadata: ["write_key": WRITE_KEY]) { result in
                Task { @MainActor in
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    switch result {
                    case .success(let response):
                        if let imgixUrl = response.media?.imgix_url {
                            showToastMessage("Image uploaded successfully")
                            // Insert the image markdown at the current cursor position
                            insertImageMarkdown(fileName: fileName, url: imgixUrl)
                        } else {
                            showToastMessage("Invalid response from server")
                        }
                    case .failure(let error):
                        showToastMessage("Upload failed")
                        print("Failed to upload image: \(error)")
                    }
                    isUploading = false
                }
            }
        } catch {
            showToastMessage("Failed to process image")
            print("Failed to write image: \(error)")
            isUploading = false
        }
    }
    
    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
    
    func insertImageMarkdown(fileName: String, url: String) {
        guard let textView = textView else { return }
        
        let imageMarkdown = "![\(fileName)](\(url))"
        let selectedRange = textView.selectedRange
        
        if let textRange = textView.selectedTextRange ?? textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument) {
            textView.replace(textRange, withText: imageMarkdown)
            
            // Move cursor to the end of the inserted markdown
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: selectedRange.location + imageMarkdown.count) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }
    }
    
    func setCursorPosition(to position: Int) {
        DispatchQueue.main.async {
            guard let textView = self.textView else {
                print("TextView not found")
                return
            }
            #if os(iOS)
            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: position) {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
            #endif
        }
    }
    
    func applyMarkdownFormatting(_ format: MarkdownFormatting) {
        MarkdownFormatter.shared.applyMarkdownFormatting(
            format: format,
            document: &document,
            selectedText: selectedText,
            cursorPosition: cursorPosition,
            textView: textView
        ) { newPosition in
            cursorPosition = newPosition
            setCursorPosition(to: newPosition)
        }
    }
}

struct ImageDropDelegate: DropDelegate {
    let view: iOSContentView
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.image]).first else { return false }
        
        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            if let image = object as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                Task { @MainActor in
                    view.uploadImage(imageData, fileName: fileName)
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when dragging over
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }
}
#endif

#if os(macOS)
// Add ImageShelf component before MacContentView
struct ImageShelf: View {
    let onImageDropped: (URL) -> Void
    let onImageClick: (String, String) -> Void
    let onDelete: (ShelfImage) -> Void
    let droppedImages: [ShelfImage]
    let isUploading: Bool
    let errorMessage: String?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(droppedImages) { image in
                        AsyncImage(url: URL(string: "\(image.cosmicURL)?w=120&h=120&fit=crop&auto=format,compress")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(image)
                            } label: {
                                Label("Remove from Shelf", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            let optimizedUrl = "\(image.cosmicURL)?auto=format,compress"
                            onImageClick(image.localURL.lastPathComponent, optimizedUrl)
                        }
                    }
                    
                    // Drop zone
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        
                        if isUploading {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 2)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .onTapGesture {
                        #if os(iOS)
                        showImagePicker = true
                        #else
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [.image]
                        
                        panel.begin { response in
                            if response == .OK, let url = panel.url {
                                Task { @MainActor in
                                    onImageDropped(url)
                                }
                            }
                        }
                        #endif
                    }
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        
                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                            guard let url = url, error == nil else { return }
                            
                            #if os(macOS)
                            // Verify it's an image and check size
                            guard let image = NSImage(contentsOf: url) else { return }
                            
                            // Check file size (limit to 5MB)
                            let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
                            let fileSize = resources?.fileSize ?? 0
                            if fileSize > 5_000_000 {
                                Task { @MainActor in
                                    print("Image too large (max 5MB)")
                                }
                                return
                            }
                            #endif
                            
                            Task { @MainActor in
                                onImageDropped(url)
                            }
                        }
                        return true
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Text("Drop images here or click to insert (max 5MB)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        #if os(iOS)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { url in
                onImageDropped(url)
            }
        }
        #endif
    }
}

#if os(iOS)
struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let imageURL = info[.imageURL] as? URL {
                parent.onImagePicked(imageURL)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

@MainActor
struct MacContentView: View {
    @Binding var document: Cosmic_WriterDocument
    @Environment(\.modelContext) private var modelContext
    @Query private var shelfImages: [ShelfImage]
    
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @State private var openSettings: Bool = false
    @State private var tag = PostTag.design.rawValue
    @State private var focusMode: Bool = true
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var selectedText: String = ""
    @State private var textView: NSTextView? = nil
    @State private var observers: [NSObjectProtocol] = []
    @State private var isSending: Bool = false
    @State private var showToast: Bool = false
    @State private var toastOffset: CGFloat = 100
    @State private var isUploading: Bool = false
    @State private var imageError: String?
    @State private var toastMessage: String = ""
    
    // Filter images for current document
    private var documentImages: [ShelfImage] {
        shelfImages.filter { $0.documentID == document.filePath }
    }
    
    // Add these computed properties to both iOSContentView and MacContentView
    private var characterCount: Int {
        document.text.count
    }
    
    private var wordCount: Int {
        document.text.wordCount
    }
    
    private var readingTime: Int {
        document.text.estimatedReadingTime
    }
    
    private var statsText: String {
        "\(characterCount) characters • \(wordCount) words • \(readingTime) min read"
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HSplitView {
                    // Editor pane
                    VStack(spacing: 0) {
                        HighlightedTextEditor(text: $document.text, highlightRules: .markdown)
                            .onSelectionChange { (range: NSRange) in
                                cursorPosition = range.location
                                selectionLength = range.length
                            }
                            .introspect { editor in
                                DispatchQueue.main.async {
                                    textView = editor.textView
                                    textView?.isAutomaticQuoteSubstitutionEnabled = true
                                    textView?.isAutomaticDashSubstitutionEnabled = true
                                    textView?.isAutomaticTextReplacementEnabled = true
                                    textView?.isAutomaticSpellingCorrectionEnabled = true
                                    
                                    if let selectedRange = textView?.selectedRange() {
                                        selectedText = textView?.string.substring(with: selectedRange) ?? ""
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Add ImageShelf
                        ImageShelf(
                            onImageDropped: { url in
                                uploadImage(url)
                            },
                            onImageClick: { fileName, cosmicUrl in
                                insertImageMarkdown(fileName: fileName, url: cosmicUrl)
                            },
                            onDelete: { image in
                                modelContext.delete(image)
                                try? modelContext.save()
                            },
                            droppedImages: documentImages,
                            isUploading: isUploading,
                            errorMessage: imageError
                        )
                    }
                    .background(.background)
                    .frame(minWidth: 400)
                    
                    // Preview pane
                    if !focusMode {
                        PreviewView(document: document)
                            .frame(minWidth: 400)
                            .padding()
                    }
                }
            }
            
            if showToast {
                ToastView(message: toastMessage)
                    .offset(y: toastOffset)
                    .animation(.spring(response: 0.3), value: toastOffset)
            }
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                withAnimation {
                    toastOffset = -32 // Slide up from bottom
                }
                
                // Automatically hide after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        toastOffset = 100 // Slide back down
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showToast = false
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text(statsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(PostTag.allCases, id: \.self) { postTag in
                        Button {
                            tag = postTag.rawValue
                        } label: {
                            Text(postTag.title)
                        }
                    }
                } label: {
                    Text(tag.capitalized)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        focusMode.toggle()
                    }
                } label: {
                    Image(systemName: "eye")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.isSending = true
                    uploadPost()
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(width: 24, height: 24)
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
        .navigationTitle(document.title)
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .frame(width: 400, height: 300)
        }
    }
    
    func insertImageMarkdown(fileName: String, url: String) {
        guard let textView = textView else { return }
        
        let imageMarkdown = "![\(fileName)](\(url))"
        let selectedRange = textView.selectedRange()
        
        textView.shouldChangeText(in: selectedRange, replacementString: imageMarkdown)
        textView.replaceCharacters(in: selectedRange, with: imageMarkdown)
        textView.didChangeText()
        
        // Move cursor after the image
        let newPosition = selectedRange.location + imageMarkdown.count
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        
        // Update the document text
        document.text = textView.string
    }
    
    func uploadImage(_ imageURL: URL) {
        isUploading = true
        
        // Create Cosmic client
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        // Load and compress image if needed
        guard let image = NSImage(contentsOf: imageURL) else {
            showToastMessage("Invalid image")
            return
        }
        
        // Convert NSImage to compressed JPEG Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            showToastMessage("Failed to process image")
            return
        }
        
        // Check if compressed size is still too large (2MB limit)
        if compressedData.count > 2_000_000 {
            showToastMessage("Image too large (max 2MB)")
            return
        }
        
        // Create a temporary file with the compressed data
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("compressed_\(imageURL.lastPathComponent)")
        
        do {
            try compressedData.write(to: tempFileURL)
            
            // Upload compressed image
            print("Starting media upload with bucket:", BUCKET)
            print("File URL:", tempFileURL)
            print("Write key:", WRITE_KEY)
            
            cosmic.uploadMedia(fileURL: tempFileURL, metadata: ["write_key": WRITE_KEY]) { result in
                Task { @MainActor in
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    switch result {
                    case .success(let response):
                        print("Upload response received:", response)
                        if let imgixUrl = response.media?.imgix_url {
                            print("Media URL:", imgixUrl)
                            // Create and save ShelfImage
                            let shelfImage = ShelfImage(
                                localURL: imageURL,
                                cosmicURL: imgixUrl,
                                documentID: document.filePath
                            )
                            modelContext.insert(shelfImage)
                            try? modelContext.save()
                            showToastMessage("Image uploaded successfully")
                        } else {
                            showToastMessage("Invalid response from server")
                            print("Media response missing URL:", response)
                            print("Response message:", response.message ?? "No message")
                        }
                    case .failure(let error):
                        showToastMessage("Upload failed")
                        print("Failed to upload image: \(error)")
                    }
                    isUploading = false
                }
            }
        } catch {
            showToastMessage("Failed to process image")
            print("Failed to write compressed image: \(error)")
        }
    }
    
    func uploadPost() {
        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: BUCKET, readKey: READ_KEY, writeKey: WRITE_KEY))
        
        cosmic.insertOne(type: "writings", title: document.title, metadata: [
            "tag": tag,
            "content": document.text,
        ], status: .draft) { results in
            Task { @MainActor in
                switch results {
                case .success(_):
                    self.showToast = true
                    self.isSending = false
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Create a reference to self that can be captured
        let view = self
        
        // Store observers so we can remove them later
        observers = [
            NotificationCenter.default.addObserver(
                forName: .applyItalic,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.italic)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyBold,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.bold)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyStrikethrough,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.applyMarkdownFormatting(.strikethrough)
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .applyLink,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    view.handleLinkFormatting()
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .openSettings,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    openSettings = true
                }
            },
            
            NotificationCenter.default.addObserver(
                forName: .showPreview,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    focusMode.toggle()
                }
            }
        ]
    }
    
    func showError(_ message: String) {
        imageError = message
        isUploading = false
        // Clear error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            imageError = nil
        }
    }
    
    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
}

extension String {
    func substring(with nsrange: NSRange) -> String? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
}

// Add back the extension with formatting methods
extension MacContentView {
    func applyMarkdownFormatting(_ format: MarkdownFormatting) {
        guard let textView = textView else {
            return
        }
        
        let selectedRange = textView.selectedRange()
        
        if selectedRange.length > 0 {
            // There is selected text
            guard let selectedContent = textView.string.substring(with: selectedRange) else {
                return
            }
            
            let formattedText: String
            switch format {
            case .italic:
                if selectedContent.hasPrefix("_") && selectedContent.hasSuffix("_") {
                    // Remove italic formatting
                    formattedText = String(selectedContent.dropFirst().dropLast())
                } else {
                    formattedText = "_\(selectedContent)_"
                }
            case .bold:
                if selectedContent.hasPrefix("**") && selectedContent.hasSuffix("**") {
                    // Remove bold formatting
                    formattedText = String(selectedContent.dropFirst(2).dropLast(2))
                } else {
                    formattedText = "**\(selectedContent)**"
                }
            case .strikethrough:
                if selectedContent.hasPrefix("~~") && selectedContent.hasSuffix("~~") {
                    // Remove strikethrough formatting
                    formattedText = String(selectedContent.dropFirst(2).dropLast(2))
                } else {
                    formattedText = "~~\(selectedContent)~~"
                }
            default:
                return
            }
            
            textView.replaceCharacters(in: selectedRange, with: formattedText)
            document.text = textView.string
            
            // Update selection to cover new text
            let newLength = formattedText.count
            textView.setSelectedRange(NSRange(location: selectedRange.location, length: newLength))
        } else {
            // No selection, insert at cursor
            let insertion: String
            let cursorOffset: Int
            
            switch format {
            case .italic:
                insertion = "__"
                cursorOffset = 1
            case .bold:
                insertion = "****"
                cursorOffset = 2
            case .strikethrough:
                insertion = "~~~~"
                cursorOffset = 2
            default:
                return
            }
            
            let insertionRange = NSRange(location: selectedRange.location, length: 0)
            textView.shouldChangeText(in: insertionRange, replacementString: insertion)
            textView.replaceCharacters(in: insertionRange, with: insertion)
            textView.didChangeText()
            
            // Update cursor position
            let newPosition = selectedRange.location + cursorOffset
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        }
    }
    
    func handleLinkFormatting() {
        guard let textView = textView else { return }
        
        // Check clipboard for URL
        let pasteboard = NSPasteboard.general
        var clipboardUrl: String? = nil
        
        // Try to get URL from clipboard
        if let clipboardString = pasteboard.string(forType: .string) {
            // Basic URL validation
            if clipboardString.hasPrefix("http://") ||
               clipboardString.hasPrefix("https://") ||
               clipboardString.hasPrefix("www.") {
                clipboardUrl = clipboardString
            }
        }
        
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            // There is selected text
            if let selectedContent = textView.string.substring(with: selectedRange) {
                // Store selected text for potential later use
                let tempSelected = selectedContent
                
                let formattedText: String
                if let url = clipboardUrl {
                    formattedText = "[\(selectedContent)](\(url))"
                } else {
                    // No URL in clipboard, save selected text and leave parentheses empty
                    pasteboard.clearContents()
                    pasteboard.setString(selectedContent, forType: .string)
                    formattedText = "[\(selectedContent)]()"
                }
                
                textView.shouldChangeText(in: selectedRange, replacementString: formattedText)
                textView.replaceCharacters(in: selectedRange, with: formattedText)
                textView.didChangeText()
                
                // Position cursor appropriately
                let newPosition: Int
                if clipboardUrl != nil {
                    // Place cursor at end if we inserted a URL
                    newPosition = selectedRange.location + formattedText.count
                } else {
                    // Place cursor between parentheses if no URL
                    newPosition = selectedRange.location + tempSelected.count + 3
                }
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
                
                // Update the document text
                document.text = textView.string
            }
        } else {
            // No selection, insert empty link
            let insertion: String
            if let url = clipboardUrl {
                insertion = "[]("+url+")"
            } else {
                insertion = "[]()"
            }
            let insertionRange = NSRange(location: selectedRange.location, length: 0)
            
            textView.shouldChangeText(in: insertionRange, replacementString: insertion)
            textView.replaceCharacters(in: insertionRange, with: insertion)
            textView.didChangeText()
            
            // Position cursor between brackets if no URL, or at end if URL was inserted
            let newPosition = selectedRange.location + (clipboardUrl == nil ? 1 : insertion.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            
            // Update the document text
            document.text = textView.string
        }
    }
}

#endif


