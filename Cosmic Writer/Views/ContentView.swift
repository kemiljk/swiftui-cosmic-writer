//
//  ContentView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI
//import SwiftDown
import Markdown

struct ContentView: View {
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
    
#if os(iOS)
    var device = UIDevice.current.userInterfaceIdiom
    let modal = UIImpactFeedbackGenerator(style: .medium)
    let success = UIImpactFeedbackGenerator(style: .heavy)
#endif
    
    let media = "00f906c0-6262-11ec-a8a3-53f360c99be6-placeholder2x.png"
    var date: String {
        let today = Date.now
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: today)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if device == .mac {
                HStack {
                    //                    SwiftDownEditor(text: $document.text)
                    //                        .autocorrectionType(.yes)
                    //                        .insetsSize(16)
                    //                        .theme(colorScheme == .dark ? Theme(themePath: Bundle.main.path(forResource: "darkTheme", ofType: "json")!) : Theme(themePath: Bundle.main.path(forResource: "lightTheme", ofType: "json")!))
                    TextEditor(text: $document.text)
                        .scrollContentBackground(.hidden)
                        .background(Color("bg"))
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                    Markdown(content: $document.text)
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                }
            }  else {
                VStack {
                    TextEditor(text: $document.text)
                        .scrollContentBackground(.hidden)
                        .background(Color("bg"))
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                HStack {
                                    Text(tag)
                                    Image(systemName: "xmark.circle")
                                }
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color("grey-50"))
                                .cornerRadius(4)
                                Spacer()
                                Button {
                                    self.hideKeyboard()
                                } label: {
                                    Image(systemName: "keyboard.chevron.compact.down")
                                }
                            }
                        }
                }
                .padding(.horizontal, 12)
            }
//            VStack(alignment: .center, spacing: 0) {
//                VStack {
//                    VStack {
//                        if device == .mac {
//                            Rectangle()
//                                .frame(maxWidth: .infinity, maxHeight: 8)
//                                .foregroundColor(Color("grey-900"))
//                        } else if device == .pad || device == .phone {
//                            VStack {
//                                HStack {
//                                    Text(tag)
//                                    Image(systemName: "xmark.circle")
//                                }
//                                .font(.system(.caption, design: .monospaced))
//                                .padding(.horizontal, 8)
//                                .padding(.vertical, 4)
//                                .background(Color("grey-50"))
//                                .cornerRadius(4)
//                            }
//                            .padding(.top, device == .pad ? 12 : 0)
//                            .background(Color("grey-900"))
//                            .onTapGesture {
//                                self.tag = ""
//                            }
//                        }
//                    }
//                    HStack {
//                        Menu {
//                            Button {
//                                self.tag = "design"
//                            } label: {
//                                Text("Design")
//                            }
//                            .tag(0)
//                            Button {
//                                self.tag = "development"
//                            } label: {
//                                Text("Development")
//                            }
//                            .tag(1)
//                            Button {
//                                self.tag = "opinion"
//                            } label: {
//                                Text("Opinion")
//                            }
//                            .tag(2)
//                            Button {
//                                self.tag = "journal"
//                            } label: {
//                                Text("Journal")
//                            }
//                            .tag(3)
//
//                        } label: {
//                            if device == .phone || device == .pad {
//                                Image(systemName: "tag")
//                                    .foregroundColor(.primary)
//                            } else {
//                                Label(self.tag, systemImage: "tag")
//                            }
//                        }
//                        .tint(Color("grey-50"))
//                        .buttonBorderShape(.capsule)
//                        .buttonStyle(.borderedProminent)
//                        Button {
//                            self.editTitle = true
//#if os(iOS)
//                            self.modal.impactOccurred()
//#endif
//                        } label: {
//                            Image(systemName: "character.cursor.ibeam")
//                                .foregroundColor(.primary)
//                        }
//                        .tint(Color("grey-50"))
//                        .buttonBorderShape(.capsule)
//                        .buttonStyle(.borderedProminent)
//                        .alert("Edit title", isPresented: $editTitle, actions: {
//                            TextField("Title", text: $document.title)
//                            Button("Done", action: {
//                                self.document.title = document.title
//                            })
//                            Button("Cancel", role: .cancel, action: {
//                                self.editTitle = false
//                            })
//                        })
//                        Button {
//                            withAnimation {
//#if os(iOS)
//                                self.hideKeyboard()
//                                self.success.impactOccurred()
//#endif
//                                self.snippet = trimString(string: document.text)
//                                uploadPost()
//                                print("Draft request sent")
//                            }
//                        } label: {
//                            Label("Post", systemImage: "arrow.up.circle.fill")
//                        }
//                        .disabled(document.text.isEmpty && tag.isEmpty)
//                        .tint(.accentColor)
//                        .buttonBorderShape(.capsule)
//                        .buttonStyle(.borderedProminent)
//                        .keyboardShortcut(.defaultAction)
//                    }
//                    .padding(.vertical, device == .pad ? 4 : 12)
//                    .padding(.bottom, device == .pad ? 24 : 0)
//                }
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 16)
//            .background(Color("grey-900"))
//            .cornerRadius(32, corners: [.topLeft, .topRight])
        }
#if os(iOS)
        .toolbar {
            if device == .mac {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            self.openSettings = true
#if os(iOS)
                            self.modal.impactOccurred()
#endif
                        } label: {
                            Image(systemName: "gearshape")
                                .symbolVariant(.fill)
                        }
                        .tint(Color("grey-50"))
                        .buttonStyle(.borderless)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if device == .phone {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        self.openSettings = true
#if os(iOS)
                        self.modal.impactOccurred()
#endif
                    } label: {
                        Image(systemName: "gearshape")
                            .symbolVariant(.fill)
                    }
                    .tint(Color("grey-50"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: preview, label: {
                        Image(systemName: "eye.fill")
                    })
                    .tint(Color("grey-50"))
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
                        Image(systemName: "tag")
                    } else {
                        Text(self.tag)
                    }
                }
                .tint(Color("grey-50"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
#if os(iOS)
                        self.hideKeyboard()
                        self.success.impactOccurred()
#endif
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
//            if device == .phone {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        UIApplication.shared.endEditing()
//                    }) {
//                        Image(systemName: "keyboard.chevron.compact.down")
//                            .symbolVariant(.fill)
//                    }
//                }
//            }
        }
#endif
        .sheet(isPresented: $openSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
        .background(Color("bg"))
//        .edgesIgnoringSafeArea(.bottom)
    }
    
    var preview: some View {
            VStack {
                Markdown(content: $document.text)
                    .markdownStyle(
                        MarkdownStyle(
                            padding: 0, paddingTop: 24, paddingBottom: 0, paddingLeft: 16, paddingRight: 16
                        )
                    )
            }
            .padding(.horizontal, 12)
            .navigationTitle("Preview")
    }
    
    func trimString(string: String) -> String {
        if string.count > 100 {
            return String(string.prefix(100))
        } else {
            return string
        }
    }
    
    func uploadPost() {
        let api = "https://api.cosmicjs.com/v2/buckets/\(BUCKET)/objects"
        
        guard let url = URL(string: api) else { return }
        
        let body =
        [
            "type": "writings",
            "title": document.title,
            "thumbnail": media,
            "metafields": [
                [
                    "key": "hero",
                    "title": "hero",
                    "type": "file",
                    "value": media,
                ],
                [
                    "key": "published",
                    "title": "published",
                    "type": "date",
                    "value": date,
                ],
                [
                    "key": "snippet",
                    "title": "snippet",
                    "type": "text",
                    "value": snippet,
                ],
                [
                    "key": "tag",
                    "title": "tag",
                    "type": "radio-buttons",
                    "value": tag,
                    "options": [
                        [
                            "value": "design"
                        ],
                        [
                            "value": "development"
                        ],
                        [
                            "value": "opinion"
                        ],
                        [
                            "value": "journal"
                        ],
                    ],
                ],
                [
                    "key": "content",
                    "title": "content",
                    "type": "markdown",
                    "value": document.text,
                ],
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
            }
        }
        task.resume()
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(Cosmic_WriterDocument()))
    }
}
