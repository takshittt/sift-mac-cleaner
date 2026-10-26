import SwiftUI

/// `SwiftUI.State` under another name. Recent SDKs make `@State` a macro whose
/// plugin ships only with full Xcode; the wrapper type itself works everywhere,
/// so the app builds with just the Command Line Tools. Use `@ViewState` in views.
typealias ViewState<Value> = SwiftUI.State<Value>
