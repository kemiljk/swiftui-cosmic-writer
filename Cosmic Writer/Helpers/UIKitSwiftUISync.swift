#if canImport(UIKit)
import UIKit

/// Safely perform UIKit-to-SwiftUI updates only when not in a marked text session (e.g., during autocorrect or IME composition).
@inline(__always)
public func safeUIKitToSwiftUIUpdate(_ textView: UITextView?, update: () -> Void) {
    guard let textView = textView, textView.markedTextRange == nil else { return }
    update()
} 
#endif
