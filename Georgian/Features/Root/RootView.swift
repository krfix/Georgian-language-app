import SwiftUI

/// A lesson or review to play full screen.
struct SessionRequest: Identifiable, Equatable {
    enum Mode: Equatable {
        case lesson(Lesson)
        case review([StudyItem], title: String)
    }

    let id = UUID()
    let mode: Mode
    /// Onboarding's first lesson: finishing it ends the onboarding.
    var isFirstLesson = false

    static func == (a: SessionRequest, b: SessionRequest) -> Bool { a.id == b.id }
}

enum AppTab: String, Hashable, CaseIterable {
    case home, learn, words, review, progress

    var title: String {
        switch self {
        case .home: return "Home"
        case .learn: return "Learn"
        case .words: return "Words"
        case .review: return "Review"
        case .progress: return "Progress"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .learn: return "map.fill"
        case .words: return "character.book.closed.fill"
        case .review: return "arrow.triangle.2.circlepath"
        case .progress: return "chart.bar.fill"
        }
    }
}

/// Where the screens go: the tab, the profile sheet and the lesson on screen.
@MainActor @Observable
final class Navigator {
    var tab: AppTab = .home
    var showProfile = false
    var session: SessionRequest?
    var previewLesson: Lesson?

    func start(_ lesson: Lesson) {
        present(SessionRequest(mode: .lesson(lesson)))
    }

    func review(_ items: [StudyItem], title: String) {
        guard !items.isEmpty else { return }
        present(SessionRequest(mode: .review(items, title: title)))
    }

    /// Opens a lesson full screen, after any sheet on screen has gone (two presentations
    /// at once would drop the second).
    private func present(_ request: SessionRequest) {
        if previewLesson != nil || showProfile || sheetOpen {
            previewLesson = nil
            showProfile = false
            sheetOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { self.session = request }
        } else {
            session = request
        }
    }

    /// Set by screens that show their own sheet (the alphabet chart) while it is open.
    var sheetOpen = false
}

struct RootView: View {
    @Environment(LearningStore.self) private var store
    @State private var navigator = Navigator()

    var body: some View {
        Group {
            if store.profile.onboardingDone && LaunchOptions.current.screen != "onboarding" {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(navigator)
        .motion(Motion.gentle, value: store.profile.onboardingDone)
    }
}

struct MainTabView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var didApplyLaunchScreen = false

    var body: some View {
        @Bindable var nav = navigator
        TabView(selection: $nav.tab) {
            HomeView()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }
                .tag(AppTab.home)
            LearnView()
                .tabItem { Label(AppTab.learn.title, systemImage: AppTab.learn.symbol) }
                .tag(AppTab.learn)
            VocabularyView()
                .tabItem { Label(AppTab.words.title, systemImage: AppTab.words.symbol) }
                .tag(AppTab.words)
            ReviewView()
                .tabItem { Label(AppTab.review.title, systemImage: AppTab.review.symbol) }
                .tag(AppTab.review)
                .badge(store.dueItems.count)
            ProgressScreen()
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.symbol) }
                .tag(AppTab.progress)
        }
        .onChange(of: navigator.tab) { _, _ in Haptics.select() }
        .sheet(isPresented: $nav.showProfile) { ProfileView() }
        .sheet(item: $nav.previewLesson) { lesson in
            LessonPreviewSheet(lesson: lesson)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $nav.session) { request in
            LessonPlayerView(request: request)
        }
        .onAppear(perform: applyLaunchScreen)
    }

    /// The screenshot run opens straight on one screen (LaunchOptions).
    private func applyLaunchScreen() {
        guard !didApplyLaunchScreen, let screen = LaunchOptions.current.screen else { return }
        didApplyLaunchScreen = true
        switch screen {
        case "learn": navigator.tab = .learn
        case "words", "word": navigator.tab = .words
        case "review": navigator.tab = .review
        case "progress": navigator.tab = .progress
        case "profile": navigator.showProfile = true
        case "lesson", "complete":
            if let l = store.curriculum.lesson("v4") { navigator.session = SessionRequest(mode: .lesson(l)) }
        case "alphabet": navigator.tab = .learn
        default: break
        }
    }
}
