import SwiftUI

/// The end of a lesson: confetti, accuracy, the streak, the words this lesson showed for the
/// first time (KART #20; after a review, the words you know), the warm-up, the daily goal
/// and any milestones reached. No XP on screen (KART #4): learning, not points.
struct LessonCompleteView: View {
    let reward: LessonReward
    let title: String
    let isReview: Bool
    var isDialogue = false
    let onDone: () -> Void

    @State private var appeared = false
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio

    /// A lesson of the course (not a review or a phrasebook conversation).
    private var isLesson: Bool { !isReview && !isDialogue }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Borjgali(size: 190)
                            .opacity(0.9)
                        ParrotView(height: 150, mood: .cheer)
                            .scaleEffect(appeared ? 1 : 0.3)
                            .rotationEffect(.degrees(appeared ? 0 : -25))
                        if reward.isPerfect {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40, weight: .black))
                                .foregroundStyle(Gradients.gold)
                                .offset(x: 6, y: -92)
                                .scaleEffect(appeared ? 1 : 0.2)
                        }
                    }
                    .padding(.top, 30)
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text(reward.isPerfect ? tr("Flawless!") : (isDialogue ? tr("Conversation done!") : isReview ? tr("Review complete!") : tr("Lesson complete!")))
                            .font(.display)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                        Text(title)
                            .font(.headlineRounded)
                            .foregroundStyle(Palette.inkSoft)
                        Text(tr("ყოჩაღ! (well done!)"))
                            .font(.calloutRounded)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("lesson-complete")

                    if isLesson && !reward.newWords.isEmpty { newWordsCard }
                    if reward.warmUpCount > 0 { warmUpCard }

                    HStack(spacing: 12) {
                        rewardTile(symbol: "target", value: "\(Int((reward.accuracy * 100).rounded()))%", label: tr("Accuracy"), color: Palette.tkemali)
                        if !isLesson {
                            rewardTile(symbol: "character.book.closed.fill", value: "\(reward.wordsKnown)", label: tr("Words you know"), color: Palette.saperavi)
                        }
                        rewardTile(symbol: "flame.fill", value: "\(reward.streak)", label: tr("Day streak"), color: Palette.flame)
                    }

                    if isLesson { allWordsCard }

                    goalCard

                    ForEach(reward.achievements) { a in
                        AchievementRow(achievement: a, unlocked: true, progress: 1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            VStack {
                Spacer()
                Button(tr("Continue"), action: { Haptics.tap(); onDone() })
                    .buttonStyle(ChunkyButtonStyle(color: .tkemali))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("complete-continue")
            }
            ConfettiView()
        }
        .onAppear {
            withMotion(Motion.bouncy) { appeared = true }
        }
    }

    private func rewardTile(symbol: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(color)
            Text(value).font(.title2Bold).foregroundStyle(Palette.ink).contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(color.opacity(0.5), lineWidth: 2))
        .accessibilityElement(children: .combine)
    }

    /// The words this lesson showed for the first time, as chips: tap one to hear it.
    private var newWordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plural(reward.newWords.count, "new word", "new words", pl: ("nowe słowo", "nowe słowa", "nowych słów")))
                .font(.headlineRounded)
                .foregroundStyle(Palette.ink)
            FlowLayout(spacing: 8, rowSpacing: 8, alignment: .leading) {
                ForEach(reward.newWords) { w in
                    Button {
                        Haptics.tap()
                        audio.play(w.ka)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(w.ka).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(w.en).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.saperavi.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.saperavi.opacity(0.3), lineWidth: 1.5))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(w.ka), \(w.en)")
                    .accessibilityHint(tr("Plays the word"))
                }
            }
            Text(tr("They're in your Words list now. Tap one to hear it."))
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityIdentifier("complete-new-words")
    }

    /// The warm-up before the lesson: how many came back, and which are known now.
    private var warmUpCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.success)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Palette.success.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Warm-up: {0}", plural(reward.warmUpCount, "word came back", "words came back",
                                               pl: ("słowo wróciło", "słowa wróciły", "słów wróciło"))))
                    .font(.headlineRounded).foregroundStyle(Palette.ink)
                if !reward.warmUpKnown.isEmpty {
                    Text(tr("Known now: {0}", reward.warmUpKnown.map(\.georgian).joined(separator: ", ")))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    /// All the learner's words: seen, practising and known, in one bar.
    private var allWordsCard: some View {
        let c = store.wordCounts
        let met = c.seen + c.practising + c.known
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("All your words: {0} seen · {1} known", met, c.known))
                .font(.headlineRounded).foregroundStyle(Palette.ink)
            WordStepsBar(counts: c, height: 8)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var goalCard: some View {
        let progress = Double(reward.xpToday) / Double(max(1, reward.dailyGoal))
        return HStack(spacing: 16) {
            ProgressRing(progress: appeared ? progress : 0, lineWidth: 10) {
                Image(systemName: progress >= 1 ? "checkmark" : "target")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(progress >= 1 ? Palette.success : Palette.gold)
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(progress >= 1 ? (reward.goalReachedNow ? tr("Daily goal reached!") : tr("Daily goal done")) : tr("Daily goal"))
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.ink)
                Text(progress >= 1 ? tr("Done for today. ყოჩაღ!") : tr("{0}% of today's goal", Int((progress * 100).rounded())))
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func banner(symbol: String, text: String, color: BrandColor) -> some View {
        Label(text, systemImage: symbol)
            .font(.headlineRounded)
            .foregroundStyle(color.onColor)
            .gradientCard(color, padding: 16, cornerRadius: 20)
    }
}
