import AppKit

/// How tall a translation of `text` will set in the Translation column,
/// guessed from the source before any token arrives.
enum SourceTextEstimate {
    /// Translations run a little longer than their source.
    static let translationGrowth: CGFloat = 1.1

    /// Measured in the same font and line spacing as `ReadingType.translation`.
    static func height(of text: String, width: CGFloat) -> CGFloat {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = ReadingType.translationLineSpacing
        let measured = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: ReadingType.translationSize),
            .paragraphStyle: paragraph,
        ]).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return (measured.height * translationGrowth).rounded(.up)
    }
}
