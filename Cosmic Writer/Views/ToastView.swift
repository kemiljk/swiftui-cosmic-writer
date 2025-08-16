//
//  ToastView.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 03/12/2024.
//
import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
