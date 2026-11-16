import SwiftUI

/// Two tabs for now: the alphabet to look through, and practice.
struct RootView: View {
    var body: some View {
        TabView {
            AlphabetView()
                .tabItem { Label("Alphabet", systemImage: "character.book.closed") }
            PracticeView()
                .tabItem { Label("Practice", systemImage: "rectangle.on.rectangle.angled") }
        }
    }
}

/// The big title at the top of every tab.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.app(32, weight: .bold)).foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle).font(.app(13)).foregroundStyle(Theme.mute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
