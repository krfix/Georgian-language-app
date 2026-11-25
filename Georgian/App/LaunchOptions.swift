import Foundation

/// Launch arguments used by the UI tests and the screenshot run (never by a learner):
/// - `-uiTesting`: a fresh store in memory, so nothing touches real progress;
/// - `-resetData`: delete the saved store before opening it (UI tests that check restarts);
/// - `-seedDemo`: fill the store with an invented learner (Ana, two weeks in);
/// - `-seedAll`: with `-seedDemo`, every lesson done (the finished vine, KART #15);
/// - `-screen <name>`: open on one screen: home, learn, words, review, progress, profile,
///   lesson, complete, onboarding, word, alphabet, exercise; and the phrasebook's phrasebook,
///   category, emergency, saved, dialogue, practice, phrase, show, search.
struct LaunchOptions {
    let inMemory: Bool
    let resetData: Bool
    let seedDemo: Bool
    let seedAll: Bool
    let screen: String?
    /// With `-screen exercise`: the lesson to open (`-lesson v4`) and the kind of exercise to
    /// skip ahead to (`-kind matching`).
    let lessonID: String?
    let kind: String?
    /// With the phrasebook screens: which category, phrase or dialogue (`-item pd-taxi`); with
    /// `-screen learn`, where to scroll the path: a lesson id, `top` or `bottom`.
    let item: String?
    /// With `-screen search`: what to search for (`-query taxi`).
    let query: String?

    static let current: LaunchOptions = {
        let args = ProcessInfo.processInfo.arguments
        var screen: String?
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count { screen = args[i + 1] }
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        return LaunchOptions(inMemory: args.contains("-uiTesting"), resetData: args.contains("-resetData"),
                             seedDemo: args.contains("-seedDemo"), seedAll: args.contains("-seedAll"), screen: screen,
                             lessonID: value("-lesson"), kind: value("-kind"),
                             item: value("-item"), query: value("-query"))
    }()
}
