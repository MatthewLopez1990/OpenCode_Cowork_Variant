# Prebuilt GUI Installers

Drop-in, double-click installers for end users who don't want to touch a terminal.

| File | Platform | Architecture |
|------|----------|--------------|
| `OpenCode Cowork Installer_0.1.0_aarch64.dmg` | macOS | Apple Silicon (M1 and newer) |

## How to use

**macOS (Apple Silicon)**

1. Double-click the `.dmg` to mount it.
2. Drag "OpenCode Cowork Installer" to your Applications folder.
3. Right-click the app → **Open** the first time (bypasses Gatekeeper since the app is unsigned for v1).
4. Follow the 4-step wizard: branding → model → install → finish.

## Other platforms

macOS Intel, Windows x64, and Linux x64 binaries are produced by the [`Build Installer`](../.github/workflows/build-installer.yml) GitHub Action. Trigger it from the Actions tab and attach the artifacts here (or to a release) once they finish.

## What the installer does

Under the hood it clones this repo to `~/.opencode-cowork-install`, reads your branding + model choice from the wizard, and runs the platform-appropriate shell installer (`install-macos.sh` / `install-linux.sh` / `install-windows.ps1`) non-interactively. The result is the same branded desktop app the scripts produce when run manually.
