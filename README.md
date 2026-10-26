# RizzKB

An iPhone keyboard that turns a conversation into reply ideas, powered by Ollama on your own PC.

**How you use it:** copy her message (long-press → Copy), *or* take a screenshot of the chat (tap the preview → Share → **Copy**). Switch to RizzKB with 🌐, pick a vibe, tap **✨ Rizz from clipboard**, then tap a reply to drop it into the text box. If you've already typed a draft, it rewrites that instead.

> iOS doesn't let any keyboard read the screen of another app, so the clipboard is how the conversation gets in. That's how every rizz keyboard on the App Store works too.

---

## Part 1 — Your PC (Ollama)

1. Install/update Ollama for Windows if you haven't (ollama.com).
2. Open PowerShell **as Administrator** in this folder and run:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass; .\setup-ollama-windows.ps1
   ```
   It makes Ollama listen on your network, opens the firewall port, pulls the `qwen2.5vl:7b` vision model, and prints the URL to use.
3. **Away from home:** install Tailscale on the PC and your iPhone (same account) and use the PC's `100.x.x.x` address. Your PC has to be on for the keyboard to work.

Other vision models that work: `qwen3-vl:8b`, `gemma3:12b`, `llama3.2-vision`. A text-only model (e.g. `llama3.1:8b`) works for copied text but not screenshots. (ComfyUI isn't needed — that's for images.)

## Part 2 — Build the app without a Mac (GitHub Actions)

GitHub gives free macOS build machines.

1. Create a free GitHub account → **New repository** → name it `RizzKB` (Private is fine).
2. **Add file → Upload files** and drag in everything in this folder, *including* the hidden `.github` folder. (Easiest: install GitHub Desktop, clone the repo, copy the files in, Commit, Push.)
3. Go to the **Actions** tab. The *Build unsigned IPA* run starts on every push (or click **Run workflow**). ~5 minutes.
4. Open the finished run → **Artifacts** → download `RizzKB-ipa` and unzip it to get `RizzKB.ipa`.

Private repos get 2,000 free Actions minutes/month; macOS minutes count 10×, so ~20 builds a month. Public repos are unlimited.

## Part 3 — Install on your iPhone from Windows (Sideloadly)

1. Install **iTunes (the version from apple.com, not the Microsoft Store)** and **Sideloadly** (sideloadly.io).
2. Plug in your iPhone, tap *Trust This Computer*.
3. Drag `RizzKB.ipa` into Sideloadly, enter your Apple ID, click **Start**.
4. On the iPhone: Settings → Privacy & Security → **Developer Mode** → On (restarts the phone). Then Settings → General → VPN & Device Management → trust your Apple ID.
5. Settings → General → Keyboard → Keyboards → Add New Keyboard → **RizzKB** → turn on **Allow Full Access**.

**Free Apple ID limit:** sideloaded apps expire after 7 days. Re-run Sideloadly (it can auto-refresh over Wi-Fi if the PC is on). A paid Apple Developer account ($99/yr) makes it last a year.

## Part 4 — Connect the keyboard

1. Open the RizzKB app → enter `http://<your PC IP>:11434` → **Test connection** → pick your model → **Save**.
2. Tap **Copy config for keyboard**, open Notes, switch to RizzKB, tap ✨ once — it says *Settings imported*. (Needed because Sideloadly can strip the shared App Group between the app and the keyboard.)
3. Use **Try it here** in the app to test with a screenshot first.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Couldn't reach Ollama" | Phone on same Wi-Fi (or Tailscale on)? PC awake? Windows network set to *Private*? Open `http://<PC IP>:11434` in iPhone Safari — should say "Ollama is running". |
| Keyboard shows "needs Full Access" | Settings → General → Keyboard → Keyboards → RizzKB → Allow Full Access. |
| Slow first reply | Model is loading into GPU memory; later replies are faster (kept warm for 30 min). |
| Keyboard disappears / crashes on huge screenshots | Crop the screenshot to the last few messages. |
| Build fails on GitHub | Download the `build-log` artifact from the failed run and send it to Claude. |

## Files

- `Keyboard/KeyboardViewController.swift` — the keyboard UI and clipboard logic
- `Shared/Prompt.swift` — the wingman prompt (tweak the rules/vibes here)
- `Shared/OllamaClient.swift` — talks to Ollama's `/api/chat`
- `App/ContentView.swift` — settings + test screen
- `project.yml` — XcodeGen project definition (the workflow turns it into an Xcode project)
