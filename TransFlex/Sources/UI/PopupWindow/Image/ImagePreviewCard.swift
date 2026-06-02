import SwiftUI

/// Full-bleed preview that replaces the text editor when an image is
/// attached. Image is the primary content for image translation, so it
/// takes the whole input card instead of being demoted to a 48pt chip
/// above an empty editor.
///
/// `canRemove` hides the X during streaming/done — the attached image
/// is the source of an in-flight or completed translation, so removing
/// it mid-stream would leave the result orphaned.
struct ImagePreviewCard: View {
    let image: NSImage
    let sourceType: ImageSource
    let canRemove: Bool
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if canRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .black.opacity(0.65))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .padding(8)
                .opacity(isHovered ? 1 : 0.55)
                .help("Remove image")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            sourceBadge
                .padding(14)
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var sourceBadge: some View {
        let icon: String = {
            switch sourceType {
            case .paste: return "doc.on.clipboard"
            case .drag:  return "arrow.down.doc"
            case .file:  return "doc.fill"
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white)
            .padding(5)
            .background(Circle().fill(.black.opacity(0.55)))
    }
}
