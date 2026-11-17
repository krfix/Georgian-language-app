import SwiftUI

/// Name, level, goal and settings: audio, haptics, reminders, appearance, and a fresh start.
struct ProfileView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio
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
                            TextField("Your name", text: $name)
                                .font(.title3.weight(.bold))
                                .submitLabel(.done)
                                .onSubmit(saveName)
                                .accessibilityIdentifier("profile-name")
                            let xp = store.totalXP
                            Text("Level \(LearnerLevel.level(forXP: xp)) · \(xp) XP · \(store.streak)-day streak")
                                .font(.caption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Learning") {
                    Picker("Daily goal", selection: goalBinding) {
                        ForEach(DailyGoal.allCases) { g in
                            Text("\(g.title) · \(g.rawValue) XP").tag(g.rawValue)
                        }
                    }
                    Picker("Starting point", selection: levelBinding) {
                        ForEach(StartingLevel.allCases) { l in Text(l.title).tag(l.rawValue) }
                    }
                    NavigationLink {
                        ScrollView { AchievementsGrid().padding(20) }
                            .background(Palette.background.ignoresSafeArea())
                            .navigationTitle("Achievements")
                    } label: {
                        LabeledContent("Achievements", value: "\(store.achievementDates.count) of \(Achievement.all.count)")
                    }
                    LabeledContent("Lessons finished", value: "\(store.completedLessons.count) of \(store.curriculum.lessons.count)")
                    LabeledContent("Words learned", value: "\(store.snapshot.wordsLearned)")
                }

                Section {
                    LabeledContent("Phrases", value: "\(store.phrasebook.phrases.count) in \(store.phrasebook.categories.count) situations")
                    LabeledContent("Saved", value: "\(store.savedPhrases.count)")
                    LabeledContent("Checked by", value: store.phrasebook.isNativeChecked ? "A native speaker" : "Claude (AI)")
                } header: {
                    Text("Phrasebook")
                } footer: {
                    Text("Everything works offline: phrases, search, audio and your saved phrases are all on this iPhone.")
                }

                Section {
                    Toggle("Slower Georgian audio", isOn: binding(\.slowAudio) { audio.slow = $0 })
                    LabeledContent("Voice in the app", value: audio.syntheticClipCount > 0 ? "Eka · synthetic" : "None")
                    LabeledContent("Native recordings", value: audio.nativeClipCount > 0 ? "\(audio.nativeClipCount) clips" : "Not included yet")
                    LabeledContent("iPhone's Georgian voice", value: audio.georgianVoice == nil ? "Not on this iPhone" : (audio.georgianVoice?.name ?? "Installed"))
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Georgian is spoken by Eka, a computer voice from Microsoft Azure, and labelled \"Synthetic voice\". A native speaker's recordings will replace her clips one by one and are labelled \"Native recording\".")
                }

                Section {
                    Toggle("Daily reminder", isOn: reminderBinding)
                        .accessibilityIdentifier("reminder-toggle")
                    if store.profile.remindersOn {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if reminderDenied {
                        Text("Notifications are off for this app. Turn them on in the iPhone's Settings › Notifications.")
                            .font(.caption)
                            .foregroundStyle(Palette.error)
                    }
                } header: {
                    Text("Reminders")
                }

                Section("App") {
                    Toggle("Haptics", isOn: binding(\.hapticsOn) { Haptics.enabled = $0 })
                    Picker("Appearance", selection: binding(\.appearance)) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                Section {
                    Toggle("Open all lessons", isOn: Binding(get: { store.unlockAllLessons },
                                                             set: { store.unlockAllLessons = $0 }))
                        .accessibilityIdentifier("dev-unlock-all")
                } header: {
                    Text("Developer")
                } footer: {
                    Text("For testing: every lesson can be opened, whatever you've finished. Your progress isn't changed.")
                }

                Section {
                    Button("Start over", role: .destructive) { confirmReset = true }
                        .accessibilityIdentifier("reset-progress")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Everything stays on this iPhone: no account, no tracking.")
                        AraSymbol(size: 34)
                            .padding(.top, 8)
                        Text("Ara \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · course v\(store.curriculum.version)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AmbientBackground(tint: .saperavi))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveName(); dismiss() }.accessibilityIdentifier("profile-done")
                }
            }
            .confirmationDialog("Delete all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    ReminderScheduler.disable()
                    dismiss()
                    store.resetAll()
                }
            } message: {
                Text("Your lessons, words, XP and streak will be gone. This can't be undone.")
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
