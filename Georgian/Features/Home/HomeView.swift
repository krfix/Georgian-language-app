import SwiftUI

/// Home (KART #6 order): the greeting; how far you are (a small card, always in view); the
/// two halves of the app, Learn (your next lesson, one tap) and Use in Georgia; review, only
/// when something is waiting; search; the situations; recent and saved phrases. Each thing
/// once, the most frequent first.
struct HomeView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        @Bindable var nav = navigator
        NavigationStack(path: $nav.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    HomeProgressCard()
                    PurposeRow()
                    if !store.dueItems.isEmpty { ReviewNudgeCard() }
                    SearchBarButton { navigator.search() }
                    QuickSituations()
                    PhraseShelf()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .pomegranate))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .progress:
                    ProgressScreen().toolbar(.visible, for: .navigationBar)
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "დილა მშვიდობისა"
        case 18..<24: return "საღამო მშვიდობისა"
        default: return "გამარჯობა"
        }
    }

    private var greetingLatin: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return tr("Good morning")
        case 18..<24: return tr("Good evening")
        default: return tr("Hello")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.pomegranate)
                Text(store.profile.name.isEmpty ? greetingLatin + "!" : greetingLatin + ", " + store.profile.name + "!")
                    .font(.display)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button {
                Haptics.tap()
                navigator.showProfile = true
            } label: {
                Text(store.profile.name.isEmpty ? "ა" : String(store.profile.name.prefix(1)).uppercased())
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Gradients.hero))
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
                    .shadow(color: Palette.pomegranate.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(tr("Profile and settings"))
            .accessibilityIdentifier("profile-button")
        }
        .padding(.top, 12)
    }
}

/// A big symbol for a lesson: its first letter, or an icon for its kind.
struct LessonGlyph: View {
    let lesson: Lesson
    var size: CGFloat = 60
    var onColor: Color = .white

    var body: some View {
        ZStack {
            Circle().fill(onColor.opacity(0.18))
            if let first = lesson.letters?.first {
                Text(first).font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(onColor)
            } else {
                Image(systemName: symbol).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(onColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        switch lesson.kind {
        case .letters: return "text.book.closed.fill"
        case .contrast: return "waveform"
        case .vocabulary: return "character.bubble.fill"
        case .phrases: return "text.bubble.fill"
        case .grammar: return "puzzlepiece.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        }
    }
}

/// The last seven days: a dot per day, lit when there was any learning.
struct WeekDots: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let days = store.weeklyXP(7)
        HStack(spacing: 6) {
            ForEach(days, id: \.day) { d in
                VStack(spacing: 3) {
                    Circle()
                        .fill(d.xp >= store.profile.dailyGoal ? AnyShapeStyle(Gradients.gold) : d.xp > 0 ? AnyShapeStyle(Palette.gold.opacity(0.45)) : AnyShapeStyle(Palette.line))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if d.xp >= store.profile.dailyGoal {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                            }
                        }
                    Text(weekday(d.day)).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkFaint)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func weekday(_ key: String) -> String {
        guard let date = DayKey.date(key) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }
}

/// The next few lessons as stepping stones.
struct PathPreview: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let states = store.lessonStates
        let lessons = store.curriculum.lessons
        let start = lessons.firstIndex { states[$0.id] == .current } ?? 0
        let slice = Array(lessons[max(0, start - 1)..<min(lessons.count, start + 5)])
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: tr("Your path"), trailing: tr("See all")) { navigator.tab = .learn }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(slice) { lesson in
                        let state = states[lesson.id] ?? .locked
                        let color = BrandColor(named: store.curriculum.module(of: lesson.id)?.color ?? "pomegranate")
                        Button {
                            Haptics.tap()
                            if state != .locked { navigator.previewLesson = lesson }
                        } label: {
                            VStack(spacing: 8) {
                                PathNode(lesson: lesson, state: state, color: color, size: 64)
                                Text(lesson.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(state == .locked ? Palette.inkFaint : Palette.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 90)
                            }
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("\(lesson.title), \(stateLabel(state))")
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }
}

func stateLabel(_ s: LessonState) -> String {
    switch s {
    case .completed: return tr("done")
    case .current: return tr("up next")
    case .available: return tr("open")
    case .locked: return tr("locked")
    }
}

struct ChallengeCard: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let c = store.dailyChallenge
        let value = min(store.challengeValue, c.target)
        let done = store.challengeDone
        return HStack(spacing: 14) {
            Image(systemName: done ? "trophy.fill" : c.symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(done ? AnyShapeStyle(Gradients.gold) : AnyShapeStyle(BrandColor.saperavi.gradient)))
                .symbolEffect(.bounce, value: done)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tr("Daily challenge")).font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.saperavi)
                    Spacer()
                    if done { Pill(text: tr("Done"), color: Palette.success) }
                }
                Text(c.title).font(.headlineRounded).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                ProgressBar(progress: Double(value) / Double(max(1, c.target)), color: Palette.saperavi, height: 10)
                Text("\(value) / \(c.target)").font(.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct ReviewNudgeCard: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let due = store.dueItems
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(due.isEmpty ? tr("Nothing to review") : tr("{0} to review", due.count)).font(.headlineRounded).foregroundStyle(Palette.ink)
                    Text(due.isEmpty ? tr("Learn something new, and it comes back here at the right time.") : tr("Words and letters you're about to forget."))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.blacksea)
            }
            if !due.isEmpty {
                FlowLayout(spacing: 6, alignment: .leading) {
                    ForEach(due.prefix(8)) { item in
                        Text(item.georgian)
                            .font(.system(.callout, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Palette.blacksea.opacity(0.12)))
                    }
                }
                Button {
                    Haptics.tap()
                    navigator.review(due, title: tr("Daily review"))
                } label: {
                    Label(tr("Review now"), systemImage: "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: .blacksea))
                .accessibilityIdentifier("home-review")
            }
        }
        .card()
    }
}

// MARK: Use in Georgia, on Home

/// How far the learner is, small enough to sit at the top of Home: the stage's name (no
/// exam levels), the share of the course, the week. Opens the Progress screen.
struct HomeProgressCard: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let s = store.snapshot
        let stage = store.courseStage
        let total = max(1, store.curriculum.lessons.count)
        let pct = Int((Double(s.lessonsCompleted.count) / Double(total) * 100).rounded())
        Button {
            Haptics.tap()
            navigator.homePath.append(HomeRoute.progress)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(stage.emoji)
                        .font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Palette.gold.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Your level")).font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.inkFaint)
                        Text(stage.name).font(.headlineRounded).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    Text("\(pct)%").font(.title3.weight(.bold)).foregroundStyle(Palette.saperavi)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.inkFaint)
                }
                HStack(alignment: .center, spacing: 10) {
                    WeekDots()
                    Spacer(minLength: 4)
                    if store.streak > 0 {
                        Label(tr("{0}-day streak", store.streak), systemImage: "flame.fill")
                            .font(.captionBold).foregroundStyle(Palette.flame)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
            .card(padding: 14, cornerRadius: 22)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("Your level: {0}. {1} percent of the course. Opens your progress.", stage.name, pct))
        .accessibilityIdentifier("home-progress")
    }
}

/// The two halves of the app, side by side and low: Learn opens the next lesson in one tap,
/// Use in Georgia the phrasebook. Each with a thin bar of how far you are.
struct PurposeRow: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let lessonsDone = store.completedLessons.count
        let total = store.curriculum.lessons.count
        let phrases = store.phrasebook.phrases
        let phrasesLearned = phrases.filter { store.isLearned($0.id) }.count
        let next = store.nextLesson
        HStack(spacing: 12) {
            tile(color: .saperavi, symbol: "map.fill", title: tr("Learn"),
                 text: next.map { tr("Next: {0}", $0.title) } ?? tr("Course finished!"),
                 progress: Double(lessonsDone) / Double(max(1, total)),
                 detail: tr("{0} of {1} lessons", lessonsDone, total), id: "continue-lesson") {
                if let next { navigator.preview(next) } else { navigator.tab = .learn }
            }
            tile(color: .pomegranate, symbol: "bubble.left.and.text.bubble.right.fill", title: tr("Use in Georgia"),
                 text: tr("Phrases for real situations"),
                 progress: Double(phrasesLearned) / Double(max(1, phrases.count)),
                 detail: tr("{0} of {1} phrases learned", phrasesLearned, phrases.count), id: "purpose-use") {
                navigator.tab = .phrasebook
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(color: BrandColor, symbol: String, title: String, text: String, progress: Double, detail: String,
                      id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(title)
                        .font(.headlineRounded)
                        .foregroundStyle(color.onColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(color.onColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(color.onColor.opacity(0.18)))
                }
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color.onColor.opacity(0.92))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                ProgressBar(progress: progress, color: color.onColor.opacity(0.9), height: 6)
                Text(detail)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color.onColor.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .gradientCard(color, padding: 14, cornerRadius: 22)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(id)
    }
}

/// The situations people need most, one tap each, and emergencies in red.
struct QuickSituations: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    private let ids = ["transport", "shopping", "food", "health", "home", "social", "emergency"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: tr("Right now I need…"), trailing: tr("All")) { navigator.tab = .phrasebook }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ids.compactMap(store.phrasebook.category)) { c in
                        Button {
                            Haptics.tap()
                            navigator.open(category: c.id)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: c.symbol)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 58, height: 58)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(c.isEmergency ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE5484D), Color(hex: 0xB4232F)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(c.brand.gradient))
                                    )
                                    .shadow(color: c.brand.fill.opacity(0.3), radius: 6, y: 3)
                                Text(shortName(c))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(c.isEmergency ? Palette.error : Palette.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(width: 80, alignment: .top)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(c.title)
                        .accessibilityIdentifier("quick-\(c.id)")
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    private func shortName(_ c: PhraseCategory) -> String {
        switch c.id {
        case "transport": return tr("Taxi & bus")
        case "shopping": return tr("Shopping")
        case "food": return tr("Café")
        case "health": return tr("Pharmacy")
        case "home": return tr("At home")
        case "social": return tr("People")
        case "emergency": return tr("Emergency")
        default: return c.title
        }
    }
}

/// Recently used phrases, or saved ones, as small cards to tap again.
struct PhraseShelf: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let recent = store.recentPhrases
        let saved = store.savedPhrases
        let list = recent.isEmpty ? saved : recent
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: recent.isEmpty ? tr("Your saved phrases") : tr("Recently used"),
                             trailing: saved.isEmpty ? nil : tr("My phrasebook")) { navigator.openSaved() }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(list.prefix(8)) { p in PhraseMiniCard(phrase: p) }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
            }
        }
    }
}
