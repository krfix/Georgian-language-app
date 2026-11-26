import SwiftUI
import UIKit

/// "Report a mistake" (KART #16): opens the learner's email app with a message to us that
/// already says exactly what they were looking at (the Georgian, its meaning, the id, the
/// app's version). Nothing is sent unless they send it; the app itself sends nothing. On a
/// phrase card, a word card and in lessons (the flag in the top bar).
struct ReportSubject {
    /// What it is about, for the email's subject ("the phrase ეს რა ღირს?").
    var title: String
    /// What the learner saw, one fact a line.
    var lines: [String]
    /// The item's id (pb-…, w-…, lesson/exercise), so it's found at once in the content.
    var id: String
}

enum MistakeReport {
    static let address = "ara.learn.app@gmail.com"

    static func body(_ s: ReportSubject) -> String {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        let facts = s.lines + [tr("Id: {0}", s.id),
                               "Ara \(version) · \(AppLanguage.current.rawValue) · iOS \(UIDevice.current.systemVersion)"]
        return tr("What's wrong? Write it here, in any language:") + "\n\n\n———\n" + facts.joined(separator: "\n")
    }

    static func url(_ s: ReportSubject) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [URLQueryItem(name: "subject", value: tr("Ara: a mistake in {0}", s.title)),
                        URLQueryItem(name: "body", value: body(s))]
        return c.url
    }
}

/// The button: a quiet link under a card, or a flag icon (the lesson's top bar). The subject
/// is worked out when tapped, so a lesson reports the exercise on screen at that moment.
struct ReportMistakeButton: View {
    enum Style { case link, icon }
    var style: Style = .link
    let subject: () -> ReportSubject
    @Environment(\.openURL) private var openURL
    @State private var noMail: ReportSubject?

    var body: some View {
        Group {
            switch style {
            case .link:
                Button { Haptics.tap(); report() } label: {
                    Label(tr("Report a mistake"), systemImage: "flag")
                        .font(.calloutRounded)
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            case .icon:
                CircleIconButton(symbol: "flag", label: tr("Report a mistake"), action: report)
            }
        }
        .accessibilityIdentifier("report-mistake")
        .alert(tr("No email app"), isPresented: Binding(get: { noMail != nil }, set: { if !$0 { noMail = nil } })) {
            Button(tr("Copy the details")) {
                if let s = noMail { UIPasteboard.general.string = MistakeReport.address + "\n\n" + MistakeReport.body(s) }
                noMail = nil
            }
            Button(tr("Cancel"), role: .cancel) { noMail = nil }
        } message: {
            Text(tr("Write to {0} from any email app; copy the details to paste them in.", MistakeReport.address))
        }
    }

    private func report() {
        let s = subject()
        guard let url = MistakeReport.url(s) else { noMail = s; return }
        openURL(url) { accepted in
            if !accepted { noMail = s }
        }
    }
}
