import SwiftUI
import AppKit

// MARK: - File type icon / tint + per-file actions

enum FileKind {
    /// An SF Symbol + tint color for a file, chosen by extension. Color does most
    /// of the work (symbols stay conservative so they always resolve).
    static func icon(for url: URL) -> (symbol: String, tint: Color) {
        switch url.pathExtension.lowercased() {
        case "swift":                         return ("swift", .orange)
        case "py":                            return ("chevron.left.forwardslash.chevron.right", Color(red: 0.30, green: 0.62, blue: 0.92))
        case "js", "jsx", "mjs", "cjs":       return ("curlybraces", .yellow)
        case "ts", "tsx":                     return ("curlybraces", Color(red: 0.20, green: 0.52, blue: 0.92))
        case "json":                          return ("curlybraces", .green)
        case "yml", "yaml", "toml":           return ("curlybraces", .teal)
        case "md", "markdown", "txt", "rst":  return ("doc.text", .gray)
        case "html", "xml", "css", "scss":    return ("chevron.left.forwardslash.chevron.right", .pink)
        case "sh", "bash", "zsh":             return ("terminal", .green)
        case "c", "cpp", "cc", "h", "hpp", "m", "mm": return ("chevron.left.forwardslash.chevron.right", .blue)
        case "rs", "go", "rb", "java", "kt":  return ("chevron.left.forwardslash.chevron.right", .orange)
        case "png", "jpg", "jpeg", "gif", "heic", "svg", "webp", "pdf": return ("photo", .purple)
        default:                              return ("doc", .secondary)
        }
    }
}

/// Right-click actions for a file row (shared by the tree + the flat filtered list).
@ViewBuilder
func fileActionsMenu(_ url: URL) -> some View {
    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: {
        Label("Reveal in Finder", systemImage: "folder")
    }
    Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    } label: { Label("Copy Path", systemImage: "doc.on.doc") }
    Button {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    } label: { Label("Copy Contents", systemImage: "doc.plaintext") }
}

// MARK: - File tree model
//
// The Code tab's workspace exposes a FLAT `[URL]`; this builds a real folder
// hierarchy from it so the sidebar can be a collapsible tree instead of one long
// flat list.

struct FileNode: Identifiable {
    let id: String          // relative path — stable identity
    let name: String        // last path component
    let url: URL?           // file URL; nil for a directory
    var children: [FileNode]
    var isDir: Bool { url == nil }
}

enum FileTreeBuilder {
    /// Build a sorted hierarchy (folders first, then files; case-insensitive) from a
    /// flat list of file URLs under `root`.
    static func build(files: [URL], root: URL) -> [FileNode] {
        final class Box { var dirs: [String: Box] = [:]; var files: [(String, URL)] = [] }
        let rootBox = Box()
        let prefix = root.path + "/"
        for url in files {
            let rel = url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.lastPathComponent
            let parts = rel.split(separator: "/").map(String.init)
            guard !parts.isEmpty else { continue }
            var box = rootBox
            for dir in parts.dropLast() {
                let next = box.dirs[dir] ?? Box()
                box.dirs[dir] = next
                box = next
            }
            box.files.append((parts.last!, url))
        }
        func nodes(_ box: Box, prefix: String) -> [FileNode] {
            let dirs = box.dirs.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { name -> FileNode in
                    let path = prefix.isEmpty ? name : prefix + "/" + name
                    return FileNode(id: path, name: name, url: nil, children: nodes(box.dirs[name]!, prefix: path))
                }
            let files = box.files
                .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
                .map { FileNode(id: $0.1.path, name: $0.0, url: $0.1, children: []) }
            return dirs + files
        }
        return nodes(rootBox, prefix: "")
    }
}

// MARK: - Recursive tree row
//
// A View struct (NOT a @ViewBuilder func) so it can reference itself — recursive
// opaque return types don't compile. Folders toggle into `expanded`; files call back.

struct FileTreeRow: View {
    let node: FileNode
    let depth: Int
    @Binding var expanded: Set<String>
    @ObservedObject var ws: CodeWorkspace
    let onSelect: (URL) -> Void
    @State private var hovering = false

    var body: some View {
        if node.isDir {
            let isOpen = expanded.contains(node.id)
            Button {
                if isOpen { expanded.remove(node.id) } else { expanded.insert(node.id) }
            } label: {
                row {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary).frame(width: 9)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10)).foregroundStyle(DS.Palette.accent.opacity(0.7))
                    Text(node.name)
                        .font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(hovering ? 1.0 : 0.8))
                        .lineLimit(1).truncationMode(.middle)
                }
                .background(hovering ? Color.white.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
            .accessibilityLabel("\(node.name) folder, \(isOpen ? "expanded" : "collapsed")")

            if isOpen {
                ForEach(node.children) { child in
                    FileTreeRow(node: child, depth: depth + 1, expanded: $expanded, ws: ws, onSelect: onSelect)
                }
            }
        } else if let url = node.url {
            let isSel = ws.selectedFile == url
            let changed = ws.changedFiles.contains(url)
            let icon = FileKind.icon(for: url)
            Button { onSelect(url) } label: {
                row {
                    Image(systemName: icon.symbol)
                        .font(.system(size: 10)).foregroundStyle(changed ? DS.Palette.accent : icon.tint).frame(width: 9)
                    Text(node.name)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(isSel ? .white : Color.white.opacity(hovering ? 0.92 : 0.72))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    if changed { Circle().fill(DS.Palette.accent).frame(width: 6, height: 6) }
                }
                .background(
                    isSel ? Color.white.opacity(0.08) : hovering ? Color.white.opacity(0.04) : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(DS.Motion.press) { hovering = h } }
            .contextMenu { fileActionsMenu(url) }
        }
    }

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 5) { content() }
            .padding(.leading, CGFloat(depth) * 12 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
