import SwiftUI

/// The learning path: five modules, each a winding trail of lesson stones.
struct LearnView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var showAlphabet = LaunchOptions.current.screen == "alphabet"
    @State private var lockedNotice: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 26) {
                        ForEach(store.curriculum.modules) { module in
                            ModuleSection(module: module, showAlphabet: $showAlphabet) { lesson, state in
                                if state == .locked {
                                    Haptics.error()
                                    withMotion { lockedNotice = "Finish the lessons before \"\(lesson.title)\" to open it." }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withMotion { lockedNotice = nil } }
                                } else {
                                    Haptics.tap()
                                    navigator.previewLesson = lesson
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    if let next = store.nextLesson {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withMotion(Motion.slow) { proxy.scrollTo(next.id, anchor: .center) }
                        }
                    }
                }
            }
            .background(AmbientBackground(tint: .saperavi))
            .navigationTitle("Learn")
            .overlay(alignment: .bottom) {
                if let lockedNotice {
                    Label(lockedNotice, systemImage: "lock.fill")
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.ink.opacity(0.9)))
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showAlphabet) { AlphabetChartView() }
        }
    }
}

private struct ModuleSection: View {
    let module: CourseModule
    @Binding var showAlphabet: Bool
    let onTap: (Lesson, LessonState) -> Void
    @Environment(LearningStore.self) private var store

    var body: some View {
        let color = BrandColor(named: module.color)
        let done = store.completedCount(in: module)
        let states = store.lessonStates
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title).font(.titleBold).foregroundStyle(color.onColor)
                        Text(module.subtitle).font(.calloutRounded.weight(.semibold)).foregroundStyle(color.onColor.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: module.symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(color.onColor.opacity(0.9))
                }
                Text(module.intro)
                    .font(.calloutRounded)
                    .foregroundStyle(color.onColor.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressBar(progress: Double(done) / Double(max(1, module.lessons.count)), color: color.onColor.opacity(0.9), height: 10)
                    Text("\(done)/\(module.lessons.count)").font(.captionBold).foregroundStyle(color.onColor)
                }
                if module.id == "alphabet" {
                    Button {
                        Haptics.tap()
                        showAlphabet = true
                    } label: {
                        Label("All 33 letters", systemImage: "square.grid.3x3.fill")
                            .font(.calloutRounded.weight(.bold))
                            .foregroundStyle(color.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("alphabet-chart")
                }
            }
            .gradientCard(color)
            .accessibilityElement(children: .contain)

            // The trail: stones swing left and right.
            VStack(spacing: 6) {
                ForEach(Array(module.lessons.enumerated()), id: \.element.id) { i, lesson in
                    let state = states[lesson.id] ?? .locked
                    Button { onTap(lesson, state) } label: {
                        HStack(spacing: 14) {
                            PathNode(lesson: lesson, state: state, color: color, size: 72)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.headlineRounded)
                                    .foregroundStyle(state == .locked ? Palette.inkFaint : Palette.ink)
                                Text(lesson.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Palette.inkSoft)
                                    .lineLimit(1)
                            }
                            .frame(width: 150, alignment: .leading)
                        }
                        .offset(x: swing(i))
                    }
                    .buttonStyle(.pressable)
                    .id(lesson.id)
                    .accessibilityLabel("\(lesson.title). \(lesson.subtitle). \(stateLabel(state))")
                    .accessibilityIdentifier("lesson-\(lesson.id)")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func swing(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 40, 60, 40, 0, -40, -60, -40]
        return pattern[i % pattern.count]
    }
}

/// One stone on the path: done (gold with a tick), up next (pulsing), open, or locked.
struct PathNode: View {
    let lesson: Lesson
    let state: LessonState
    let color: BrandColor
    var size: CGFloat = 72
    @State private var pulse = false

    var body: some View {
        ZStack {
            if state == .current {
                Circle()
                    .stroke(color.color.opacity(0.35), lineWidth: 6)
                    .frame(width: size + 16, height: size + 16)
                    .scaleEffect(pulse ? 1.12 : 0.95)
                    .opacity(pulse ? 0.2 : 0.9)
            }
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
                .background(Circle().fill(deep).offset(y: 5))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 3).padding(4))
            content
        }
        .frame(width: size + 16, height: size + 16)
        .onAppear {
            if state == .current { withMotion(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } }
        }
        .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        switch state {
        case .completed: return AnyShapeStyle(Gradients.gold)
        case .current, .available: return AnyShapeStyle(color.gradient)
        case .locked: return AnyShapeStyle(Palette.line)
        }
    }

    private var deep: Color {
        switch state {
        case .completed: return BrandColor.gold.deep
        case .current, .available: return color.deep
        case .locked: return Palette.inkFaint.opacity(0.4)
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark").font(.system(size: size * 0.38, weight: .heavy)).foregroundStyle(.white)
        case .locked:
            Image(systemName: "lock.fill").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(Palette.inkFaint)
        default:
            LessonGlyph(lesson: lesson, size: size * 0.8, onColor: color.onColor)
        }
    }
}

/// What a lesson holds, and Start.
struct LessonPreviewSheet: View {
    let lesson: Lesson
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let module = store.curriculum.module(of: lesson.id)
        let color = BrandColor(named: module?.color ?? "pomegranate")
        let state = store.state(of: lesson)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    PathNode(lesson: lesson, state: state == .completed ? .completed : .available, color: color, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module?.title ?? "").font(.captionBold).textCase(.uppercase).foregroundStyle(color.color)
                        Text(lesson.title).font(.titleBold).foregroundStyle(Palette.ink)
                        Text(kindLabel).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                    }
                }
                Text("You'll learn").font(.headlineRounded).foregroundStyle(Palette.ink)
                FlowLayout(spacing: 8, alignment: .leading) {
                    ForEach(previewItems, id: \.self) { item in
                        Text(item)
                            .font(.system(.callout, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(color.color.opacity(0.13)))
                    }
                }
                HStack(spacing: 12) {
                    Pill(text: "Up to \(XPRules.lessonComplete + 20) XP", color: Palette.gold, symbol: "bolt.fill")
                    if state == .completed { Pill(text: "Done: practise again", color: Palette.success, symbol: "checkmark") }
                }
                Button {
                    Haptics.tap()
                    navigator.start(lesson)
                } label: {
                    Label(state == .completed ? "Practise again" : "Start", systemImage: "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: color))
                .accessibilityIdentifier("start-lesson")
            }
            .padding(24)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var kindLabel: String {
        switch lesson.kind {
        case .letters: return lesson.letters?.isEmpty == false ? "New letters and your first reading" : "Reading practice"
        case .contrast: return "Sound pairs"
        case .vocabulary: return "New words"
        case .phrases: return "Everyday phrases"
        case .grammar: return "Grammar, step by step"
        case .conversation: return "A conversation"
        }
    }

    private var previewItems: [String] {
        if let letters = lesson.letters, !letters.isEmpty { return letters.map { "\($0)  \(store.curriculum.letter($0)?.latin ?? "")" } }
        if let pairs = lesson.pairs { return pairs.map { $0.joined(separator: " / ") } }
        if let read = lesson.read, lesson.kind == .letters { return read.map(\.ka) }
        if let d = lesson.dialogue { return d.lines.filter(\.isLearner).map(\.ka) }
        let words = store.curriculum.words(in: lesson).map { "\($0.ka) · \($0.en)" }
        if !words.isEmpty { return words }
        return lesson.notes?.map(\.title) ?? []
    }
}
