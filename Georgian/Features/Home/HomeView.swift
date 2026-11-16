import SwiftUI

/// The dashboard: greeting, streak and XP, the daily goal, the next lesson, the path ahead,
/// today's challenge and words to review.
struct HomeView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statsRow
                    if let lesson = store.nextLesson { ContinueCard(lesson: lesson) }
                    else { CourseDoneCard() }
                    DailyGoalCard()
                    PathPreview()
                    ChallengeCard()
                    ReviewNudgeCard()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .pomegranate))
            .toolbar(.hidden, for: .navigationBar)
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
        case 5..<12: return "Good morning"
        case 18..<24: return "Good evening"
        default: return "Hello"
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.pomegranate)
                Text(store.profile.name.isEmpty ? "\(greetingLatin)!" : "\(greetingLatin), \(store.profile.name)!")
                    .font(.display)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
            .accessibilityLabel("Profile and settings")
            .accessibilityIdentifier("profile-button")
        }
        .padding(.top, 12)
    }

    private var statsRow: some View {
        let xp = store.totalXP
        return HStack(spacing: 12) {
            StatTile(symbol: "flame.fill", value: "\(store.streak)", label: "day streak", color: Palette.flame, singleLine: true)
            StatTile(symbol: "bolt.fill", value: "\(xp)", label: "total XP", color: Palette.gold, singleLine: true)
            StatTile(symbol: "star.fill", value: "\(LearnerLevel.level(forXP: xp))", label: "level", color: Palette.saperavi, singleLine: true)
        }
    }
}

/// The big card for the next lesson.
struct ContinueCard: View {
    let lesson: Lesson
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var glow = false

    var body: some View {
        let module = store.curriculum.module(of: lesson.id)
        let color = BrandColor(named: module?.color ?? "pomegranate")
        let done = module.map { store.completedCount(in: $0) } ?? 0
        let total = module?.lessons.count ?? 1
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(module?.title ?? "", systemImage: module?.symbol ?? "book")
                    .font(.captionBold)
                    .textCase(.uppercase)
                    .foregroundStyle(color.onColor.opacity(0.85))
                Spacer()
                Text("\(done)/\(total)").font(.captionBold).foregroundStyle(color.onColor.opacity(0.85))
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.completedLessons.isEmpty ? "Start learning" : "Continue")
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(color.onColor.opacity(0.85))
                    Text(lesson.title)
                        .font(.titleBold)
                        .foregroundStyle(color.onColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lesson.subtitle)
                        .font(.calloutRounded)
                        .foregroundStyle(color.onColor.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                LessonGlyph(lesson: lesson, size: 74, onColor: color.onColor)
            }
            ProgressBar(progress: Double(done) / Double(max(1, total)), color: color.onColor.opacity(0.9), height: 10)
            Button {
                Haptics.tap()
                navigator.start(lesson)
            } label: {
                Label("Start lesson", systemImage: "play.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: color == .gold ? .pomegranate : .gold))
            .accessibilityIdentifier("continue-lesson")
        }
        .gradientCard(color)
        .scaleEffect(glow ? 1.0 : 0.985)
        .onAppear { withMotion(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true } }
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

struct CourseDoneCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You've finished the course!").font(.titleBold).foregroundStyle(.white)
            Text("Keep your Georgian fresh with daily reviews.").font(.calloutRounded).foregroundStyle(.white.opacity(0.9))
        }
        .gradientCard(.tkemali)
    }
}

struct DailyGoalCard: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let goal = store.profile.dailyGoal
        let xp = store.xpToday
        let progress = Double(xp) / Double(max(1, goal))
        return HStack(spacing: 18) {
            ProgressRing(progress: progress, lineWidth: 12) {
                VStack(spacing: 0) {
                    Text("\(min(xp, 999))").font(.title2Bold).foregroundStyle(Palette.ink).contentTransition(.numericText())
                    Text("of \(goal)").font(.caption2).foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 5) {
                Text("Daily goal").font(.headlineRounded).foregroundStyle(Palette.ink)
                Text(progress >= 1 ? "Done for today. ყოჩაღ!" : "\(max(0, goal - xp)) XP to go: about one lesson.")
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                WeekDots()
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily goal: \(xp) of \(goal) XP")
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
            SectionTitle(title: "Your path", trailing: "See all") { navigator.tab = .learn }
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
    case .completed: return "done"
    case .current: return "up next"
    case .available: return "open"
    case .locked: return "locked"
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
                    Text("Daily challenge").font(.captionBold).textCase(.uppercase).foregroundStyle(Palette.saperavi)
                    Spacer()
                    Pill(text: done ? "Done" : "+\(XPRules.challengeBonus) XP", color: done ? Palette.success : Palette.gold)
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
                    Text(due.isEmpty ? "Nothing to review" : "\(due.count) to review").font(.headlineRounded).foregroundStyle(Palette.ink)
                    Text(due.isEmpty ? "Learn something new, and it comes back here at the right time." : "Words and letters you're about to forget.")
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
                    navigator.review(due, title: "Daily review")
                } label: {
                    Label("Review now", systemImage: "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: .blacksea))
                .accessibilityIdentifier("home-review")
            }
        }
        .card()
    }
}
