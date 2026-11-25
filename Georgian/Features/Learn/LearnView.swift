import SwiftUI

/// The learning path as a grapevine (KART #15, docs/vine-path.md): it grows from the bottom
/// up, the first module at the bottom. Lessons done are grape bunches (green when just done,
/// ripening to purple), the lesson up next a fresh leaf with Ara perched beside it, locked
/// ones buds; each module's card hangs from a trellis bar, and the supra table waits at the
/// top. The vine itself is drawn in VinePath.swift.
struct LearnView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var showAlphabet = LaunchOptions.current.screen == "alphabet"
    @State private var lockedNotice: String?
    /// The lesson the path last scrolled to, so coming back to it doesn't scroll again.
    @State private var scrolledTo: String?
    /// The lesson Ara sits beside. It follows the next lesson with a hop, a moment after the
    /// path shows again.
    @State private var perchID: String?
    @Namespace private var perchSpace
    /// Rows grow with larger text.
    @ScaledMetric(relativeTo: .headline) private var rowHeight: CGFloat = 92

    var body: some View {
        let modules = store.curriculum.modules
        let states = store.lessonStates
        let firsts = moduleFirstIndices(modules)
        let total = modules.reduce(0) { $0 + $1.lessons.count }
        let next = store.nextLesson
        let nextIndex = next.flatMap { lesson in courseIndex(of: lesson.id, modules, firsts) }
        let vine = VineState(next: nextIndex.map(Double.init), lessonCount: Double(total))
        let last = modules.count - 1
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let top = modules.last {
                            VineTop(lastModuleFirst: firsts[last], lastModuleCount: top.lessons.count, rowHeight: rowHeight,
                                    vine: vine, finished: next == nil)
                                .accessibilitySortPriority(0)
                        }
                        ForEach(Array(modules.enumerated().reversed()), id: \.element.id) { mi, module in
                            ForEach(Array(module.lessons.enumerated().reversed()), id: \.element.id) { i, lesson in
                                let state = states[lesson.id] ?? .locked
                                let spot = VineSpot(lesson: lesson, index: firsts[mi] + i, indexInModule: i, moduleFirst: firsts[mi],
                                                    moduleCount: module.lessons.count, isTopModule: mi == last, state: state, vine: vine)
                                VineLessonRow(spot: spot, rowHeight: rowHeight, showsPerch: perchID == lesson.id,
                                              perchSpace: perchSpace) { tap(lesson, state) }
                                    .id(lesson.id)
                                    .accessibilityLabel("\(lesson.title). \(lesson.subtitle). \(stateLabel(state))")
                                    .accessibilityIdentifier("lesson-\(lesson.id)")
                                    .accessibilitySortPriority(Double(total - spot.index))
                            }
                            VineModuleBase(firstIndex: firsts[mi], count: module.lessons.count, isTopModule: mi == last,
                                           rowHeight: rowHeight, vine: vine) {
                                ModuleCard(module: module, showAlphabet: $showAlphabet)
                            }
                            .accessibilitySortPriority(Double(total - firsts[mi]) + 0.5)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                // Bring the next lesson into view the first time the path opens, and again
                // when it changes (a lesson finished), not every time the tab shows: scrolling
                // on return made the big "Learn" title jump (KART #6).
                .onAppear {
                    if perchID == nil { perchID = next?.id }
                    if perchID != next?.id {
                        // Back from a lesson: Ara hops up to the new leaf.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withMotion(Motion.bouncy) { perchID = store.nextLesson?.id }
                        }
                    }
                    guard scrolledTo != next?.id else { return }
                    scrolledTo = next?.id
                    if let next {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withMotion(Motion.slow) { proxy.scrollTo(next.id, anchor: .center) }
                        }
                    }
                }
                .onChange(of: store.nextLesson?.id) { _, id in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withMotion(Motion.bouncy) { perchID = id }
                    }
                    guard let id, id != scrolledTo else { return }
                    scrolledTo = id
                    withMotion(Motion.slow) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .background(AmbientBackground(tint: .saperavi))
            .navigationTitle(tr("Learn"))
            .navigationBarTitleDisplayMode(.inline)
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

    private func tap(_ lesson: Lesson, _ state: LessonState) {
        if state == .locked {
            Haptics.error()
            withMotion { lockedNotice = tr("Finish the lessons before \"{0}\" to open it.", lesson.title) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withMotion { lockedNotice = nil } }
        } else {
            Haptics.tap()
            navigator.previewLesson = lesson
        }
    }

    /// Where each module's first lesson is in the whole course.
    private func moduleFirstIndices(_ modules: [CourseModule]) -> [Int] {
        var out: [Int] = [], k = 0
        for m in modules { out.append(k); k += m.lessons.count }
        return out
    }

    private func courseIndex(of id: String, _ modules: [CourseModule], _ firsts: [Int]) -> Int? {
        for (mi, m) in modules.enumerated() {
            if let i = m.lessons.firstIndex(where: { $0.id == id }) { return firsts[mi] + i }
        }
        return nil
    }
}

/// A module's card, in its colour: title, what it covers, progress, and for the alphabet the
/// chart of all 33 letters.
private struct ModuleCard: View {
    let module: CourseModule
    @Binding var showAlphabet: Bool
    @Environment(LearningStore.self) private var store

    var body: some View {
        let color = BrandColor(named: module.color)
        let done = store.completedCount(in: module)
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
                    Label(tr("All 33 letters"), systemImage: "square.grid.3x3.fill")
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
                Text(tr("You'll learn")).font(.headlineRounded).foregroundStyle(Palette.ink)
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
                if state == .completed { Pill(text: tr("Done: practise again"), color: Palette.success, symbol: "checkmark") }
            }
            .padding(24)
        }
        // Start stays on screen at the bottom of the sheet, however long the list of words
        // is and whether the sheet is half or fully open.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                Haptics.tap()
                navigator.start(lesson)
            } label: {
                Label(state == .completed ? tr("Practise again") : tr("Start"), systemImage: "play.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: color))
            .accessibilityIdentifier("start-lesson")
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Palette.background.opacity(0.96).ignoresSafeArea())
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var kindLabel: String {
        switch lesson.kind {
        case .letters: return lesson.letters?.isEmpty == false ? tr("New letters and your first reading") : tr("Reading practice")
        case .contrast: return tr("Sound pairs")
        case .vocabulary: return tr("New words")
        case .phrases: return tr("Everyday phrases")
        case .grammar: return tr("Grammar, step by step")
        case .conversation: return tr("A conversation")
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
