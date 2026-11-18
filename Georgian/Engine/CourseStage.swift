import Foundation

/// The learner's stage in the course: a playful name instead of an exam level (A0, A1… are
/// official levels given after exams; Ara gives none). One stage per finished part of the
/// course, borrowed from a visit to Georgia: from stepping off the plane to leading the
/// toasts at a supra as the tamada (KART #6).
struct CourseStage: Equatable, Identifiable {
    /// 0 (start) to 5 (course finished).
    let id: Int
    let emoji: String
    let name: String
    /// What the learner can do at this stage, in one line.
    let canDo: String
    /// What the stage means, told as a little story.
    let story: String
    /// The part of the course whose end reaches this stage (none for the first).
    let moduleID: String?

    static var all: [CourseStage] {
        [
            CourseStage(id: 0, emoji: "✈️", name: tr("Just landed"),
                        canDo: tr("Everything is new, and that's the fun part."),
                        story: tr("You've just stepped off the plane. Georgian is still a row of beautiful curls. Not for long: a few lessons, and those curls turn into sounds you can read."),
                        moduleID: nil),
            CourseStage(id: 1, emoji: "🪧", name: tr("Sign reader"),
                        canDo: tr("Read any sign, menu or street name aloud."),
                        story: tr("The curls are letters now. Shop signs, menus, metro stations: you can sound them all out, even words you don't know yet. Most visitors never get this far."),
                        moduleID: "alphabet"),
            CourseStage(id: 2, emoji: "🍇", name: tr("Bazaar regular"),
                        canDo: tr("Count, shop and name the things around you."),
                        story: tr("You can walk through a Tbilisi bazaar, ask how much, understand the price and say what you want. Sellers notice when a visitor tries: expect a smile, maybe an extra peach."),
                        moduleID: "vocabulary"),
            CourseStage(id: 3, emoji: "🍷", name: tr("Supra guest"),
                        canDo: tr("Greet, order, ask the way and say thanks."),
                        story: tr("A supra is a Georgian feast, and you'd hold your own at one: greet the hosts, thank them, order in a café and find your way home. A welcome guest at any table."),
                        moduleID: "everyday"),
            CourseStage(id: 4, emoji: "🥂", name: tr("Tamada's apprentice"),
                        canDo: tr("Build your own simple sentences."),
                        story: tr("The tamada leads the toasts at a supra, and you're learning the craft. You know how Georgian sentences fit together, so you make your own instead of only repeating phrases."),
                        moduleID: "grammar"),
            CourseStage(id: 5, emoji: "🏆", name: tr("Tamada"),
                        canDo: tr("Hold a simple conversation."),
                        story: tr("You've finished the course. Like the tamada at the head of the table, you can lead a simple conversation in Georgian. Keep it fresh with a few minutes of review."),
                        moduleID: "conversation"),
        ]
    }

    /// The highest stage whose part of the course is finished.
    static func current(modulesCompleted: Set<String>) -> CourseStage {
        let stages = all
        return stages.last { $0.moduleID.map(modulesCompleted.contains) ?? true } ?? stages[0]
    }

    /// The stage after this one, or nil at the end.
    var next: CourseStage? {
        let stages = Self.all
        return id + 1 < stages.count ? stages[id + 1] : nil
    }
}
