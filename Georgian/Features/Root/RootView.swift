import SwiftUI

/// A lesson or review to play full screen.
struct SessionRequest: Identifiable, Equatable {
    enum Mode: Equatable {
        case lesson(Lesson)
        case review([StudyItem], title: String)
        /// A phrasebook dialogue, one side played by the learner (counts like a review).
        case dialogue(Lesson, tint: String)
    }

    let id = UUID()
    let mode: Mode
    /// Onboarding's first lesson: finishing it ends the onboarding.
    var isFirstLesson = false

    static func == (a: SessionRequest, b: SessionRequest) -> Bool { a.id == b.id }
}

enum AppTab: String, Hashable, CaseIterable {
    case home, learn, phrasebook, words, review

    var title: String {
        switch self {
        case .home: return tr("Home")
        case .learn: return tr("Learn")
        case .phrasebook: return tr("Phrasebook")
        case .words: return tr("Words")
        case .review: return tr("Review")
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .learn: return "map.fill"
        case .phrasebook: return "bubble.left.and.text.bubble.right.fill"
        case .words: return "character.book.closed.fill"
        case .review: return "arrow.triangle.2.circlepath"
        }
    }
}

/// Screens pushed inside the Phrasebook tab.
enum PhrasebookRoute: Hashable {
    case category(String)
    case dialogue(String)
    case saved
}

/// Screens pushed inside the Home tab.
enum HomeRoute: Hashable {
    case progress
}

/// Where the screens go: the tab, what each tab has pushed, the sheets, the phrase on
/// screen and the lesson on screen.
@MainActor @Observable
final class Navigator {
    var tab: AppTab = .home
    var showProfile = false
    var session: SessionRequest?
    var previewLesson: Lesson?
    /// The phrase card, as a sheet over any tab.
    var openPhrase: Phrase?
    /// A phrase shown full screen to someone else (a driver, a shopkeeper).
    var showPhrase: Phrase?
    var phrasebookPath = NavigationPath()
    var homePath = NavigationPath()
    /// Set to open the Words tab's search with the keyboard up (the search bars on Home and
    /// in the Phrasebook), or with a query.
    var searchRequest: SearchRequest?

    struct SearchRequest: Equatable {
        let id = UUID()
        var query: String = ""
    }

    func start(_ lesson: Lesson) {
        present(SessionRequest(mode: .lesson(lesson)))
    }

    func review(_ items: [StudyItem], title: String) {
        guard !items.isEmpty else { return }
        present(SessionRequest(mode: .review(items, title: title)))
    }

    /// Plays one side of a phrasebook dialogue in the lesson player.
    func practise(_ dialogue: PhraseDialogue, as role: Int, in phrasebook: Phrasebook) {
        let color = phrasebook.category(dialogue.category)?.color ?? "saperavi"
        present(SessionRequest(mode: .dialogue(phrasebook.practiceLesson(dialogue, role: role), tint: color)))
    }

    /// Opens a situation in the Phrasebook tab, from anywhere.
    func open(category id: String) {
        closeSheets()
        tab = .phrasebook
        phrasebookPath = NavigationPath()
        phrasebookPath.append(PhrasebookRoute.category(id))
    }

    func openSaved() {
        closeSheets()
        tab = .phrasebook
        phrasebookPath = NavigationPath()
        phrasebookPath.append(PhrasebookRoute.saved)
    }

    func search(_ query: String = "") {
        closeSheets()
        tab = .words
        searchRequest = SearchRequest(query: query)
    }

    /// A lesson's preview sheet; waits for the phrase card to go first.
    func preview(_ lesson: Lesson) {
        if openPhrase != nil {
            openPhrase = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { self.previewLesson = lesson }
        } else {
            previewLesson = lesson
        }
    }

    private func closeSheets() {
        openPhrase = nil
        previewLesson = nil
        showProfile = false
    }

    /// Opens a lesson full screen, after any sheet on screen has gone (two presentations
    /// at once would drop the second).
    private func present(_ request: SessionRequest) {
        if previewLesson != nil || showProfile || sheetOpen || openPhrase != nil {
            previewLesson = nil
            showProfile = false
            sheetOpen = false
            openPhrase = nil
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
            PhrasebookView()
                .tabItem { Label(AppTab.phrasebook.title, systemImage: AppTab.phrasebook.symbol) }
                .tag(AppTab.phrasebook)
            WordsView()
                .tabItem { Label(AppTab.words.title, systemImage: AppTab.words.symbol) }
                .tag(AppTab.words)
            ReviewView()
                .tabItem { Label(AppTab.review.title, systemImage: AppTab.review.symbol) }
                .tag(AppTab.review)
                .badge(store.dueItems.count)
        }
        .onChange(of: navigator.tab) { _, _ in Haptics.select() }
        .sheet(isPresented: $nav.showProfile) { ProfileView() }
        .sheet(item: $nav.previewLesson) { lesson in
            LessonPreviewSheet(lesson: lesson)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $nav.openPhrase) { phrase in
            PhraseDetailView(phrase: phrase)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $nav.showPhrase) { phrase in
            ShowPhraseView(phrase: phrase)
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
        let options = LaunchOptions.current
        let pb = store.phrasebook
        switch screen {
        case "learn", "alphabet": navigator.tab = .learn
        case "words", "word": navigator.tab = .words
        case "progress": navigator.homePath.append(HomeRoute.progress)
        case "review": navigator.tab = .review
        case "profile": navigator.showProfile = true
        case "lesson", "complete":
            if let l = store.curriculum.lesson("v4") { navigator.session = SessionRequest(mode: .lesson(l)) }
        case "exercise":
            if let l = store.curriculum.lesson(options.lessonID ?? "v4") { navigator.session = SessionRequest(mode: .lesson(l)) }
        case "phrasebook": navigator.tab = .phrasebook
        case "category": navigator.open(category: options.item ?? "transport")
        case "emergency": navigator.open(category: "emergency")
        case "saved": navigator.openSaved()
        case "dialogue":
            navigator.tab = .phrasebook
            navigator.phrasebookPath.append(PhrasebookRoute.dialogue(options.item ?? "pd-taxi"))
        case "practice":
            if let d = pb.dialogue(options.item ?? "pd-taxi") { navigator.practise(d, as: 0, in: pb) }
        case "phrase":
            navigator.tab = .phrasebook
            navigator.openPhrase = pb.phrase(options.item ?? "pb-ak-gamicheret-tu-sheidzleba")
        case "show":
            navigator.showPhrase = pb.phrase(options.item ?? "pb-ak-gamicheret-tu-sheidzleba")
        case "search": navigator.search(options.query ?? "")
        default: break
        }
    }
}
