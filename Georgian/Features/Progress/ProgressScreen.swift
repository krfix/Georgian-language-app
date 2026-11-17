import Charts
import SwiftData
import SwiftUI

/// Statistics: XP, streak, lessons, words, accuracy, the week in a chart, modules,
/// achievements and the history of lessons.
struct ProgressScreen: View {
    @Environment(LearningStore.self) private var store
    @State private var range = 7

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    levelCard
                    ChallengeCard()
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

    private var levelCard: some View {
        let xp = store.totalXP
        let level = LearnerLevel.level(forXP: xp)
        let next = LearnerLevel.threshold(level + 1)
        return HStack(spacing: 18) {
            ProgressRing(progress: LearnerLevel.progress(forXP: xp), lineWidth: 12, colors: [.white, .white.opacity(0.6)]) {
                VStack(spacing: 0) {
                    Text("\(level)").font(.titleBold).foregroundStyle(.white)
                    Text(tr("level")).font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(levelName(level)).font(.title2Bold).foregroundStyle(.white)
                Text(tr("{0} XP · {1} to level {2}", xp, next - xp, level + 1)).font(.calloutRounded).foregroundStyle(.white.opacity(0.9))
                Text(cefr).font(.captionBold).foregroundStyle(.white.opacity(0.85)).textCase(.uppercase)
            }
            Spacer(minLength: 0)
        }
        .gradientCard(.saperavi)
        .accessibilityElement(children: .combine)
    }

    private func levelName(_ level: Int) -> String {
        let names = [tr("Newcomer"), tr("Letter hunter"), tr("Reader"), tr("Word gatherer"), tr("Phrase maker"), tr("Conversationalist"), tr("Supra guest"), tr("Tamada in training")]
        return names[min(level - 1, names.count - 1)]
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
            StatTile(symbol: "bolt.fill", value: "\(s.totalXP)", label: tr("total XP"), color: Palette.gold)
            StatTile(symbol: "flag.checkered", value: "\(s.lessonsCompleted.count)", label: tr("lessons of {0}", store.curriculum.lessons.count), color: Palette.pomegranate)
            StatTile(symbol: "character.book.closed.fill", value: "\(s.wordsLearned)", label: tr("words learned"), color: Palette.tkemali)
            StatTile(symbol: "textformat", value: "\(s.lettersLearned)/33", label: tr("letters learned"), color: Palette.blacksea)
            StatTile(symbol: "target", value: store.answerTotals.all == 0 ? "–" : "\(Int((store.accuracy * 100).rounded()))%", label: tr("accuracy"), color: Palette.saperavi)
        }
    }

    private var activityChart: some View {
        let data = store.weeklyXP(range)
        let goal = store.profile.dailyGoal
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
                    BarMark(x: .value(tr("Day"), DayKey.date(d.day) ?? Date(), unit: .day), y: .value(tr("XP"), d.xp))
                        .foregroundStyle(d.xp >= goal ? AnyShapeStyle(Gradients.gold) : AnyShapeStyle(Palette.pomegranate.opacity(0.75)))
                        .cornerRadius(6)
                }
                RuleMark(y: .value(tr("Goal"), goal))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .foregroundStyle(Palette.tkemali)
                    .annotation(position: .top, alignment: .leading) {
                        Text(tr("Goal {0} XP", goal)).font(.caption2.weight(.bold)).foregroundStyle(Palette.tkemali)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in
                    AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 190)
            .motion(Motion.spring, value: range)
            .accessibilityLabel(tr("XP per day. {0} active days.", data.filter { $0.xp > 0 }.count))
            Text(tr("{0} XP in the last {1} days · {2} days at goal", data.reduce(0) { $0 + $1.xp }, range, data.filter { $0.xp >= goal }.count))
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(tr("+{0} XP", r.xp)).font(.captionBold).foregroundStyle(Palette.gold)
                        Text("\(Int((r.accuracy * 100).rounded()))%").font(.caption).foregroundStyle(Palette.inkSoft)
                    }
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
                Text(tr("Achievements")).font(.title2Bold).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(store.achievementDates.count)/\(Achievement.all.count)").font(.captionBold).foregroundStyle(Palette.inkSoft)
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
                Text(tr("Achievement unlocked")).font(.captionBold).textCase(.uppercase).foregroundStyle(color.color)
                Text(achievement.title).font(.headlineRounded).foregroundStyle(Palette.ink)
                Text(achievement.detail).font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
