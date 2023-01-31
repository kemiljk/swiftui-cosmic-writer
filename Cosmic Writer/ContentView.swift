//
//  ContentView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Cosmic_WriterDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(Cosmic_WriterDocument()))
    }
}
