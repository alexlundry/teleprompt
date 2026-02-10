import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct EditorView: View {
    @ObservedObject var scriptStore: ScriptStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var scrollController: ScrollController

    @State private var editingTitle: String = ""
    @State private var editingContent: String = ""
    @State private var isImporting = false

    var body: some View {
        NavigationSplitView {
            // Sidebar with script list
            VStack(spacing: 0) {
                List(selection: Binding(
                    get: { scriptStore.selectedScript },
                    set: { newValue in
                        saveCurrentEdits()
                        scriptStore.selectedScript = newValue
                        loadSelectedScript()
                    }
                )) {
                    ForEach(scriptStore.scripts) { script in
                        ScriptRowView(script: script)
                            .tag(script)
                            .contextMenu {
                                Button(role: .destructive) {
                                    scriptStore.deleteScript(script)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button {
                        saveCurrentEdits()
                        scriptStore.addScript()
                        loadSelectedScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("New Script")

                    Button {
                        isImporting = true
                    } label: {
                        Label("Import", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Import File (.txt, .docx, .doc, .rtf)")

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 200)
        } detail: {
            // Editor area
            if scriptStore.selectedScript != nil {
                VStack(spacing: 0) {
                    // Title field
                    TextField("Script Title", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.title2.bold())
                        .padding()
                        .onChange(of: editingTitle) { _, newValue in
                            if var script = scriptStore.selectedScript {
                                script.title = newValue
                                scriptStore.updateScript(script)
                            }
                        }

                    Divider()

                    // Content editor
                    TextEditor(text: $editingContent)
                        .font(.body)
                        .padding()
                        .onChange(of: editingContent) { _, newValue in
                            if var script = scriptStore.selectedScript {
                                script.content = newValue
                                scriptStore.updateScript(script)
                            }
                        }

                    Divider()

                    // Bottom toolbar
                    HStack {
                        Text("\(wordCount) words")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()

                        Text("Est. read time: \(estimatedReadTime)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            } else {
                ContentUnavailableView(
                    "No Script Selected",
                    systemImage: "doc.text",
                    description: Text("Select a script from the sidebar or create a new one")
                )
            }
        }
        .onAppear {
            loadSelectedScript()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [
                .plainText,
                UTType(filenameExtension: "docx")!,
                UTType(filenameExtension: "doc")!,
                .rtf
            ],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var wordCount: Int {
        editingContent.split(separator: " ").count
    }

    private var estimatedReadTime: String {
        let minutes = Double(wordCount) / settings.scrollSpeed
        if minutes < 1 {
            return "< 1 min"
        } else {
            return "\(Int(ceil(minutes))) min"
        }
    }

    private func loadSelectedScript() {
        if let script = scriptStore.selectedScript {
            editingTitle = script.title
            editingContent = script.content
        }
    }

    private func saveCurrentEdits() {
        if var script = scriptStore.selectedScript {
            script.title = editingTitle
            script.content = editingContent
            scriptStore.updateScript(script)
        }
    }

    private static let maxImportFileSize: Int = 10 * 1024 * 1024 // 10 MB

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Reject files larger than 10 MB
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
               fileSize > Self.maxImportFileSize {
                print("File too large to import (max 10 MB)")
                return
            }

            let title = url.deletingPathExtension().lastPathComponent
            var content: String?

            let fileExtension = url.pathExtension.lowercased()

            // Handle different file types
            if fileExtension == "txt" {
                content = try? String(contentsOf: url, encoding: .utf8)
            } else if fileExtension == "docx" || fileExtension == "doc" || fileExtension == "rtf" {
                // Use NSAttributedString to read Word/RTF documents
                if let attributedString = try? NSAttributedString(
                    url: url,
                    options: [:],
                    documentAttributes: nil
                ) {
                    content = attributedString.string
                }
            }

            if let content = content, !content.isEmpty {
                let newScript = Script(title: title, content: content)
                scriptStore.scripts.insert(newScript, at: 0)
                scriptStore.selectedScript = newScript
                scriptStore.saveScripts()
                loadSelectedScript()
            } else {
                print("Failed to import file: Could not read content")
            }

        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

struct ScriptRowView: View {
    let script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.title)
                .font(.headline)
                .lineLimit(1)

            Text(script.content.prefix(50) + (script.content.count > 50 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(
            scriptStore: ScriptStore(),
            settings: AppSettings(),
            scrollController: ScrollController(settings: AppSettings())
        )
    }
}
