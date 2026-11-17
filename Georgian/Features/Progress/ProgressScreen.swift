import Charts
import SwiftData
import SwiftUI

/// What you know and can do: words, letters, phrases, the course level, the streak, the week
/// in a chart, modules, milestones and the history of lessons. No XP or levels on screen.
struct ProgressScreen: View {
    @Environment(LearningStore.self) private var store
    @State private var range = 7

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    knowCard
                    tiles
                    activityChart
                    modulesCard
                    AchievementsGrid()
                    history
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .gold))
            .navigationTitle(tr("Progress"))
        }
    }

    /// What the learner can do now, in plain words.
    private var knowCard: some View {
        let s = store.snapshot
        let done = s.lessonsCompleted
        let total = max(1, store.curriculum.lessons.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ProgressRing(progress: Double(done.count) / Double(total), lineWidth: 12, colors: [.white, .white.opacity(0.6)]) {
                    Text("\(Int((Double(done.count) / Double(total) * 100).rounded()))%").font(.title3.weight(.bold)).foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("What you can do")).font(.title2Bold).foregroundStyle(.white)
                    Text(cefr).font(.captionBold).foregroundStyle(.white.opacity(0.85)).textCase(.uppercase)
                }
                Spacer(minLength: 0)
            }
            ForEach(canDo(done: done, modules: s.modulesCompleted), id: \.self) { line in
                Label(line, systemImage: "checkmark.circle.fill")
                    .font(.calloutRounded.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .gradientCard(.saperavi)
        .accessibilityElement(children: .combine)
    }

    /// Real things the finished lessons let you do.
    private func canDo(done: Set<String>, modules: Set<String>) -> [String] {
        var out: [String] = []
        if modules.contains("alphabet") { out.append(tr("Read any Georgian word aloud")) }
        else if done.contains("a1") { out.append(tr("Read your first Georgian words")) }
        if done.contains("v1") && done.contains("v2") { out.append(tr("Greet people, thank them and say sorry")) }
        if done.contains("v6c") { out.append(tr("Count, and understand prices up to a hundred")) }
        else if done.contains("v5") { out.append(tr("Count to ten")) }
        if done.contains("e1") || done.contains("c1") { out.append(tr("Order in a café")) }
        if done.contains("e3") || done.contains("c4") { out.append(tr("Take a taxi")) }
        if done.contains("c5") || done.contains("e4") { out.append(tr("Ask the way")) }
        if modules.contains("grammar") { out.append(tr("Build your own simple sentences")) }
        if out.isEmpty { out.append(tr("Finish your first lesson to see what you can do")) }
        return out
    }

    /// A rough course level: A0 until the alphabet is done, then towards A1.
    private var cefr: String {
        let done = store.snapshot.modulesCompleted
        if done.contains("conversation") { return tr("Course level: A1") }
        if done.contains("alphabet") { return tr("Course level: A0+ (heading for A1)") }
        return tr("Course level: A0")
    }

    private var tiles: some View {
        let s = store.snapshot
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(symbol: "flame.fill", value: "\(s.streak)", label: tr("day streak · best {0}", s.longestStreak), color: Palette.flame)
            StatTile(symbol: "star.fill", value: "\(store.savedPhrases.count)", label: tr("phrases saved"), color: Palette.gold)
            StatTile(symbol: "flag.checkered", value: "\(s.lessonsCompleted.count)", label: tr("lessons of {0}", store.curriculum.lessons.count), color: Palette.pomegranate)
            StatTile(symbol: "character.book.closed.fill", value: "\(s.wordsLearned)", label: tr("words learned"), color: Palette.tkemali)
            StatTile(symbol: "textformat", value: "\(s.lettersLearned)/33", label: tr("letters learned"), color: Palette.blacksea)
            StatTile(symbol: "target", value: store.answerTotals.all == 0 ? "–" : "\(Int((store.accuracy * 100).rounded()))%", label: tr("accuracy"), color: Palette.saperavi)
        }
    }

    private var activityChart: some View {
        let data = store.weeklyAnswers(range)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("Activity")).font(.title2Bold).foregroundStyle(Palette.ink)
                Spacer()
                Picker(tr("Range"), selection: $range) {
                    Text(tr("Week")).tag(7)
                    Text(tr("Month")).tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            Chart {
                ForEach(data, id: \.day) { d in
                    BarMark(x: .value(tr("Day"), DayKey.date(d.day) ?? Date(), unit: .day), y: .value(tr("Answers"), d.answers))
                        .foregroundStyle(Palette.pomegranate.opacity(0.75))
                        .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in
                    AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 190)
            .motion(Motion.spring, value: range)
            .accessibilityLabel(tr("Answers per day. {0} active days.", data.filter { $0.answers > 0 }.count))
            Text(tr("{0} answers · {1} active days", data.reduce(0) { $0 + $1.answers }, data.filter { $0.answers > 0 }.count))
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
        }
        .card()
    }

    private var modulesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Modules")).font(.title2Bold).foregroundStyle(Palette.ink)
            ForEach(store.curriculum.modules) { m in
                let done = store.completedCount(in: m)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(m.title, systemImage: m.symbol).font(.headlineRounded).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(done)/\(m.lessons.count)").font(.captionBold).foregroundStyle(Palette.inkSoft)
                    }
                    ProgressBar(progress: Double(done) / Double(max(1, m.lessons.count)), color: BrandColor(named: m.color).color, height: 12)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("History")).font(.title2Bold).foregroundStyle(Palette.ink)
            if store.lessonRecords.isEmpty {
                Text(tr("Finished lessons show up here.")).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
            }
            ForEach(store.lessonRecords.prefix(12), id: \.persistentModelID) { r in
                HStack(spacing: 12) {
                    Image(systemName: r.perfect ? "crown.fill" : "checkmark.circle.fill")
                        .foregroundStyle(r.perfect ? Palette.gold : Palette.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.curriculum.lesson(r.lessonID)?.title ?? r.lessonID).font(.headlineRounded).foregroundStyle(Palette.ink)
                        Text(r.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Text("\(Int((r.accuracy * 100).rounded()))%").font(.captionBold).foregroundStyle(Palette.inkSoft)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

/// Every achievement: unlocked ones in colour, the rest with their progress.
struct AchievementsGrid: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let s = store.snapshot
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("Milestones")).font(.title2Bold).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(store.unlockedAchievementCount)/\(Achievement.all.count)").font(.captionBold).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                ForEach(Achievement.all) { a in
                    AchievementBadge(achievement: a, unlocked: store.achievementDates[a.id] != nil, progress: a.progress(s))
                }
            }
        }
        .card()
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    let progress: Double

    var body: some View {
        let color = BrandColor(named: achievement.color)
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Palette.line.opacity(0.6)))
                    .frame(width: 64, height: 64)
                if !unlocked {
                    Circle().trim(from: 0, to: progress).stroke(color.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 64, height: 64)
                }
                Image(systemName: achievement.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(unlocked ? color.onColor : Palette.inkFaint)
            }
            Text(achievement.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title): \(achievement.detail). \(unlocked ? tr("Unlocked") : tr("{0} percent", Int(progress * 100)))")
    }
}

/// An achievement as a row, for the completion screen.
struct AchievementRow: View {
    let achievement: Achievement
    let unlocked: Bool
    let progress: Double

    var body: some View {
        let color = BrandColor(named: achievement.color)
        HStack(spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color.onColor)
                .frame(width: 54, height: 54)
                .background(Circle().fill(color.gradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("Milestone reached")).font(.captionBold).textCase(.uppercase).foregroundStyle(color.color)
                Text(achievement.title).font(.headlineRounded).foregroundStyle(Palette.ink)
                Text(achievement.detail).font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
