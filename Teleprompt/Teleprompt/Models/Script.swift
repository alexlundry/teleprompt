import Foundation

struct Script: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "Untitled Script", content: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []
    @Published var selectedScript: Script?

    private let saveKey = "SavedScripts"
    private let fileURL: URL

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("teleprompt_scripts.json")
        loadScripts()
    }

    func loadScripts() {
        do {
            let data = try Data(contentsOf: fileURL)
            scripts = try JSONDecoder().decode([Script].self, from: data)
            if let first = scripts.first {
                selectedScript = first
            }
        } catch {
            // No saved scripts yet, create a sample one
            let sampleScript = Script(
                title: "Welcome Script",
                content: "Welcome to Teleprompt!\n\nThis is your teleprompter app for natural video calls.\n\nThe text will scroll smoothly near your camera so you can maintain eye contact while reading.\n\nUse the controls to adjust speed, pause, or restart.\n\nEdit this script or create new ones in the editor window.\n\nHappy presenting!"
            )
            scripts = [sampleScript]
            selectedScript = sampleScript
            saveScripts()
        }
    }

    func saveScripts() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save scripts: \(error)")
        }
    }

    func addScript() {
        let newScript = Script()
        scripts.insert(newScript, at: 0)
        selectedScript = newScript
        saveScripts()
    }

    func deleteScript(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        if selectedScript?.id == script.id {
            selectedScript = scripts.first
        }
        saveScripts()
    }

    func updateScript(_ script: Script) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            var updated = script
            updated.updatedAt = Date()
            scripts[index] = updated
            if selectedScript?.id == script.id {
                selectedScript = updated
            }
            saveScripts()
        }
    }
}
