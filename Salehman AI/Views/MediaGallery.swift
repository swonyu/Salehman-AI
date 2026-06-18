import SwiftUI
import AVKit
import AppKit

/// Inline gallery for image/video search results under an assistant reply. Built
/// in the app's design language: a "double-bezel" outer tray holding concentric
/// tiles, soft hover physics, and a button-in-button play affordance for videos.
/// Images open full-size in the browser; videos play inline when the URL is a
/// direct file, else open their source page. The model never produces this —
/// the Chat tab attaches `message.media` (see `MediaCapture`).
struct MediaGallery: View {
    let items: [MediaItem]

    /// Direct-file video chosen for inline playback (sheet). Watch-page videos
    /// open in the browser instead.
    @State private var playing: MediaItem?

    private var imageCount: Int { items.filter { $0.kind == .image }.count }
    private var videoCount: Int { items.filter { $0.kind == .video }.count }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220),
                                    spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    MediaTile(item: item) { open(item) }
                }
            }
        }
        // The double-bezel "tray": a subtle outer shell with a hairline, holding
        // the tiles on a recessed surface — the gallery reads as one machined unit.
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Bezel.shellFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.Bezel.shellStroke, lineWidth: 1)
        )
        .frame(maxWidth: 520, alignment: .leading)
        .sheet(item: $playing) { VideoSheet(item: $0) }
    }

    // Eyebrow: a microscopic count pill, calm and subordinate to the reply.
    private var header: some View {
        HStack(spacing: 8) {
            if imageCount > 0 { countPill(icon: "photo.on.rectangle.angled", n: imageCount, word: "image") }
            if videoCount > 0 { countPill(icon: "play.rectangle.fill", n: videoCount, word: "video") }
            Spacer(minLength: 0)
        }
    }

    private func countPill(icon: String, n: Int, word: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text("\(n) \(word)\(n == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(DS.Palette.textSecondary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    /// Click action: direct-file videos play inline; everything else (images and
    /// watch-page videos) opens in the default browser — never auto-clicked, the
    /// user taps a tile.
    private func open(_ item: MediaItem) {
        if item.isDirectVideoFile {
            playing = item
        } else if let url = URL(string: item.url) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - One tile

private struct MediaTile: View {
    let item: MediaItem
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                // Video affordance: a centered glass play well (button-in-button)
                // plus a duration chip — only on video tiles.
                if item.kind == .video {
                    playOverlay
                }
                // Source label gradient foot — lets the user judge where it's from.
                if let source = item.source, !source.isEmpty {
                    sourceFoot(source)
                }
            }
            // Inner core: concentric radius (card − bezel padding) so the curve
            // nests cleanly inside the tray.
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovering ? 0.18 : 0.08), lineWidth: 1)
            )
            // Soft, diffused lift on hover — physical, never a harsh drop shadow.
            .shadow(color: .black.opacity(hovering ? 0.35 : 0.0),
                    radius: hovering ? 14 : 0, y: hovering ? 6 : 0)
            .scaleEffect(hovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
        .help(item.title ?? (item.kind == .video ? "Open video" : "Open image"))
    }

    private var thumbnail: some View {
        AsyncImage(url: URL(string: item.displayURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder(systemImage: "photo")
            case .empty:
                ZStack {
                    Rectangle().fill(Color.white.opacity(0.04))
                    ProgressView().controlSize(.small)
                }
            @unknown default:
                placeholder(systemImage: "photo")
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.25))
        .clipped()
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.04))
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private var playOverlay: some View {
        ZStack {
            // Center play well — concentric circle, glass, scales on hover.
            Circle()
                .fill(.black.opacity(0.45))
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                )
                .scaleEffect(hovering ? 1.08 : 1.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Duration chip, bottom-right.
            if let d = item.duration, !d.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(d)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.65)))
                            .padding(6)
                    }
                }
            }
        }
    }

    private func sourceFoot(_ source: String) -> some View {
        Text(source)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 7).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
            )
    }
}

// MARK: - Inline video sheet (direct-file URLs only)

private struct VideoSheet: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.title ?? "Video")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            if let url = URL(string: item.url) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(minWidth: 640, minHeight: 360)
            } else {
                Text("Couldn't load this video.")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 640, minHeight: 360)
            }
        }
        .frame(width: 720, height: 460)
        .background(DS.Palette.modalBG)
    }
}
