//
//  SettingsView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 30/01/2023.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("bucketName") var BUCKET = ""
    @AppStorage("readKey") var READ_KEY = ""
    @AppStorage("writeKey") var WRITE_KEY = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            settingsList
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .symbolRenderingMode(.hierarchical)
                                .symbolVariant(.fill)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
        }
        #else
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Color(nsColor: .windowBackgroundColor)
                }
            
            // Content
            settingsList
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Save") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400)
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
    }
    
    var settingsList: some View {
        List {
            Section("Bucket") {
                TextField("Bucket name", text: $BUCKET)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .listRowSeparator(.hidden)
            Section("Keys") {
                TextField("Read key", text: $READ_KEY)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                TextField("Write key", text: $WRITE_KEY)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .listRowSeparator(.hidden)
            #if os(iOS)
            Button("Save") {
                dismiss()
            }
            #endif
        }
        #if os(macOS)
        .formStyle(.grouped)
        .padding(16)
        #endif
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif

