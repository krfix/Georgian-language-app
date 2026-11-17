import SwiftUI

/// The end of a lesson: confetti, the XP counting up, accuracy, streak, the daily goal and
/// any achievements reached.
struct LessonCompleteView: View {
    let reward: LessonReward
    let title: String
    let isReview: Bool
    var isDialogue = false
    let onDone: () -> Void

    @State private var shownXP = 0
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
                        Text(reward.isPerfect ? "Flawless!" : (isDialogue ? "Conversation done!" : isReview ? "Review complete!" : "Lesson complete!"))
                            .font(.display)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                        Text(title)
                            .font(.headlineRounded)
                            .foregroundStyle(Palette.inkSoft)
                        Text("ყოჩაღ! (well done!)")
                            .font(.calloutRounded)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("lesson-complete")

                    HStack(spacing: 12) {
                        rewardTile(symbol: "bolt.fill", value: "+\(shownXP)", label: "XP", color: Palette.gold)
                        rewardTile(symbol: "target", value: "\(Int((reward.accuracy * 100).rounded()))%", label: "Accuracy", color: Palette.tkemali)
                        rewardTile(symbol: "flame.fill", value: "\(reward.streak)", label: "Day streak", color: Palette.flame)
                    }

                    goalCard

                    if reward.challengeCompletedNow {
                        banner(symbol: "trophy.fill", text: "Daily challenge done: +\(XPRules.challengeBonus) XP", color: .saperavi)
                    }
                    if let level = reward.newLevel {
                        banner(symbol: "arrow.up.circle.fill", text: "You reached level \(level)!", color: .blacksea)
                    }
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
                Button("Continue", action: { Haptics.tap(); onDone() })
                    .buttonStyle(ChunkyButtonStyle(color: .tkemali))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("complete-continue")
            }
            ConfettiView()
        }
        .onAppear {
            withMotion(Motion.bouncy) { appeared = true }
            countUp()
        }
    }

    /// The XP climbs to its total.
    private func countUp() {
        let steps = min(reward.xp, 30)
        guard steps > 0 else { return }
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.03) {
                withAnimation(.snappy) { shownXP = reward.xp * i / steps }
                if i % 5 == 0 { Haptics.select() }
            }
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
                Text(progress >= 1 ? (reward.goalReachedNow ? "Daily goal reached!" : "Daily goal done") : "Daily goal")
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.ink)
                Text("\(reward.xpToday) of \(reward.dailyGoal) XP today")
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
