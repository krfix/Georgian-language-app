import SwiftUI

/// First run: welcome, a little about Georgian, how the app teaches, the learner's level,
/// a daily goal, a name (optional), then straight into the first lesson. No account.
struct OnboardingView: View {
    enum Step: Int, CaseIterable { case welcome, language, method, level, goal, name, ready }

    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var level: StartingLevel = .beginner
    @State private var goal: DailyGoal = .regular
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)
                .motion(Motion.slow, value: step)
            VStack(spacing: 0) {
                if step != .welcome { topBar }
                ScrollView {
                    page
                        .padding(.horizontal, 24)
                        .padding(.top, step == .welcome ? 40 : 12)
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .scrollBounceBehavior(.basedOnSize)
                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
    }

    private var tint: BrandColor {
        switch step {
        case .welcome, .ready: return .pomegranate
        case .language: return .saperavi
        case .method: return .blacksea
        case .level: return .tkemali
        case .goal: return .gold
        case .name: return .saperavi
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(symbol: "chevron.left", label: "Back") { go(-1) }
                .accessibilityIdentifier("onboarding-back")
            HStack(spacing: 6) {
                ForEach(Step.allCases.dropFirst(), id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? tint.color : Palette.line)
                        .frame(height: 8)
                }
            }
            .motion(Motion.spring, value: step)
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue) of \(Step.allCases.count - 1)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome: WelcomePage()
        case .language: LanguagePage()
        case .method: MethodPage()
        case .level: ChoicePage(title: "How much Georgian do you know?", subtitle: "We'll start you in the right place. You can change it later.",
                                options: StartingLevel.allCases.map { ($0.rawValue, $0.title, $0.detail, $0.symbol) },
                                selected: level.rawValue, color: .tkemali) { level = StartingLevel(rawValue: $0) ?? .beginner }
        case .goal: ChoicePage(title: "Pick a daily goal", subtitle: "Little and often works best. You earn XP for every lesson and review.",
                               options: DailyGoal.allCases.map { ("\($0.rawValue)", "\($0.title) · \($0.rawValue) XP", $0.minutes.capitalizedFirst, goalSymbol($0)) },
                               selected: "\(goal.rawValue)", color: .gold) { goal = DailyGoal(rawValue: Int($0) ?? 20) ?? .regular }
        case .name: namePage
        case .ready: readyPage
        }
    }

    private func goalSymbol(_ g: DailyGoal) -> String {
        switch g {
        case .casual: return "cup.and.saucer.fill"
        case .regular: return "figure.walk"
        case .serious: return "figure.run"
        case .intense: return "flame.fill"
        }
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What should we call you?").font(.titleBold).foregroundStyle(Palette.ink)
            Text("Optional. It's only used to greet you, and it stays on this iPhone.")
                .font(.bodyRounded).foregroundStyle(Palette.inkSoft)
            TextField("Your name", text: $name)
                .font(.title2.weight(.semibold))
                .textContentType(.givenName)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { go(1) }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(nameFocused ? Palette.saperavi : Palette.line, lineWidth: 2))
                .accessibilityIdentifier("onboarding-name")
            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("გამარჯობა, \(name.trimmingCharacters(in: .whitespaces))!")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(Palette.saperavi)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .motion(Motion.bouncy, value: name.isEmpty)
    }

    private var firstLesson: Lesson? {
        level == .canRead ? store.curriculum.lesson("v1") : store.curriculum.lessons.first
    }

    private var readyPage: some View {
        VStack(spacing: 22) {
            Borjgali(size: 150)
                .padding(.top, 10)
            Text("You're all set!")
                .font(.display)
                .foregroundStyle(Palette.ink)
            Text("Your first lesson takes about five minutes.")
                .font(.bodyRounded)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            if let lesson = firstLesson {
                HStack(spacing: 14) {
                    LessonGlyph(lesson: lesson, size: 60, onColor: .white)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("First lesson").font(.captionBold).textCase(.uppercase).foregroundStyle(.white.opacity(0.85))
                        Text(lesson.title).font(.title2Bold).foregroundStyle(.white)
                        Text(lesson.subtitle).font(.calloutRounded).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .gradientCard(.pomegranate)
            }
            HStack(spacing: 10) {
                Pill(text: "\(goal.rawValue) XP a day", color: Palette.gold, symbol: "target")
                Pill(text: level.title, color: Palette.tkemali, symbol: level.symbol)
            }
        }
    }

    @ViewBuilder private var bottomButton: some View {
        switch step {
        case .welcome:
            VStack(spacing: 10) {
                Button("Get started") { go(1) }
                    .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
                    .accessibilityIdentifier("onboarding-next")
                Text("No account needed. Everything stays on your iPhone.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        case .ready:
            VStack(spacing: 8) {
                Button {
                    finish(startLesson: true)
                } label: { Label("Start my first lesson", systemImage: "play.fill") }
                    .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
                    .accessibilityIdentifier("onboarding-start-lesson")
                Button("Explore first") { finish(startLesson: false) }
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding-skip-lesson")
            }
        case .name:
            Button(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip" : "Continue") { go(1) }
                .buttonStyle(ChunkyButtonStyle(color: tint))
                .accessibilityIdentifier("onboarding-next")
        default:
            Button("Continue") { go(1) }
                .buttonStyle(ChunkyButtonStyle(color: tint))
                .accessibilityIdentifier("onboarding-next")
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        Haptics.tap()
        nameFocused = false
        forward = delta > 0
        withMotion(Motion.spring) { step = next }
    }

    private func finish(startLesson: Bool) {
        Haptics.success()
        let lesson = firstLesson
        store.completeOnboarding(name: name, level: level, goal: goal)
        // The main screen replaces onboarding first; the lesson opens over it a moment later.
        if startLesson, let lesson {
            let nav = navigator
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { nav.start(lesson) }
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: Pages

private struct WelcomePage: View {
    @State private var appeared = false
    private let letters = ["ა", "ბ", "გ", "დ", "ე", "ვ", "ზ", "თ", "ი", "კ", "ლ", "მ"]

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                ForEach(Array(letters.enumerated()), id: \.offset) { i, l in
                    let angle = Double(i) / Double(letters.count) * 2 * .pi
                    Text(l)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle([Palette.pomegranate, Palette.saperavi, Palette.gold, Palette.tkemali, Palette.blacksea][i % 5])
                        .offset(x: cos(angle) * (appeared ? 130 : 20), y: sin(angle) * (appeared ? 130 : 20))
                        .opacity(appeared ? 1 : 0)
                }
                Borjgali(size: 170)
            }
            .frame(height: 300)
            VStack(spacing: 10) {
                Text("ქართული")
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundStyle(Gradients.hero)
                    .padding(.vertical, 6)
                Text("Learn Georgian, one letter at a time")
                    .font(.titleBold)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("Read the alphabet in a week. Then words, phrases and real conversations.")
                    .font(.bodyRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .frame(maxWidth: .infinity)
        .onAppear { withMotion(.spring(response: 1.0, dampingFraction: 0.7)) { appeared = true } }
    }
}

private struct LanguagePage: View {
    private let facts: [(String, String, String, BrandColor)] = [
        ("character.book.closed.fill", "33 letters, no capitals", "Mkhedruli, today's alphabet, has one form for every letter.", .pomegranate),
        ("speaker.wave.2.fill", "One letter, one sound", "Words are spelled exactly as they're said. Learn the letters and you can read anything aloud.", .saperavi),
        ("scroll.fill", "Over 1,500 years of writing", "Georgian has its own script. UNESCO lists the living culture of its three alphabets.", .gold),
        ("globe.europe.africa.fill", "A language family of its own", "Georgian is Kartvelian: not related to Russian, Turkish or any language outside the Caucasus. About four million people speak it.", .blacksea),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meet Georgian").font(.titleBold).foregroundStyle(Palette.ink)
            ForEach(Array(facts.enumerated()), id: \.offset) { i, f in
                FactRow(symbol: f.0, title: f.1, text: f.2, color: f.3, delay: Double(i) * 0.08)
            }
        }
    }
}

private struct MethodPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How you'll learn").font(.titleBold).foregroundStyle(Palette.ink)
            FactRow(symbol: "1.circle.fill", title: "Learn", text: "Short lessons: a few new letters or words, shown, then practised straight away.", color: .pomegranate, delay: 0)
            FactRow(symbol: "2.circle.fill", title: "Practise", text: "Ten kinds of exercise: matching, spelling with letter tiles, building sentences, conversations…", color: .saperavi, delay: 0.08)
            FactRow(symbol: "3.circle.fill", title: "Review", text: "Every word comes back just before you'd forget it. Mistakes come back sooner.", color: .blacksea, delay: 0.16)
            FactRow(symbol: "flame.fill", title: "Keep a streak", text: "Earn XP, reach your daily goal and unlock achievements.", color: .gold, delay: 0.24)
        }
    }
}

private struct FactRow: View {
    let symbol: String
    let title: String
    let text: String
    let color: BrandColor
    let delay: Double
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color.onColor)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.gradient))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headlineRounded).foregroundStyle(Palette.ink)
                Text(text).font(.calloutRounded).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 16, cornerRadius: 22)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 16)
        .onAppear { withMotion(Motion.spring.delay(delay)) { shown = true } }
        .accessibilityElement(children: .combine)
    }
}

private struct ChoicePage: View {
    let title: String
    let subtitle: String
    let options: [(id: String, title: String, detail: String, symbol: String)]
    let selected: String
    let color: BrandColor
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.titleBold).foregroundStyle(Palette.ink)
            Text(subtitle).font(.bodyRounded).foregroundStyle(Palette.inkSoft)
            ForEach(options, id: \.id) { o in
                let isOn = o.id == selected
                Button {
                    Haptics.select()
                    withMotion(Motion.spring) { onSelect(o.id) }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: o.symbol)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isOn ? color.onColor : color.color)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isOn ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.color.opacity(0.14))))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(o.title).font(.headlineRounded).foregroundStyle(Palette.ink)
                            Text(o.detail).font(.calloutRounded).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(isOn ? color.color : Palette.line)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(isOn ? color.color : Palette.line, lineWidth: isOn ? 3 : 1.5))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("choice-\(o.id)")
            }
        }
    }
}
