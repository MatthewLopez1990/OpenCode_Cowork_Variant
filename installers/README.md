# Prebuilt GUI Installers

Drop-in, double-click installers for end users who don't want to touch a terminal.

| File | Platform | Architecture |
|------|----------|--------------|
| `ChatFortAI.Cowork.Installer_0.1.10_aarch64.dmg` | macOS | Apple Silicon (M1 and newer) |
| `ChatFortAI.Cowork.Installer_0.1.10_x64.dmg` | macOS | Intel |
| `ChatFortAI.Cowork.Installer_0.1.10_x64-setup.exe` | Windows | x64 |
| `ChatFortAI.Cowork.Installer_0.1.10_amd64.AppImage` | Linux | x64 |

## How to use

**macOS (Apple Silicon)**

1. Double-click the `.dmg` to mount it.
2. Drag "ChatFortAI Cowork Installer" to your Applications folder.
3. Right-click the app → **Open** the first time if Gatekeeper prompts on an unsigned build.
4. Follow the 3-step wizard: branding → install → finish. The installer auto-loads the 5 newest models from Anthropic, OpenAI, and Google with Claude Sonnet as the starting default.

## Other platforms

macOS Intel, Windows x64, and Linux x64 binaries are produced by the [`Build Installer`](../.github/workflows/build-installer.yml) GitHub Action. Trigger it from the Actions tab and attach the artifacts here (or to a release) once they finish.

## What the installer does

Under the hood it clones this repo to `~/.opencode-cowork-install`, reads your branding from the wizard, and runs the platform-appropriate shell installer (`install-macos.sh` / `install-linux.sh` / `install-windows.ps1`) non-interactively. The shell installer queries OpenRouter, picks the 5 newest models from each of Anthropic / OpenAI / Google, and loads all 15 into the branded desktop app's config. The result is the same branded app the scripts produce when run manually — no build steps or CLI involvement required from the end user.
