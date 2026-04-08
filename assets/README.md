# Branding Assets

Place your organization's logos here **before** running the install script.

## Files

| File | Purpose | Requirements |
|------|---------|-------------|
| `icon.png` | App icon — favicon, desktop shortcut, Dock/taskbar, title bar | **PNG**, 512x512 or larger (1024x1024 recommended). Must be a real PNG — SVG or WebP files renamed to `.png` will fail silently. |
| `logo.png` | Splash screen logo — shown on the landing page when the app opens | **PNG**, any size. Transparent background recommended so it looks clean on both light and dark themes. |

## How it works

1. Drop `icon.png` and/or `logo.png` into this folder
2. Run the installer (`install-macos.sh`, `install-windows.ps1`, or `install-linux.sh`)
3. The installer detects these files and applies them automatically:
   - **icon.png** is resized to all required dimensions (16x16 through 1024x1024), converted to `.icns` on macOS, and copied to the app bundle, favicon, and PWA icons
   - **logo.png** is copied as-is to the splash/landing page

## Tips

- **Use transparent backgrounds** — avoids white boxes or hard edges on dark themes
- **Real PNG only** — if your source is SVG, open it in Preview (macOS) or any image editor and export as PNG first
- **Both files are optional** — the app works fine without them (no broken images, the logo area simply hides)
- **Re-run the installer** to update branding after adding or changing these files
