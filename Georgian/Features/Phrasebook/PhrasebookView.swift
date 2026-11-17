import SwiftUI

/// Use in Georgia: the everyday companion. Search, emergencies, the learner's own
/// phrasebook, every situation as a tile and the conversations. Nothing to unlock.
struct PhrasebookView: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var nav = navigator
        NavigationStack(path: $nav.phrasebookPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    SearchBarButton { navigator.search() }
                    EmergencyStrip()
                    MyPhrasebookCard()
                    SectionTitle(title: tr("Situations"))
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.phrasebook.categories.filter { !$0.isEmergency }) { c in
                            NavigationLink(value: PhrasebookRoute.category(c.id)) {
                                CategoryTile(category: c, count: store.phrasebook.phrases(in: c.id).count)
                            }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("category-\(c.id)")
                        }
                    }
                    SectionTitle(title: tr("Conversations"))
                    Text(tr("Real everyday exchanges. Read them, listen, then play either side."))
                        .font(.calloutRounded)
                        .foregroundStyle(Palette.inkSoft)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.phrasebook.dialogues) { d in
                                NavigationLink(value: PhrasebookRoute.dialogue(d.id)) { DialogueCard(dialogue: d) }
                                    .buttonStyle(.pressable)
                                    .accessibilityIdentifier("dialogue-\(d.id)")
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                    ContentCheckNote()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AmbientBackground(tint: .gold))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PhrasebookRoute.self) { route in
                switch route {
                case .category(let id):
                    if let c = store.phrasebook.category(id) { CategoryView(category: c) }
                case .dialogue(let id):
                    if let d = store.phrasebook.dialogue(id) { DialogueView(dialogue: d) }
                case .saved:
                    MyPhrasebookView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("საქართველოში")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.pomegranate)
            Text(tr("Use in Georgia"))
                .font(.display)
                .foregroundStyle(Palette.ink)
            Text(tr("The right words for everyday situations, ready when you need them."))
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Emergencies, always one tap away and set apart in red, with 112 to call.
struct EmergencyStrip: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                navigator.open(category: "emergency")
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.2)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Emergency phrases")).font(.headlineRounded).foregroundStyle(.white)
                        Text(tr("Help, police, accidents, lost")).font(.caption).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("emergency-open")
            Link(destination: URL(string: "tel:112")!) {
                VStack(spacing: 0) {
                    Image(systemName: "phone.fill").font(.system(size: 15, weight: .bold))
                    Text("112").font(.system(.headline, design: .rounded, weight: .heavy))
                }
                .foregroundStyle(Palette.error)
                .frame(width: 64, height: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
            }
            .accessibilityLabel(tr("Call 112, the emergency number"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE5484D), Color(hex: 0xB4232F)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(hex: 0xE5484D).opacity(0.3), radius: 12, y: 6)
        )
    }
}

/// The learner's own phrasebook: how many saved, how many in review.
struct MyPhrasebookCard: View {
    @Environment(LearningStore.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let saved = store.savedPhrases.count
        Button {
            Haptics.tap()
            navigator.openSaved()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Gradients.gold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("My phrasebook")).font(.headlineRounded).foregroundStyle(Palette.ink)
                    Text(saved == 0 ? tr("Tap ☆ on any phrase to keep it here.") :
                            tr("{0} saved · {1} in review", saved, store.practisingPhraseCount))
                        .font(.calloutRounded)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.callout.weight(.bold)).foregroundStyle(Palette.inkFaint)
            }
            .card(padding: 14, cornerRadius: 22)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("my-phrasebook")
    }
}

/// One situation: its phrases by subcategory (a chip row jumps between them), and its
/// conversations.
struct CategoryView: View {
    let category: PhraseCategory
    @Environment(LearningStore.self) private var store
    @State private var sub: String?

    var body: some View {
        let brand = category.brand
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if category.isEmergency { callCard }
                chips
                ForEach(category.subs.filter { sub == nil || $0.id == sub }) { s in
                    let list = store.phrasebook.phrases(in: category.id, sub: s.id)
                    if !list.isEmpty {
                        Text(s.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(brand.color)
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(list) { p in PhraseRow(phrase: p) }
                    }
                }
                let dialogues = store.phrasebook.dialogues(in: category.id)
                if !dialogues.isEmpty && sub == nil {
                    SectionTitle(title: tr("Conversations"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(dialogues) { d in
                                NavigationLink(value: PhrasebookRoute.dialogue(d.id)) { DialogueCard(dialogue: d) }
                                    .buttonStyle(.pressable)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                if category.id == "health" {
                    Label(tr("These phrases help you describe a problem. They are not medical advice. In an emergency, call 112."),
                          systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }
                ContentCheckNote()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(AmbientBackground(tint: brand))
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.ka)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(category.brand.onColor.opacity(0.9))
                Text(category.title)
                    .font(.titleBold)
                    .foregroundStyle(category.brand.onColor)
                Text(category.blurb)
                    .font(.calloutRounded)
                    .foregroundStyle(category.brand.onColor.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: category.symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(category.brand.onColor)
                .frame(width: 72, height: 72)
                .background(Circle().fill(category.brand.onColor.opacity(0.18)))
        }
        .gradientCard(category.brand)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var callCard: some View {
        Link(destination: URL(string: "tel:112")!) {
            Label(tr("Call 112: ambulance, police, fire"), systemImage: "phone.fill")
        }
        .buttonStyle(ChunkyButtonStyle(color: .pomegranate))
        .accessibilityIdentifier("call-112")
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(tr("All"), id: nil)
                ForEach(category.subs) { s in chip(s.title, id: s.id) }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: String, id: String?) -> some View {
        let selected = sub == id
        let color = category.brand.color
        return Button {
            Haptics.select()
            withMotion { sub = id }
        } label: {
            Text(title)
                .font(.calloutRounded.weight(.semibold))
                .foregroundStyle(selected ? category.brand.onColor : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(selected ? AnyShapeStyle(category.brand.fill) : AnyShapeStyle(color.opacity(0.12))))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("sub-\(id ?? "all")")
    }
}
