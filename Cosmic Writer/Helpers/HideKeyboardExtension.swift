//
//  HideKeyboardExtension.swift
//  Cosmic Writer
//
//  Created by Karl Koch on 31/01/2023.
//

import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

