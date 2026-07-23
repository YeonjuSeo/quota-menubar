import SwiftUI

@main
struct QuotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // The UI lives in the status item + popover (managed by AppDelegate).
        // An empty Settings scene satisfies the App protocol without showing
        // a window; the real settings window is opened from the popover.
        Settings { EmptyView() }
    }
}
