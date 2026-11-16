import Foundation

/// Launch arguments used by the UI tests and the screenshot run (never by a learner):
/// - `-uiTesting`: a fresh store in memory, so nothing touches real progress;
/// - `-resetData`: delete the saved store before opening it (UI tests that check restarts);
/// - `-seedDemo`: fill the store with an invented learner (Ana, two weeks in);
/// - `-screen <name>`: open on one screen: home, learn, words, review, progress, profile,
///   lesson, complete, onboarding, word, alphabet, exercise.
struct LaunchOptions {
    let inMemory: Bool
    let resetData: Bool
    let seedDemo: Bool
    let screen: String?
    /// With `-screen exercise`: the lesson to open (`-lesson v4`) and the kind of exercise to
    /// skip ahead to (`-kind matching`).
    let lessonID: String?
    let kind: String?

    static let current: LaunchOptions = {
        let args = ProcessInfo.processInfo.arguments
        var screen: String?
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count { screen = args[i + 1] }
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        return LaunchOptions(inMemory: args.contains("-uiTesting"), resetData: args.contains("-resetData"),
                             seedDemo: args.contains("-seedDemo"), screen: screen,
                             lessonID: value("-lesson"), kind: value("-kind"))
    }()
}
