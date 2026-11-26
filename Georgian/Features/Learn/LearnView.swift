import SwiftUI

/// The learning path: five modules, each a winding trail of lesson stones, from the bottom up
/// (KART #15): the first module at the bottom, the supra table at the top. Behind the stones a
/// grapevine runs from stone to stone and under the module cards, where the ribbon used to
/// (KART #8); it hangs purple grapes by the lessons done, green ones by the lesson up next, and
/// leaves and tendrils ahead (VinePath.swift).
struct LearnView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @State private var showAlphabet = LaunchOptions.current.screen == "alphabet"
    @State private var lockedNotice: String?
    /// The lesson the path last scrolled to, so coming back to it doesn't scroll again.
    @State private var scrolledTo: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    path
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                // Bring the next lesson into view the first time the path opens, and again
                // when it changes (a lesson finished), not every time the tab shows: scrolling
                // on return made the big "Learn" title jump (KART #6).
                .onAppear {
                    // The screenshot run can ask for a place on the path: a lesson, the top or the
                    // bottom (`-screen learn -item <where>`).
                    if scrolledTo == nil, LaunchOptions.current.screen == "learn", let item = LaunchOptions.current.item {
                        scrolledTo = store.nextLesson?.id
                        let target = item == "top" ? "vine-top" : (item == "bottom" ? "module-alphabet" : item)
                        let anchor: UnitPoint = item == "top" ? .top : (item == "bottom" ? .bottom : .center)
                        proxy.scrollTo(target, anchor: anchor)
                        DispatchQueue.main.async { proxy.scrollTo(target, anchor: anchor) }
                        return
                    }
                    guard scrolledTo != store.nextLesson?.id else { return }
                    let first = scrolledTo == nil
                    scrolledTo = store.nextLesson?.id
                    if let next = store.nextLesson {
                        if first {
                            // The path grows from the bottom up: open it straight at the lesson
                            // up next, without a long glide down.
                            proxy.scrollTo(next.id, anchor: .center)
                            DispatchQueue.main.async { proxy.scrollTo(next.id, anchor: .center) }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withMotion(Motion.slow) { proxy.scrollTo(next.id, anchor: .center) }
                            }
                        }
                    }
                }
                .onChange(of: store.nextLesson?.id) { _, id in
                    guard let id, id != scrolledTo else { return }
                    scrolledTo = id
                    withMotion(Motion.slow) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .background(AmbientBackground(tint: .saperavi))
            .navigationTitle(tr("Learn"))
            .toolbar {
                // The 33 letters, one tap from anywhere on the path (KART #20).
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showAlphabet = true
                    } label: {
                        // A bare label: iOS 26 draws its round glass button around it. The
                        // letter has no tall parts, so it's lifted a little to sit in the middle.
                        Text("ა")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Palette.pomegranate)
                            .offset(y: -2)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(tr("All 33 letters"))
                    .accessibilityIdentifier("alphabet-shortcut")
                }
            }
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

    /// The supra table at the top, then the modules from the last down to the first, with
    /// the vine behind them.
    private var path: some View {
        VStack(spacing: 26) {
            VineTop(finished: store.nextLesson == nil)
                .padding(.horizontal, -20)
                .id("vine-top")
            ForEach(Array(store.curriculum.modules.enumerated().reversed()), id: \.element.id) { mi, module in
                ModuleSection(module: module, showAlphabet: $showAlphabet) { lesson, state in
                    if state == .locked {
                        Haptics.error()
                        withMotion { lockedNotice = tr("Finish the lessons before \"{0}\" to open it.", lesson.title) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withMotion { lockedNotice = nil } }
                    } else {
                        Haptics.tap()
                        navigator.previewLesson = lesson
                    }
                }
                .accessibilitySortPriority(Double(store.curriculum.modules.count - mi))
            }
        }
        .accessibilityElement(children: .contain)
        // The vine's layers reach out to the screen's edges (past the path's 20-point margins),
        // so leaves near the edge are never cut off by the drawing's own edge.
        .backgroundPreferenceValue(StoneCentres.self) { anchors in
            GeometryReader { geo in
                VineRibbon(layout: vineLayout(anchors, in: geo), vine: vineState)
            }
            .padding(.horizontal, -20)
        }
        .overlayPreferenceValue(StoneCentres.self) { anchors in
            GeometryReader { geo in
                let layout = vineLayout(anchors, in: geo)
                ZStack(alignment: .topLeading) {
                    VineClimb(layout: layout, vine: vineState)
                    // Ara, perched beside the lesson up next.
                    VinePerchView(perch: layout.perch)
                }
            }
            .padding(.horizontal, -20)
            .allowsHitTesting(false)
        }
    }

    private func vineLayout(_ anchors: [String: Anchor<CGPoint>], in geo: GeometryProxy) -> VineLayout {
        var texts: [CGRect] = []
        for lesson in store.curriculum.lessons {
            guard let a = anchors["ta-\(lesson.id)"], let b = anchors["tb-\(lesson.id)"] else { continue }
            let p = geo[a], q = geo[b]
            texts.append(CGRect(x: p.x, y: p.y, width: q.x - p.x, height: q.y - p.y))
        }
        return VineLayout(stops: vineStops(anchors, in: geo), top: topFrame(anchors, in: geo), finished: store.nextLesson == nil,
                          texts: texts, width: geo.size.width)
    }

    /// Every stone in course order (bottom to top on screen), where it sits, its place in the
    /// course and its state.
    private func vineStops(_ anchors: [String: Anchor<CGPoint>], in geo: GeometryProxy) -> [VineStop] {
        let states = store.lessonStates
        var out: [VineStop] = [], k = 0
        for module in store.curriculum.modules {
            for (i, lesson) in module.lessons.enumerated() {
                if let anchor = anchors[lesson.id] {
                    out.append(VineStop(point: geo[anchor], index: k, state: states[lesson.id] ?? .locked, firstInModule: i == 0))
                }
                k += 1
            }
        }
        return out
    }

    private func topFrame(_ anchors: [String: Anchor<CGPoint>], in geo: GeometryProxy) -> CGRect? {
        guard let a = anchors["vine-top-a"], let b = anchors["vine-top-b"] else { return nil }
        let p = geo[a], q = geo[b]
        return CGRect(x: p.x, y: p.y, width: q.x - p.x, height: q.y - p.y)
    }

    /// How far the learner has got, for the vine's colours.
    private var vineState: VineState {
        var k = 0, next: Double?
        let nextID = store.nextLesson?.id
        for module in store.curriculum.modules {
            for lesson in module.lessons {
                if lesson.id == nextID { next = Double(k) }
                k += 1
            }
        }
        return VineState(next: next, lessonCount: Double(k))
    }
}

/// Where each lesson's stone sits, for the ribbon.
struct StoneCentres: PreferenceKey {
    static var defaultValue: [String: Anchor<CGPoint>] = [:]
    static func reduce(value: inout [String: Anchor<CGPoint>], nextValue: () -> [String: Anchor<CGPoint>]) {
        value.merge(nextValue()) { $1 }
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
        VStack(spacing: 0) {
            trail(color: color, states: states)
            // Room under the first lesson for its grapes, above the card.
            Color.clear.frame(height: 76)
            card(color: color, done: done)
                .id("module-\(module.id)")
        }
        .accessibilityElement(children: .contain)
    }

    /// The module's card: what it covers and how far the learner has got. VoiceOver reads it
    /// before the lessons, though it sits below them.
    private func card(color: BrandColor, done: Int) -> some View {
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
        .accessibilitySortPriority(1000)
    }

    /// The trail: stones swing left and right, the module's first lesson at the bottom.
    /// VoiceOver still reads them in course order.
    private func trail(color: BrandColor, states: [String: LessonState]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(module.lessons.enumerated().reversed()), id: \.element.id) { i, lesson in
                let state = states[lesson.id] ?? .locked
                Button { onTap(lesson, state) } label: {
                    HStack(spacing: 14) {
                        PathNode(lesson: lesson, state: state, color: color, size: 72)
                            .anchorPreference(key: StoneCentres.self, value: .center) { [lesson.id: $0] }
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
                        // Its box, so the vine's leaves keep clear of the words.
                        .transformAnchorPreference(key: StoneCentres.self, value: .topLeading) { $0["ta-\(lesson.id)"] = $1 }
                        .transformAnchorPreference(key: StoneCentres.self, value: .bottomTrailing) { $0["tb-\(lesson.id)"] = $1 }
                    }
                    .offset(x: swing(i))
                }
                .buttonStyle(.pressable)
                .id(lesson.id)
                .accessibilityLabel("\(lesson.title). \(lesson.subtitle). \(stateLabel(state))")
                .accessibilityIdentifier("lesson-\(lesson.id)")
                .accessibilitySortPriority(Double(module.lessons.count - i))
                if i > 0 { Color.clear.frame(height: 34) }   // room for the vine between stones
            }
        }
        .frame(maxWidth: .infinity)
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
