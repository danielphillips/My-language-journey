import SwiftUI
import UIKit

/// App-wide: a tap anywhere outside a text input dismisses the keyboard.
///
/// Installed once on the window, so it also covers sheets and full-screen covers (they live in the
/// same window). It never cancels touches, so buttons, rows and pickers still receive the tap, and
/// taps on text fields/views are ignored so moving between fields keeps the keyboard up.
final class KeyboardDismissTapRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(dismissKeyboard))
        cancelsTouchesInView = false
        delaysTouchesEnded = false
        delegate = self
    }

    @objc private func dismissKeyboard() {
        view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let view = current {
            if view is UITextField || view is UITextView { return false }
            current = view.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window,
                  !(window.gestureRecognizers ?? []).contains(where: { $0 is KeyboardDismissTapRecognizer })
            else { return }
            window.addGestureRecognizer(KeyboardDismissTapRecognizer())
        }
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}
}

extension View {
    /// Tap outside a text field, or drag a scroll view, to dismiss the keyboard everywhere below this view.
    func dismissesKeyboardOnTapOutside() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissInstaller().allowsHitTesting(false))
    }
}
