import SwiftUI

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
                        .font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(node.name) folder, \(isOpen ? "expanded" : "collapsed")")

            if isOpen {
                ForEach(node.children) { child in
                    FileTreeRow(node: child, depth: depth + 1, expanded: $expanded, ws: ws, onSelect: onSelect)
                }
            }
        } else if let url = node.url {
            let isSel = ws.selectedFile == url
            let changed = ws.changedFiles.contains(url)
            Button { onSelect(url) } label: {
                row {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10)).foregroundStyle(changed ? DS.Palette.accent : .secondary).frame(width: 9)
                    Text(node.name)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(isSel ? .white : Color.white.opacity(0.72))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    if changed { Circle().fill(DS.Palette.accent).frame(width: 6, height: 6) }
                }
                .background(isSel ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
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
