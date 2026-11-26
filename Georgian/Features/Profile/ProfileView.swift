import SwiftUI

/// Name, level, goal and settings: audio, haptics, reminders, appearance, and a fresh start.
struct ProfileView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmReset = false
    @State private var reminderDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Text(store.profile.name.isEmpty ? "ა" : String(store.profile.name.prefix(1)).uppercased())
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Gradients.hero))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(tr("Your name"), text: $name)
                                .font(.title3.weight(.bold))
                                .submitLabel(.done)
                                .onSubmit(saveName)
                                .accessibilityIdentifier("profile-name")
                            Text(tr("{0}-day streak", store.streak) + " · " + plural(store.snapshot.wordsLearned, "word known", "words known", pl: ("znane słowo", "znane słowa", "znanych słów")))
                                .font(.caption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section(tr("Learning")) {
                    Picker(tr("Daily goal"), selection: goalBinding) {
                        ForEach(DailyGoal.allCases) { g in
                            Text(g.title + " · " + g.minutes).tag(g.rawValue)
                        }
                    }
                    Picker(tr("Starting point"), selection: levelBinding) {
                        ForEach(StartingLevel.allCases) { l in Text(l.title).tag(l.rawValue) }
                    }
                    NavigationLink {
                        ScrollView { AchievementsGrid().padding(20) }
                            .background(Palette.background.ignoresSafeArea())
                            .navigationTitle(tr("Milestones"))
                    } label: {
                        LabeledContent(tr("Milestones"), value: tr("{0} of {1}", store.unlockedAchievementCount, Achievement.all.count))
                    }
                    LabeledContent(tr("Lessons finished"), value: tr("{0} of {1}", store.completedLessons.count, store.curriculum.lessons.count))
                    LabeledContent(tr("Words learned"), value: "\(store.snapshot.wordsLearned)")
                }

                Section {
                    LabeledContent(tr("Phrases"), value: tr("{0} in {1} situations", store.phrasebook.phrases.count, store.phrasebook.categories.count))
                    LabeledContent(tr("Saved"), value: "\(store.savedPhrases.count)")
                    LabeledContent(tr("Checked by"), value: store.phrasebook.isNativeChecked ? tr("A native speaker") : tr("With the help of AI"))
                } header: {
                    Text(tr("Phrasebook"))
                } footer: {
                    Text(tr("Everything works offline: phrases, search, audio and your saved phrases are all on this iPhone."))
                }

                Section {
                    Toggle(tr("Slower Georgian audio"), isOn: binding(\.slowAudio) { audio.slow = $0 })
                    if audio.syntheticClipCount > 0 {
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text(tr("Every Georgian word and sentence in the app is spoken in this voice. Tap Listen to hear each one."))
                                        .font(.bodyRounded)
                                        .foregroundStyle(Palette.inkSoft)
                                    VoicePicker()
                                }
                                .padding(20)
                            }
                            .background(Palette.background.ignoresSafeArea())
                            .navigationTitle(tr("Voice"))
                            .onDisappear { audio.stop() }
                        } label: {
                            LabeledContent(tr("Voice in the app"), value: tr("{0} · synthetic", audio.voice.name))
                        }
                        .accessibilityIdentifier("profile-voice")
                    } else {
                        LabeledContent(tr("Voice in the app"), value: tr("None"))
                    }
                    LabeledContent(tr("Native recordings"), value: audio.nativeClipCount > 0 ? tr("{0} clips", audio.nativeClipCount) : tr("Not included yet"))
                    LabeledContent(tr("iPhone's Georgian voice"), value: audio.georgianVoice == nil ? tr("Not on this iPhone") : (audio.georgianVoice?.name ?? tr("Installed")))
                } header: {
                    Text(tr("Audio"))
                } footer: {
                    Text(tr("Georgian is spoken by Eka or Giorgi, computer voices from Microsoft Azure, and labelled \"Synthetic voice\". With Giorgi, the alphabet is a native speaker's recording changed into a man's voice, labelled \"Native recording, voice changed\". More native recordings will replace clips one by one and are labelled \"Native recording\"."))
                }

                Section {
                    Toggle(tr("Daily reminder"), isOn: reminderBinding)
                        .accessibilityIdentifier("reminder-toggle")
                    if store.profile.remindersOn {
                        DatePicker(tr("Time"), selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if reminderDenied {
                        Text(tr("Notifications are off for this app. Turn them on in the iPhone's Settings › Notifications."))
                            .font(.caption)
                            .foregroundStyle(Palette.error)
                    }
                } header: {
                    Text(tr("Reminders"))
                }

                Section {
                    Picker(tr("Language"), selection: Binding(get: { app.language }, set: { new in
                        // The app reloads in the new language; close this sheet first.
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { app.setLanguage(new) }
                    })) {
                        ForEach(AppLanguage.allCases) { l in Text(l.flag + " " + l.nativeName).tag(l) }
                    }
                    .accessibilityIdentifier("language-picker")
                } header: {
                    Text(tr("Language"))
                } footer: {
                    Text(tr("Explanations, meanings and the app itself in your language. Your progress stays the same."))
                }

                Section(tr("App")) {
                    Toggle(tr("Haptics"), isOn: binding(\.hapticsOn) { Haptics.enabled = $0 })
                    Picker(tr("Appearance"), selection: binding(\.appearance)) {
                        Text(tr("System")).tag("system")
                        Text(tr("Light")).tag("light")
                        Text(tr("Dark")).tag("dark")
                    }
                }

                // Developer (KART #8): one switch; its two testing tools show only while it's on.
                // Only in builds that have the tools (Feather IPA, Simulator), never on the App Store.
                if LearningStore.devToolsAvailable {
                    Section {
                        Toggle(isOn: Binding(get: { store.developerMode }, set: { on in withMotion { store.developerMode = on } })) {
                            DevRow(symbol: "hammer.fill", color: .saperavi, title: tr("Developer mode"),
                                   detail: tr("Tools for testing the app."))
                        }
                        .accessibilityIdentifier("dev-mode")
                        if store.developerMode {
                            Toggle(isOn: Binding(get: { store.devOpenAllLessons }, set: { store.devOpenAllLessons = $0 })) {
                                DevRow(symbol: "lock.open.fill", color: .tkemali, title: tr("Open all lessons"),
                                       detail: tr("Every lesson can be opened, whatever you've finished."))
                            }
                            .accessibilityIdentifier("dev-unlock-all")
                            Toggle(isOn: Binding(get: { store.devQuickPass }, set: { store.devQuickPass = $0 })) {
                                DevRow(symbol: "forward.fill", color: .gold, title: tr("Quick pass in lessons"),
                                       detail: tr("A Pass button at the top of a lesson: tap it to count the exercise as right, hold it to finish the lesson."))
                            }
                            .accessibilityIdentifier("dev-quick-pass-toggle")
                        }
                    } header: {
                        Text(tr("Developer"))
                    } footer: {
                        Text(store.developerMode
                             ? tr("Quick pass counts as right answers, so it changes your progress. Open all lessons doesn't.")
                             : tr("Off: the app works as it does for everyone."))
                    }
                }

                // About (KART #14): Apple asks for the privacy policy inside the app too.
                Section(tr("About")) {
                    Link(destination: Self.siteLink("privacy")) {
                        Label(tr("Privacy policy"), systemImage: "hand.raised.fill")
                    }
                    .accessibilityIdentifier("about-privacy")
                    Link(destination: Self.siteLink("support")) {
                        Label(tr("Help and support"), systemImage: "questionmark.circle.fill")
                    }
                    .accessibilityIdentifier("about-support")
                }

                Section {
                    Button(tr("Start over"), role: .destructive) { confirmReset = true }
                        .accessibilityIdentifier("reset-progress")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Everything stays on this iPhone: no account, no tracking."))
                        AraSymbol(size: 34)
                            .padding(.top, 8)
                        Text(tr("Ara {0} · build {1} · course v{2}", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                                Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "", store.curriculum.version))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AmbientBackground(tint: .saperavi))
            .navigationTitle(tr("Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Done")) { saveName(); dismiss() }.accessibilityIdentifier("profile-done")
                }
            }
            .confirmationDialog(tr("Delete all progress?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("Delete everything"), role: .destructive) {
                    ReminderScheduler.disable()
                    dismiss()
                    store.resetAll()
                }
            } message: {
                Text(tr("Your lessons, words and streak will be gone. This can't be undone."))
            }
            .onAppear { name = store.profile.name }
        }
    }

    /// A page of the website (aralearn.github.io) in the app's language.
    private static func siteLink(_ page: String) -> URL {
        let prefix = AppLanguage.current == .pl ? "/pl" : ""
        return URL(string: "https://aralearn.github.io\(prefix)/\(page)")!
    }

    private struct DevRow: View {
        let symbol: String
        let color: BrandColor
        let title: String
        let detail: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.gradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail).font(.caption).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != store.profile.name { store.updateProfile { $0.name = trimmed } }
    }

    private func binding<T>(_ key: ReferenceWritableKeyPath<LearnerProfile, T>, then: ((T) -> Void)? = nil) -> Binding<T> {
        Binding(get: { store.profile[keyPath: key] }, set: { v in
            store.updateProfile { $0[keyPath: key] = v }
            then?(v)
        })
    }

    private var goalBinding: Binding<Int> { binding(\.dailyGoal) }
    private var levelBinding: Binding<String> { binding(\.levelRaw) }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { store.profile.remindersOn }, set: { on in
            if on {
                Task {
                    let ok = await store.enableReminders()
                    reminderDenied = !ok
                }
            } else {
                ReminderScheduler.disable()
                store.updateProfile { $0.remindersOn = false }
            }
        })
    }

    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(hour: store.profile.reminderHour, minute: store.profile.reminderMinute)) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            store.updateProfile {
                $0.reminderHour = c.hour ?? 19
                $0.reminderMinute = c.minute ?? 0
            }
            store.refreshReminders()
        })
    }
}
