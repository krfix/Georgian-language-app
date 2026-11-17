import SwiftUI

/// Spaced repetition: what's due, the hardest items, and recent mistakes.
struct ReviewView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    if !store.difficultItems.isEmpty { difficult }
                    if !store.recentMistakes.isEmpty { mistakes }
                    lettersCard
                    howItWorks
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .blacksea))
            .navigationTitle("Review")
        }
    }

    private var hero: some View {
        let due = store.dueItems
        let practice = due.isEmpty ? Array(store.weakestItems.prefix(10)) : due
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(due.isEmpty ? "All caught up" : "Due today")
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(due.isEmpty ? "Nothing due" : "\(due.count) \(due.count == 1 ? "item" : "items")")
                        .font(.display)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(due.isEmpty ? (practice.isEmpty ? "Finish a lesson and its words come back here at the right time." : "Practise your weakest words anyway.")
                                     : "Review now, before they slip away.")
                        .font(.calloutRounded)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if due.isEmpty {
                    ParrotView(height: 96, mood: .sleep)
                } else {
                    Borjgali(size: 70, colors: [.white.opacity(0.9), .white.opacity(0.4), .white.opacity(0.9)])
                }
            }
            if !practice.isEmpty {
                Button {
                    Haptics.tap()
                    navigator.review(practice, title: due.isEmpty ? "Practice" : "Daily review")
                } label: {
                    Label(due.isEmpty ? "Practise" : "Start review", systemImage: "play.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: .gold))
                .accessibilityIdentifier("start-review")
            }
        }
        .gradientCard(.blacksea)
    }

    private var difficult: some View {
        let items = Array(store.difficultItems.prefix(8))
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Difficult", trailing: "Practise") {
                navigator.review(items, title: "Difficult words")
            }
            ForEach(items) { item in
                HStack {
                    Text(item.georgian).font(.system(.title3, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(item.latin).font(.caption.italic()).foregroundStyle(Palette.inkSoft)
                    Spacer()
                    Text(item.english).font(.calloutRounded).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.error).accessibilityLabel("difficult")
                }
                .card(padding: 14, cornerRadius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var mistakes: some View {
        let recent = Array(store.recentMistakes.prefix(6))
        let items = recent.compactMap { store.curriculum.item($0.itemID) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Recent mistakes", trailing: items.isEmpty ? nil : "Practise") {
                var seen = Set<String>()
                navigator.review(items.filter { seen.insert($0.id).inserted }, title: "Your mistakes")
            }
            ForEach(Array(recent.enumerated()), id: \.offset) { _, m in
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.prompt).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.error)
                        Text(m.given.isEmpty ? "—" : m.given).strikethrough().foregroundStyle(Palette.inkSoft)
                    }
                    .font(.calloutRounded)
                    if !m.expected.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                            Text(m.expected).foregroundStyle(Palette.ink)
                        }
                        .font(.calloutRounded.weight(.semibold))
                    }
                    Text(m.date.formatted(.relative(presentation: .named))).font(.caption2).foregroundStyle(Palette.inkFaint)
                }
                .card(padding: 14, cornerRadius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var lettersCard: some View {
        let letters = store.curriculum.letters.filter { store.mastery[$0.itemID] != nil }
        return HStack(spacing: 14) {
            Text("ა").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gradients.hero))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Letter workout").font(.headlineRounded).foregroundStyle(Palette.ink)
                Text(letters.isEmpty ? "Meet your first letters in Learn." : "\(letters.count) letters met. Keep them sharp.")
                    .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            if !letters.isEmpty {
                Button {
                    Haptics.tap()
                    navigator.review(Array(letters.shuffled().prefix(12)).map(StudyItem.letter), title: "Letter workout")
                } label: {
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 46, height: 46).background(Circle().fill(Palette.pomegranate))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Start letter workout")
            }
        }
        .card()
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How review works", systemImage: "info.circle.fill").font(.headlineRounded).foregroundStyle(Palette.blacksea)
            Text("Every word and letter has its own schedule. Get it right and it comes back later each time: tomorrow, in three days, then weeks. Miss it and it comes back soon. A few minutes a day keeps everything you've learned.")
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}
