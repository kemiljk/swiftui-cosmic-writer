//
//  Previewview.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 02/12/2024.
//
import SwiftUI
import MarkdownUI

struct PreviewView: View {
    let document: Cosmic_WriterDocument
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(document.title)
                    .font(.largeTitle).bold()
                    .padding(.bottom, 8)
                Markdown {
                    document.text
                }
                .markdownTextStyle(\.code) {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                    ForegroundColor(.purple)
                    BackgroundColor(.purple.opacity(0.15))
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Preview")
    }
}
