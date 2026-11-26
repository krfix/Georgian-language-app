import SwiftUI
import UIKit

/// A phrase's full card: the Georgian large with its sound and meaning; one row of actions
/// (show it, save it, practise it, mark it learned, copy it); how to say it; when to use it;
/// other ways to say it; replies you may hear; and the course words and grammar inside it.
struct PhraseDetailView: View {
    let phrase: Phrase
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioService.self) private var audio
    @State private var showing = false
    /// Said once when the card opens (automatic playback), not again on coming back to it.
    @State private var spoke = false
    @State private var toast: String?
    @State private var newListName = ""
    @State private var askListName = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    actions
                    sayIt
                    wordByWord
                    if phrase.note != nil || phrase.lit != nil || phrase.register != nil { usage }
                    if let v = phrase.variants, !v.isEmpty { forms(tr("Other ways to say it"), v, symbol: "arrow.triangle.branch") }
                    if let r = phrase.replies, !r.isEmpty { forms(tr("You may hear"), r, symbol: "ear.fill") }
                    if !linkedWords.isEmpty { wordsCard }
                    if !grammar.isEmpty { grammarCard }
                    if store.isPractising(phrase.id) { reviewCard }
                    ReportMistakeButton {
                        ReportSubject(title: tr("the phrase {0}", phrase.ka), lines: [phrase.ka, phrase.lat, phrase.en], id: phrase.id)
                    }
                }
                .padding(20)
            }
            .background(AmbientBackground(tint: brand).ignoresSafeArea())
            .onAppear {
                guard !spoke else { return }
                spoke = true
                audio.autoSay(phrase.ka)
            }
            .navigationTitle(store.phrasebook.category(phrase.category)?.title ?? tr("Phrase"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Done")) { dismiss() }.accessibilityIdentifier("phrase-done")
                }
            }
            .overlay(alignment: .bottom) {
                if let toast { Toast(text: toast).padding(.bottom, 20) }
            }
            .fullScreenCover(isPresented: $showing) { ShowPhraseView(phrase: phrase) }
            .alert(tr("New list"), isPresented: $askListName) {
                TextField(tr("For example: At the bazaar"), text: $newListName)
                Button(tr("Add")) {
                    if !newListName.trimmingCharacters(in: .whitespaces).isEmpty {
                        store.move(phrase, toList: newListName)
                        flash(tr("Added to {0}", newListName.trimmingCharacters(in: .whitespaces)))
                    }
                    newListName = ""
                }
                Button(tr("Cancel"), role: .cancel) { newListName = "" }
            } message: {
                Text(tr("A list of your own in your phrasebook."))
            }
        }
        .onAppear { store.noteOpened(phrase) }
    }

    private var brand: BrandColor { phrase.urgent ? .pomegranate : store.phrasebook.brand(of: phrase) }

    // MARK: The phrase

    private var hero: some View {
        VStack(spacing: 10) {
            if phrase.urgent {
                Label(tr("Emergency · call 112"), systemImage: "exclamationmark.triangle.fill")
                    .font(.captionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.22)))
            }
            FittedGeorgianText(phrase.ka, maxSize: 40, color: .white)
                .accessibilityIdentifier("phrase-georgian")
            Text(phrase.lat)
                .font(.headlineRounded)
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
            Text(phrase.en)
                .font(.title2Bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let r = phrase.register {
                Pill(text: r.title, color: .white, symbol: r == .polite ? "hand.raised.fill" : "face.smiling")
            }
            SpeakerButton(text: phrase.ka, size: 46, showsSource: true, onColor: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .gradientCard(brand, padding: 22)
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        let saved = store.isSaved(phrase.id)
        let practising = store.isPractising(phrase.id)
        let learned = store.isLearned(phrase.id)
        return VStack(spacing: 12) {
          HStack(spacing: 8) {
            ActionTile(symbol: "textformat.size", title: tr("Show"), color: brand.color, id: "action-show") {
                showing = true
            }
            ActionTile(symbol: saved ? "star.fill" : "star", title: saved ? tr("Saved") : tr("Save"), color: Palette.gold,
                       active: saved, id: "action-save") {
                store.toggleSaved(phrase)
                flash(saved ? tr("Removed from your phrasebook") : tr("Saved to your phrasebook"))
            }
            ActionTile(symbol: practising ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath",
                       title: practising ? tr("In review") : tr("Practise"), color: Palette.blacksea, active: practising,
                       id: "action-practise") {
                if !practising {
                    store.practiseLater(phrase)
                    flash(tr("Added to your review"))
                }
            }
            ActionTile(symbol: learned ? "checkmark.seal.fill" : "checkmark.seal", title: tr("Learned"), color: Palette.tkemali,
                       active: learned, id: "action-learned") {
                store.setLearned(phrase, !learned)
                flash(learned ? tr("Not marked as learned") : tr("Marked as learned"))
            }
            ActionTile(symbol: "doc.on.doc", title: tr("Copy"), color: Palette.saperavi, id: "action-copy") {
                UIPasteboard.general.string = phrase.ka
                flash(tr("Georgian copied"))
            }
          }
          Menu { listMenu } label: {
              let list = store.list(of: phrase.id)
              Label(list.isEmpty ? tr("Add to a list") : tr("In your list: {0}", list), systemImage: "folder.badge.plus")
                  .font(.calloutRounded.weight(.semibold))
                  .foregroundStyle(Palette.saperavi)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 10)
                  .background(Capsule().fill(Palette.saperavi.opacity(0.10)))
          }
          .accessibilityIdentifier("action-list")
        }
    }

    @ViewBuilder private var listMenu: some View {
        if !store.list(of: phrase.id).isEmpty {
            Button(tr("No list"), systemImage: "folder") { store.move(phrase, toList: ""); flash(tr("Kept in your phrasebook")) }
        }
        ForEach(store.phraseLists, id: \.self) { name in
            Button(name) { store.move(phrase, toList: name); flash(tr("Added to {0}", name)) }
        }
        Button(tr("New list…"), systemImage: "plus") { askListName = true }
    }

    // MARK: Saying it and using it

    /// Every word of the phrase: what it is and why it looks like this.
    @ViewBuilder private var wordByWord: some View {
        let words = Curriculum.wordsForTapping(phrase.ka).compactMap { w in store.curriculum.gloss(w).map { (Curriculum.glossaryKey(w), $0) } }
        if words.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Label(tr("Word by word"), systemImage: "text.magnifyingglass").font(.headlineRounded).foregroundStyle(Palette.saperavi)
                ForEach(Array(words.enumerated()), id: \.offset) { _, pair in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(pair.0).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(pair.1.lat).font(.caption.italic()).foregroundStyle(Palette.inkSoft)
                            Spacer(minLength: 4)
                            Text(pair.1.meaning ?? pair.1.baseMeaning ?? "").font(.calloutRounded).foregroundStyle(Palette.saperavi)
                                .multilineTextAlignment(.trailing)
                        }
                        if let base = pair.1.base, pair.1.meaning == nil || pair.1.baseMeaning != nil {
                            Text(tr("From {0}", base + (pair.1.baseMeaning.map { " (\($0))" } ?? "")))
                                .font(.caption).foregroundStyle(Palette.inkSoft)
                        }
                        if let note = pair.1.note {
                            Text(note).font(.caption).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }

    private var sayIt: some View {
        let hints = Pronunciation.hints(for: phrase.ka, in: store.curriculum)
        return VStack(alignment: .leading, spacing: 8) {
            Label(tr("Say it"), systemImage: "waveform").font(.headlineRounded).foregroundStyle(Palette.blacksea)
            Text(phrase.sound)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(tr("Sounds like {0}", phrase.sound))
            Text(tr("A rough English sound-alike. Vowels are short and clear (ah, eh, ee, oh, oo); stress is light, so give every syllable the same weight."))
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(hints, id: \.self) {
                Text($0).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
            }
        }
        .card()
    }

    private var usage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("When to use it"), systemImage: "lightbulb.fill").font(.headlineRounded).foregroundStyle(Palette.gold)
            if let note = phrase.note {
                Text(note).font(.bodyRounded).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            if let lit = phrase.lit {
                (Text(tr("Literally: ")).bold() + Text(lit))
                    .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
            }
            if let r = phrase.register {
                (Text("\(r.title): ").bold() + Text(r.explanation))
                    .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func forms(_ title: String, _ list: [PhraseForm], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headlineRounded).foregroundStyle(Palette.saperavi)
            ForEach(list, id: \.ka) { f in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = f.label {
                            Text(label).font(.captionBold).foregroundStyle(Palette.saperavi).textCase(.uppercase)
                        }
                        Text(f.ka).font(.system(.title3, weight: .bold)).foregroundStyle(Palette.ink)
                        Text(f.lat).font(.caption.italic()).foregroundStyle(Palette.inkSoft)
                        Text(f.en).font(.calloutRounded).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 8)
                    PlayButton(text: f.ka, size: 36)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    // MARK: Learning from it

    private var linkedWords: [Word] { (phrase.words ?? []).compactMap(store.curriculum.word) }

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("Learn the words"), systemImage: "character.book.closed.fill").font(.headlineRounded).foregroundStyle(Palette.tkemali)
            Text(tr("These words from the phrase are in the course."))
                .font(.caption).foregroundStyle(Palette.inkSoft)
            FlowLayout(spacing: 8, alignment: .leading) {
                ForEach(linkedWords) { w in
                    NavigationLink {
                        WordDetailView(word: w)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(w.ka).font(.system(.callout, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(w.en).font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.tkemali.opacity(0.12)))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("linked-\(w.id)")
                }
            }
        }
        .card()
    }

    private var grammar: [(Lesson, String)] {
        (phrase.grammar ?? []).compactMap { g in store.curriculum.lesson(g.lesson).map { ($0, g.why) } }
    }

    private var grammarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("The grammar behind it"), systemImage: "puzzlepiece.fill").font(.headlineRounded).foregroundStyle(Palette.saperavi)
            ForEach(grammar, id: \.0.id) { lesson, why in
                Button {
                    Haptics.tap()
                    navigator.preview(lesson)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BrandColor.saperavi.gradient))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Lesson: {0}", lesson.title)).font(.headlineRounded).foregroundStyle(Palette.ink)
                            Text(why).font(.caption).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .card()
    }

    private var reviewCard: some View {
        let m = store.mastery[phrase.id]
        return HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.blacksea)
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("In your review")).font(.headlineRounded).foregroundStyle(Palette.ink)
                if let m {
                    Text(m.due <= Date() ? tr("Due now: it's waiting in Review.") : tr("Next review {0}.", m.due.relativeInAppLanguage))
                        .font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            Button(tr("Stop")) { store.stopPractising(phrase); flash(tr("Taken out of your review")) }
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .card()
    }

    private func flash(_ text: String) {
        Haptics.success()
        withMotion { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withMotion { if toast == text { toast = nil } } }
    }
}

/// One of the phrase card's actions: an icon in a soft square with its name under it.
private struct ActionTile: View {
    let symbol: String
    let title: String
    let color: Color
    var active = false
    let id: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(active ? .white : color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(active ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.14))))
                    .symbolEffect(.bounce, value: active)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
