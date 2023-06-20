//
//  ContentView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI
import UIKit
import HighlightedTextEditor
import MarkdownUI

struct ContentView: View {
    @ObservedObject var aPIViewModel = APIViewModel()
    @ObservedObject var viewModel = OpenAIViewModel()
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @Binding var document: Cosmic_WriterDocument
    @State private var openSettings: Bool = false
    @State private var openPreview: Bool = false
    @State private var addTag: Bool = false
    @State private var snippet = ""
    @State private var tag = "design"
    @State private var editTitle: Bool = false
    @State private var title: String = ""
    @State private var focusMode: Bool = true
    @State private var submitSuccessful: Bool = false
    @State private var cursorPosition: Int = 0
    @State private var selectionLength: Int = 0
    @State private var promptText: String = ""
    @State private var result: String = ""
    @State private var selection: UITextRange?
    @State private var selectedText: String = ""
    @State private var fullPrompt: String = ""
    @State private var close: Bool = true
    @State private var newChat: Bool = false
    @FocusState private var textFieldIsFocused: Bool
    
#if os(iOS)
    var device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
#endif
    
    var body: some View {
        VStack(spacing: 0) {
            if device == .mac || device == .pad {
                ZStack(alignment: .bottomTrailing) {
                    HStack(spacing: 16) {
                        HighlightedTextEditor(text: $document.text, highlightRules: .markdown)
                            .onSelectionChange { (range: NSRange) in
                                self.cursorPosition = range.location
                                self.selectionLength = range.length
                            }
                            .introspect { editor in
                                editor.textView.backgroundColor = UIColor.init(named: "bg")
                                editor.textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                            }
                        .frame(maxWidth: .infinity)
                        if focusMode == false {
                            Rectangle()
                                .frame(maxWidth: 1, maxHeight: .infinity)
                                .foregroundColor(.secondary).opacity(0.1)
                            ScrollView {
                                Markdown {
                                    document.text
                                }
                                .markdownTextStyle(\.code) {
                                    FontFamilyVariant(.monospaced)
                                    ForegroundColor(.purple)
                                    BackgroundColor(.purple.opacity(0.25))
                                }
                                .padding(.top, 24)
                                .padding(.horizontal, 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    VStack(alignment: .leading) {
                        if viewModel.isLoading {
                            ThinkingView()
                                .padding([.top, .horizontal])
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }  else {
                ZStack(alignment: .bottom) {
                    HighlightedTextEditor(text: $document.text, highlightRules: .markdown)
                        .onSelectionChange { (range: NSRange) in
                            cursorPosition = range.location
                            selectionLength = range.length
                        }
                        .introspect { editor in
                            editor.textView.backgroundColor = UIColor.init(named: "bg")
                            editor.textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
                        }
                        .contextMenu {
                            Button {
                                replace()
                            } label: {
                                Text("Replace")
                            }
                            Button {
                                expand()
                            } label: {
                                Text("Expand")
                            }
                        }
                    VStack(alignment: .center) {
                        if viewModel.isLoading {
                            ThinkingView()
                                .padding([.top, .horizontal])
                        }
                    }
                }
            }
        }
        .navigationTitle($document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
#if os(iOS)
        .toolbar {
            if device == .mac {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 8) {
                        Button {
                            self.openSettings = true
                            self.modal.impactOccurred()
                        } label: {
                            Image(systemName: "gearshape")
                                .symbolVariant(.fill)
                        }
                        .tint(Color("grey-500"))
                        .buttonStyle(.borderless)
                        Button {
                            withAnimation {
                                self.focusMode.toggle()
                            }
                        } label: {
                            Image(systemName: "eye.fill")
                        }
                        .keyboardShortcut("f")
                        .tint(Color("grey-500"))
                        .buttonStyle(.borderless)
                        Spacer()
                        Button {
                            replace()
                        } label: {
                            Text("Replace")
                        }
                        .keyboardShortcut("§", modifiers: .command)
                        Button {
                            expand()
                        } label: {
                            Text("Expand")
                        }
                        .keyboardShortcut("§", modifiers: [.command, .shift])
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if device == .phone || device == .pad {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        self.openSettings = true
                        self.modal.impactOccurred()
                    } label: {
                        Image(systemName: "gearshape")
                            .symbolVariant(.fill)
                    }
                    .tint(Color("grey-500"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if device == .pad {
                        Button {
                            withAnimation {
                                self.focusMode.toggle()
                            }
                        } label: {
                            Image(systemName: "eye.fill")
                        }
                        .keyboardShortcut("f")
                        .tint(Color("grey-500"))
                    } else {
                        Button {
                            self.openPreview = true
                            self.modal.impactOccurred()
                        } label: {
                            Image(systemName: "eye.fill")
                        }
                        .tint(Color("grey-500"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            document.text.insert(contentsOf: "#", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Heading", systemImage: "number")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "![]()", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                            getAndSetCursorPosition(position: cursorPosition, length: selectionLength, characterLength: 5)
                        } label: {
                            Label("Image", systemImage: "photo")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "[]()", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Link", systemImage: "link")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "_", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Italic", systemImage: "italic")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "**", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Bold", systemImage: "bold")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "`", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Code", systemImage: "terminal")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        Button {
                            document.text.insert(contentsOf: "```", at: document.text.index(document.text.startIndex, offsetBy: cursorPosition))
                        } label: {
                            Label("Code Block", systemImage: "curlybraces.square")
                        }
                        .frame(width: 16, height: 16)
                        .font(.caption)
                        .padding(6)
                        .background(Color("grey-50"))
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                    } label: {
                        if device == .phone || device == .pad {
                            Image(systemName: "text.insert")
                        } else {
                            Text("Heading")
                        }
                    }
                    .tint(Color("grey-500"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        self.tag = "design"
                    } label: {
                        Text("Design")
                    }
                    .tag(0)
                    Button {
                        self.tag = "development"
                    } label: {
                        Text("Development")
                    }
                    .tag(1)
                    Button {
                        self.tag = "opinion"
                    } label: {
                        Text("Opinion")
                    }
                    .tag(2)
                    Button {
                        self.tag = "journal"
                    } label: {
                        Text("Journal")
                    }
                    .tag(3)
                    
                } label: {
                    if device == .phone || device == .pad {
                        Image(systemName: "tag.fill")
                    } else {
                        Text(self.tag.firstUppercased)
                        
                    }
                }
                .tint(Color("grey-500"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        self.hideKeyboard()
                        self.success.impactOccurred()
                        self.snippet = trimString(string: document.text)
                        uploadPost()
                        print("Draft request sent")
                    }
                } label: {
                    Label("Post", systemImage: "arrow.up.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(document.text.isEmpty && tag.isEmpty)
                .tint(.accentColor)
                .keyboardShortcut(.defaultAction)
            }
        }
#endif
        .background(Color("bg"))
        .alert(isPresented: $submitSuccessful) {
            Alert(
                title: Text("Submitted!"),
                message: Text("Submitted draft post successfully"),
                dismissButton: .default(Text("Got it!"))
            )
        }
        .sheet(isPresented: $openPreview) {
            preview
                .padding(.top, 24)
        }
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
    
    var preview: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(document.title)
                    .font(.largeTitle).bold()
                    .padding(.bottom, 8)
                Markdown{
                    document.text
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                    ForegroundColor(.purple)
                    BackgroundColor(.purple.opacity(0.15))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("Preview")
    }
    
    func getAndSetCursorPosition(position: Int, length: Int, characterLength: Int) {
        var range: NSRange?
        range?.location = position
        range?.length = length
        print(position, length)
        
        self.cursorPosition = position + characterLength
        range?.length = position + characterLength
        self.selectionLength = length
        print(cursorPosition, selectionLength)
    }
    
    func trimString(string: String) -> String {
        if string.count > 100 {
            return String(string.prefix(100))
        } else {
            return string
        }
    }
    
    func uploadPost() {
        let api = "https://api.cosmicjs.com/v3/buckets/\(BUCKET)/objects"
        guard let url = URL(string: api) else { return }
        
        let body =
        [
            "type": "writings",
            "title": document.title,
            "metadata": [
                "snippet": snippet,
                "tag": tag,
                "content": document.text,
            ],
            "status": "draft",
        ] as [String : Any]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(WRITE_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("\(String(describing: jsonData?.count))", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("-----> data: \(String(describing: data))")
            print("-----> error: \(String(describing: error))")
            
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            print("-----1> responseJSON: \(String(describing: responseJSON))")
            if let responseJSON = responseJSON as? [String: Any] {
                print("-----2> responseJSON: \(responseJSON)")
                self.submitSuccessful = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self.submitSuccessful = false
                }
            }
        }
        task.resume()
    }
    
    private func replace() {
        viewModel.setup()
        withAnimation {
            self.promptText = "You are a skilled writing bot and your job is to read the provided content and expand on what's provided to create a well written set of prose in the style of a somewhat casual blog post by an author who's knowledgable. Improve on this: \n\n"
            self.fullPrompt = promptText + "\n\n" + document.title + "\n\n" + document.text
            self.promptText = ""
            viewModel.send(system: aPIViewModel.AssistantType, text: fullPrompt, maxTokens: 2049) { gpt in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.document.text = gpt.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }
    
    private func expand() {
        viewModel.setup()
        withAnimation {
            self.promptText = "You are a skilled writing bot and your job is to read the provided content and provide the next paragraph to continue the well written set of prose in the style of a somewhat casual blog post by an author who's knowledgable. Add the next paragraph: \n\n"
            self.fullPrompt = promptText + "\n\n" + document.title + "\n\n" + document.text
            self.promptText = ""
            viewModel.send(system: aPIViewModel.AssistantType, text: fullPrompt, maxTokens: 2049) { gpt in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.document.text = document.text + gpt.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }
}
