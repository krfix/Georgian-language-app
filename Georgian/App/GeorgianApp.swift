import SwiftUI

@main
struct GeorgianApp: App {
    @State private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            TextSizeRoot { RootView() }
                .environment(progress)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
