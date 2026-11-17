import SwiftUI

/// The end of a lesson: confetti, accuracy, the words you know, the streak, the daily goal
/// and any milestones reached. No XP on screen (KART #4): learning, not points.
struct LessonCompleteView: View {
    let reward: LessonReward
    let title: String
    let isReview: Bool
    var isDialogue = false
    let onDone: () -> Void

    @State private var appeared = false

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

                    HStack(spacing: 12) {
                        rewardTile(symbol: "target", value: "\(Int((reward.accuracy * 100).rounded()))%", label: tr("Accuracy"), color: Palette.tkemali)
                        rewardTile(symbol: "character.book.closed.fill", value: "\(reward.wordsKnown)", label: tr("Words you know"), color: Palette.saperavi)
                        rewardTile(symbol: "flame.fill", value: "\(reward.streak)", label: tr("Day streak"), color: Palette.flame)
                    }

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
