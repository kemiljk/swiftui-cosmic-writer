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
        NavigationStack {
            VStack {
                List {
                    Section("Bucket") {
                        TextField("Bucket name", text: $BUCKET)
                    }
                    Section("Keys") {
                        TextField("Read key", text: $READ_KEY)
                        TextField("Write key", text: $WRITE_KEY)
                    }
                    Button("Save") {
                        self.dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.dismiss()
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
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
