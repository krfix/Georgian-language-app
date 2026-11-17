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
            CircleIconButton(symbol: "chevron.left", label: tr("Back")) { go(-1) }
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
            .accessibilityLabel(tr("Step {0} of {1}", step.rawValue, Step.allCases.count - 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome: WelcomePage()
        case .language: LanguagePage()
        case .method: MethodPage()
        case .level: ChoicePage(title: tr("How much Georgian do you know?"), subtitle: tr("We'll start you in the right place. You can change it later."),
                                options: StartingLevel.allCases.map { ($0.rawValue, $0.title, $0.detail, $0.symbol) },
                                selected: level.rawValue, color: .tkemali) { level = StartingLevel(rawValue: $0) ?? .beginner }
        case .goal: ChoicePage(title: tr("Pick a daily goal"), subtitle: tr("Little and often works best. You earn XP for every lesson and review."),
                               options: DailyGoal.allCases.map { ("\($0.rawValue)", tr("{0} · {1} XP", $0.title, $0.rawValue), $0.minutes.capitalizedFirst, goalSymbol($0)) },
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
            Text(tr("What should we call you?")).font(.titleBold).foregroundStyle(Palette.ink)
            Text(tr("Optional. It's only used to greet you, and it stays on this iPhone."))
                .font(.bodyRounded).foregroundStyle(Palette.inkSoft)
            TextField(tr("Your name"), text: $name)
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
            ParrotView(height: 150, mood: .cheer)
                .padding(.top, 10)
            Text(tr("You're all set!"))
                .font(.display)
                .foregroundStyle(Palette.ink)
            Text(tr("Your first lesson takes about five minutes."))
                .font(.bodyRounded)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            if let lesson = firstLesson {
                HStack(spacing: 14) {
                    LessonGlyph(lesson: lesson, size: 60, onColor: .white)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("First lesson")).font(.captionBold).textCase(.uppercase).foregroundStyle(.white.opacity(0.85))
                        Text(lesson.title).font(.title2Bold).foregroundStyle(.white)
                        Text(lesson.subtitle).font(.calloutRounded).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .gradientCard(.pomegranate)
            }
            HStack(spacing: 10) {
                Pill(text: tr("{0} XP a day", goal.rawValue), color: Palette.gold, symbol: "target")
                Pill(text: level.title, color: Palette.tkemali, symbol: level.symbol)
            }
        }
    }

    @ViewBuilder private var bottomButton: some View {
        switch step {
        case .welcome:
            VStack(spacing: 10) {
                Button(tr("Get started")) { go(1) }
                    .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
                    .accessibilityIdentifier("onboarding-next")
                Button {
                    finish(startLesson: false)
                    let nav = navigator
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nav.tab = .phrasebook }
                } label: {
                    Label(tr("I just need phrases now"), systemImage: "bubble.left.and.text.bubble.right.fill")
                }
                .buttonStyle(SoftButtonStyle())
                .accessibilityIdentifier("onboarding-phrasebook")
                Text(tr("No account needed. Everything stays on your iPhone and works offline."))
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        case .ready:
            VStack(spacing: 8) {
                Button {
                    finish(startLesson: true)
                } label: { Label(tr("Start my first lesson"), systemImage: "play.fill") }
                    .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
                    .accessibilityIdentifier("onboarding-start-lesson")
                Button(tr("Explore first")) { finish(startLesson: false) }
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding-skip-lesson")
            }
        case .name:
            Button(name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("Skip") : tr("Continue")) { go(1) }
                .buttonStyle(ChunkyButtonStyle(color: tint))
                .accessibilityIdentifier("onboarding-next")
        default:
            Button(tr("Continue")) { go(1) }
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
            LanguageSwitcher()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -24)
            ZStack {
                ForEach(Array(letters.enumerated()), id: \.offset) { i, l in
                    let angle = Double(i) / Double(letters.count) * 2 * .pi
                    Text(l)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle([Palette.pomegranate, Palette.saperavi, Palette.gold, Palette.tkemali, Palette.blacksea][i % 5])
                        .offset(x: cos(angle) * (appeared ? 130 : 20), y: sin(angle) * (appeared ? 130 : 20))
                        .opacity(appeared ? 1 : 0)
                }
                Borjgali(size: 230, colors: [Palette.gold.opacity(0.35), Palette.pomegranate.opacity(0.2), Palette.saperavi.opacity(0.3)])
                ParrotView(height: 190)
            }
            .frame(height: 300)
            VStack(spacing: 10) {
                Text(tr("Ara"))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Gradients.hero)
                Text(tr("Learn Georgian, and use it every day"))
                    .font(.titleBold)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(LocalizedStringKey(tr("Ara (**არა**) means \u{201C}no\u{201D} in Georgian. By the end, you\u{2019}ll be saying **კი**: yes!")))
                    .font(.bodyRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("welcome-joke")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .frame(maxWidth: .infinity)
        .onAppear { withMotion(.spring(response: 1.0, dampingFraction: 0.7)) { appeared = true } }
    }
}

/// English or Polish, on the welcome screen: the whole app switches at once.
struct LanguageSwitcher: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppLanguage.allCases) { l in
                let on = l == app.language
                Button {
                    guard !on else { return }
                    Haptics.select()
                    app.setLanguage(l)
                } label: {
                    Text(l.flag + " " + l.nativeName)
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(on ? Color.white : Palette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(on ? AnyShapeStyle(Gradients.hero) : AnyShapeStyle(Color.clear)))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("language-\(l.rawValue)")
            }
        }
        .padding(4)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tr("Language"))
    }
}

private struct LanguagePage: View {
    private let facts: [(String, String, String, BrandColor)] = [
        ("character.book.closed.fill", tr("33 letters, no capitals"), tr("Mkhedruli, today's alphabet, has one form for every letter."), .pomegranate),
        ("speaker.wave.2.fill", tr("One letter, one sound"), tr("Words are spelled exactly as they're said. Learn the letters and you can read anything aloud."), .saperavi),
        ("scroll.fill", tr("Over 1,500 years of writing"), tr("Georgian has its own script. UNESCO lists the living culture of its three alphabets."), .gold),
        ("globe.europe.africa.fill", tr("A language family of its own"), tr("Georgian is Kartvelian: not related to Russian, Turkish or any language outside the Caucasus. About four million people speak it."), .blacksea),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Meet Georgian")).font(.titleBold).foregroundStyle(Palette.ink)
            ForEach(Array(facts.enumerated()), id: \.offset) { i, f in
                FactRow(symbol: f.0, title: f.1, text: f.2, color: f.3, delay: Double(i) * 0.08)
            }
        }
    }
}

private struct MethodPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("How you'll learn")).font(.titleBold).foregroundStyle(Palette.ink)
            FactRow(symbol: "1.circle.fill", title: tr("Learn"), text: tr("Short lessons: a few new letters or words, shown, then practised straight away."), color: .pomegranate, delay: 0)
            FactRow(symbol: "2.circle.fill", title: tr("Practise"), text: tr("Ten kinds of exercise: matching, spelling with letter tiles, building sentences, conversations…"), color: .saperavi, delay: 0.08)
            FactRow(symbol: "3.circle.fill", title: tr("Review"), text: tr("Every word comes back just before you'd forget it. Mistakes come back sooner."), color: .blacksea, delay: 0.16)
            FactRow(symbol: "flame.fill", title: tr("Keep a streak"), text: tr("Earn XP, reach your daily goal and unlock achievements."), color: .gold, delay: 0.24)
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
