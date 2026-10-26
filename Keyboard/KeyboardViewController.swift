import UIKit

final class KeyboardViewController: UIInputViewController {

    // MARK: State
    private var settings = SettingsStore.load()
    private var currentTask: Task<Void, Never>?
    private var draftUsed: String?
    private var deleteTimer: Timer?

    // MARK: Views
    private let rootStack = UIStackView()
    private let vibeStack = UIStackView()
    private var vibeButtons: [Vibe: UIButton] = [:]
    private let scrollView = UIScrollView()
    private let suggestionsStack = UIStackView()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let rizzButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        refreshVibes()
        showIdle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = SettingsStore.load()
        refreshVibes()
        if !hasFullAccess {
            setStatus("Turn on Allow Full Access:\nSettings › General › Keyboard › Keyboards › RizzKB")
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
    }

    // MARK: UI construction
    private func buildUI() {
        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        rootStack.axis = .vertical
        rootStack.spacing = 6
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])

        // Vibe chips
        let vibeScroll = UIScrollView()
        vibeScroll.showsHorizontalScrollIndicator = false
        vibeStack.axis = .horizontal
        vibeStack.spacing = 6
        vibeStack.translatesAutoresizingMaskIntoConstraints = false
        vibeScroll.addSubview(vibeStack)
        NSLayoutConstraint.activate([
            vibeStack.leadingAnchor.constraint(equalTo: vibeScroll.contentLayoutGuide.leadingAnchor),
            vibeStack.trailingAnchor.constraint(equalTo: vibeScroll.contentLayoutGuide.trailingAnchor),
            vibeStack.topAnchor.constraint(equalTo: vibeScroll.contentLayoutGuide.topAnchor),
            vibeStack.bottomAnchor.constraint(equalTo: vibeScroll.contentLayoutGuide.bottomAnchor),
            vibeStack.heightAnchor.constraint(equalTo: vibeScroll.frameLayoutGuide.heightAnchor),
            vibeScroll.heightAnchor.constraint(equalToConstant: 32)
        ])
        for vibe in Vibe.allCases {
            var cfg = UIButton.Configuration.gray()
            cfg.title = vibe.label
            cfg.cornerStyle = .capsule
            cfg.buttonSize = .small
            let b = UIButton(configuration: cfg)
            b.addAction(UIAction { [weak self] _ in self?.selectVibe(vibe) }, for: .touchUpInside)
            vibeButtons[vibe] = b
            vibeStack.addArrangedSubview(b)
        }
        rootStack.addArrangedSubview(vibeScroll)

        // Suggestions area
        suggestionsStack.axis = .vertical
        suggestionsStack.spacing = 6
        suggestionsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(suggestionsStack)
        NSLayoutConstraint.activate([
            suggestionsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            suggestionsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            suggestionsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            suggestionsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            suggestionsStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        rootStack.addArrangedSubview(scrollView)

        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        // Bottom row
        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 6
        bottom.distribution = .fill
        bottom.heightAnchor.constraint(equalToConstant: 44).isActive = true

        nextKeyboardButton.setImage(UIImage(systemName: "globe"), for: .normal)
        styleKey(nextKeyboardButton)
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        var rizzCfg = UIButton.Configuration.filled()
        rizzCfg.title = "✨ Rizz from clipboard"
        rizzCfg.cornerStyle = .medium
        rizzCfg.baseBackgroundColor = .systemPink
        rizzButton.configuration = rizzCfg
        rizzButton.addTarget(self, action: #selector(rizzTapped), for: .touchUpInside)

        let space = UIButton(type: .system)
        space.setTitle("space", for: .normal)
        styleKey(space)
        space.widthAnchor.constraint(equalToConstant: 64).isActive = true
        space.addAction(UIAction { [weak self] _ in self?.textDocumentProxy.insertText(" ") }, for: .touchUpInside)

        let delete = UIButton(type: .system)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        styleKey(delete)
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true
        delete.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        delete.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let ret = UIButton(type: .system)
        ret.setImage(UIImage(systemName: "return"), for: .normal)
        styleKey(ret)
        ret.widthAnchor.constraint(equalToConstant: 44).isActive = true
        ret.addAction(UIAction { [weak self] _ in self?.textDocumentProxy.insertText("\n") }, for: .touchUpInside)

        [nextKeyboardButton, rizzButton, space, delete, ret].forEach { bottom.addArrangedSubview($0) }
        rootStack.addArrangedSubview(bottom)

        spinner.hidesWhenStopped = true
    }

    private func styleKey(_ b: UIButton) {
        b.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.35, alpha: 1) : .white }
        b.tintColor = .label
        b.setTitleColor(.label, for: .normal)
        b.layer.cornerRadius = 6
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.25
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.layer.shadowRadius = 0
    }

    // MARK: Vibes
    private func selectVibe(_ vibe: Vibe) {
        settings.vibe = vibe
        SettingsStore.save(settings)
        refreshVibes()
    }

    private func refreshVibes() {
        for (vibe, button) in vibeButtons {
            var cfg = vibe == settings.vibe ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
            cfg.title = vibe.label
            cfg.cornerStyle = .capsule
            cfg.buttonSize = .small
            if vibe == settings.vibe { cfg.baseBackgroundColor = .systemPink }
            button.configuration = cfg
        }
    }

    // MARK: Suggestions area states
    private func clearSuggestions() {
        suggestionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    private func showIdle() {
        setStatus("Copy her message — or a screenshot of the chat — then tap ✨")
    }

    private func setStatus(_ text: String, loading: Bool = false) {
        clearSuggestions()
        let wrap = UIStackView(arrangedSubviews: [spinner, statusLabel])
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.alignment = .center
        wrap.isLayoutMarginsRelativeArrangement = true
        wrap.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 12, bottom: 12, trailing: 12)
        statusLabel.text = text
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        suggestionsStack.addArrangedSubview(wrap)
    }

    private func showSuggestions(_ result: RizzResult) {
        clearSuggestions()
        if !result.stage.isEmpty {
            let header = UILabel()
            header.text = result.summary
            header.font = .systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabel
            header.numberOfLines = 2
            suggestionsStack.addArrangedSubview(header)
        }
        for reply in result.replies {
            var cfg = UIButton.Configuration.gray()
            cfg.title = reply.text
            cfg.subtitle = reply.angleLabel
            cfg.titleAlignment = .leading
            cfg.titlePadding = 4
            cfg.cornerStyle = .large
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 15)
                return a
            }
            cfg.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 10, weight: .bold)
                a.foregroundColor = UIColor.systemPink
                return a
            }
            let b = UIButton(configuration: cfg)
            b.contentHorizontalAlignment = .leading
            b.titleLabel?.numberOfLines = 0
            b.titleLabel?.lineBreakMode = .byWordWrapping
            let text = reply.text
            b.addAction(UIAction { [weak self] _ in self?.insert(text) }, for: .touchUpInside)
            suggestionsStack.addArrangedSubview(b)
        }
        scrollView.setContentOffset(.zero, animated: false)
    }

    // MARK: Actions
    private func insert(_ reply: String) {
        // If we rewrote a draft, replace it instead of appending to it.
        if let draft = draftUsed, textDocumentProxy.documentContextBeforeInput == draft {
            for _ in 0..<draft.count { textDocumentProxy.deleteBackward() }
        }
        draftUsed = nil
        textDocumentProxy.insertText(reply)
    }

    @objc private func rizzTapped() {
        guard hasFullAccess else {
            setStatus("RizzKB needs Allow Full Access to read the clipboard and reach your AI server.\nSettings › General › Keyboard › Keyboards › RizzKB")
            return
        }

        let pb = UIPasteboard.general
        var text: String?
        var jpeg: Data?

        if pb.hasImages, let image = pb.image {
            jpeg = ImageTools.jpegForUpload(image)
        } else if pb.hasStrings, let s = pb.string, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let imported = SettingsStore.importString(s) {
                settings = imported
                SettingsStore.save(imported)
                refreshVibes()
                pb.string = ""
                setStatus("✅ Settings imported.\nNow copy a convo or screenshot and tap ✨")
                return
            }
            text = s
        }

        let draft = textDocumentProxy.documentContextBeforeInput
        let hasDraft = !(draft?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        draftUsed = hasDraft ? draft : nil

        if text == nil && jpeg == nil && !hasDraft {
            setStatus("Clipboard is empty.\nCopy her message or a screenshot first (screenshot → tap preview → Share → Copy).")
            return
        }

        generate(text: text, image: jpeg, draft: hasDraft ? draft : nil)
    }

    private func generate(text: String?, image: Data?, draft: String?) {
        currentTask?.cancel()
        rizzButton.isEnabled = false
        setStatus(image != nil ? "Reading the screenshot… 👀" : "Cooking… 🍳", loading: true)

        let client = OllamaClient(settings: settings)
        currentTask = Task { @MainActor [weak self] in
            do {
                let result = try await client.suggestions(conversationText: text, imageJPEG: image, draft: draft)
                guard !Task.isCancelled else { return }
                self?.showSuggestions(result)
            } catch {
                guard !Task.isCancelled else { return }
                let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self?.setStatus("⚠️ \(msg)\n\nIs your PC on and Ollama reachable at \(client.settings.serverURL)?")
            }
            self?.rizzButton.isEnabled = true
        }
    }

    @objc private func deleteDown() {
        textDocumentProxy.deleteBackward()
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}
