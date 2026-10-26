import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var settings = SettingsStore.load()
    @State private var models: [String] = []
    @State private var connectionStatus = ""
    @State private var saveStatus = ""

    @State private var testText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var testImage: UIImage?
    @State private var results: [String] = []
    @State private var testError = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Set up the keyboard") {
                    Text("1. Settings › General › Keyboard › Keyboards › Add New Keyboard › **RizzKB**")
                    Text("2. Tap RizzKB and turn on **Allow Full Access** (needed to read the clipboard and reach your PC)")
                    Text("3. Fill in your server below, tap **Save**, then **Copy config for keyboard**, open any text field, switch to RizzKB with 🌐 and tap ✨ once to import.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .font(.footnote)

                Section {
                    TextField("http://192.168.1.50:11434", text: $settings.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if models.isEmpty {
                        TextField("Model (e.g. qwen2.5vl:7b)", text: $settings.model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        Picker("Model", selection: $settings.model) {
                            ForEach(pickerModels, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Button("Test connection") { Task { await testConnection() } }
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your Ollama server")
                } footer: {
                    Text("Use your PC's LAN IP at home, or its Tailscale IP (100.x.x.x) to use it anywhere. Pick a vision model so screenshots work.")
                }

                Section("Style") {
                    Picker("Default vibe", selection: $settings.vibe) {
                        ForEach(Vibe.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    TextField("About you (optional): job, hobbies, humor…", text: $settings.aboutMe, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Save") {
                        SettingsStore.save(settings)
                        saveStatus = "Saved ✓"
                    }
                    Button("Copy config for keyboard") {
                        SettingsStore.save(settings)
                        UIPasteboard.general.string = SettingsStore.exportString(settings)
                        saveStatus = "Copied — now tap ✨ in the RizzKB keyboard once to import."
                    }
                    if !saveStatus.isEmpty {
                        Text(saveStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Sideloading tools sometimes strip the shared App Group, so the keyboard can also import settings from the clipboard.")
                }

                Section("Try it here") {
                    TextField("Paste her message(s)…", text: $testText, axis: .vertical)
                        .lineLimit(2...6)
                    PhotosPicker(selection: $photoItem, matching: .screenshots) {
                        Label(testImage == nil ? "Pick a chat screenshot" : "Screenshot selected ✓", systemImage: "photo")
                    }
                    if let img = testImage {
                        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 180)
                        Button("Remove screenshot", role: .destructive) { testImage = nil; photoItem = nil }
                    }
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            Text("✨ Generate replies")
                            if busy { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(busy)

                    if !testError.isEmpty {
                        Text(testError).font(.footnote).foregroundStyle(.red)
                    }
                    ForEach(results, id: \.self) { reply in
                        HStack(alignment: .top) {
                            Text(reply)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = reply
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("RizzKB")
            .onChange(of: photoItem) { item in
                Task { await loadPhoto(item) }
            }
        }
    }

    private var pickerModels: [String] {
        models.contains(settings.model) ? models : [settings.model] + models
    }

    private func testConnection() async {
        connectionStatus = "Connecting…"
        do {
            let list = try await OllamaClient(settings: settings).listModels()
            models = list
            connectionStatus = list.isEmpty
                ? "Connected, but no models installed. Run: ollama pull qwen2.5vl:7b"
                : "Connected ✓ — \(list.count) model(s) found"
        } catch {
            models = []
            connectionStatus = "Couldn't reach Ollama: \(error.localizedDescription)"
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        testImage = img
    }

    private func runTest() async {
        busy = true
        testError = ""
        results = []
        SettingsStore.save(settings)
        let jpeg = testImage.flatMap { ImageTools.jpegForUpload($0) }
        do {
            results = try await OllamaClient(settings: settings)
                .suggestions(conversationText: testText, imageJPEG: jpeg, draft: nil)
        } catch {
            testError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}
