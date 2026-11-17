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
                    LabeledContent(tr("Checked by"), value: store.phrasebook.isNativeChecked ? tr("A native speaker") : tr("Claude (AI)"))
                } header: {
                    Text(tr("Phrasebook"))
                } footer: {
                    Text(tr("Everything works offline: phrases, search, audio and your saved phrases are all on this iPhone."))
                }

                Section {
                    Toggle(tr("Slower Georgian audio"), isOn: binding(\.slowAudio) { audio.slow = $0 })
                    LabeledContent(tr("Voice in the app"), value: audio.syntheticClipCount > 0 ? tr("Eka · synthetic") : tr("None"))
                    LabeledContent(tr("Native recordings"), value: audio.nativeClipCount > 0 ? tr("{0} clips", audio.nativeClipCount) : tr("Not included yet"))
                    LabeledContent(tr("iPhone's Georgian voice"), value: audio.georgianVoice == nil ? tr("Not on this iPhone") : (audio.georgianVoice?.name ?? tr("Installed")))
                } header: {
                    Text(tr("Audio"))
                } footer: {
                    Text(tr("Georgian is spoken by Eka, a computer voice from Microsoft Azure, and labelled \"Synthetic voice\". A native speaker's recordings will replace her clips one by one and are labelled \"Native recording\"."))
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

                Section {
                    Toggle(tr("Open all lessons"), isOn: Binding(get: { store.unlockAllLessons },
                                                             set: { store.unlockAllLessons = $0 }))
                        .accessibilityIdentifier("dev-unlock-all")
                } header: {
                    Text(tr("Developer"))
                } footer: {
                    Text(tr("For testing: every lesson can be opened, whatever you've finished. Your progress isn't changed."))
                }

                Section {
                    Button(tr("Start over"), role: .destructive) { confirmReset = true }
                        .accessibilityIdentifier("reset-progress")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("Everything stays on this iPhone: no account, no tracking."))
                        AraSymbol(size: 34)
                            .padding(.top, 8)
                        Text(tr("Ara {0} · course v{1}", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", store.curriculum.version))
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
                    let ok = await ReminderScheduler.enable(hour: store.profile.reminderHour, minute: store.profile.reminderMinute, name: store.profile.name)
                    reminderDenied = !ok
                    store.updateProfile { $0.remindersOn = ok }
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
            Task { _ = await ReminderScheduler.enable(hour: c.hour ?? 19, minute: c.minute ?? 0, name: store.profile.name) }
        })
    }
}
