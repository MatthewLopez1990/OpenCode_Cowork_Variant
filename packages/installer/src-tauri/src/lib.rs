use std::path::PathBuf;
use std::process::Stdio;

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter, Manager};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;

const REPO_URL: &str = "https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant.git";
const CLONE_DIR_NAME: &str = ".opencode-cowork-install";
// Branch to clone from. Hardcoded to the feature branch while the GUI installer
// is still under review — once merged to main, change this to "main" (or make
// it configurable via an env var / build-time constant). The shell installer
// scripts MUST exist on the referenced ref with non-interactive mode support,
// otherwise the GUI can't drive them and falls back to blocking on stdin.
const CLONE_BRANCH: &str = "feature/dynamic-models-and-gui-installer";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InstallPayload {
    app_name: String,
    api_key: String,
    // Model is no longer collected by the wizard — the shell installer
    // hardcodes Claude Sonnet 4.6 and auto-loads the top 5 per family. These
    // fields remain as optional overrides for power users invoking the Rust
    // command directly (e.g. via custom tooling).
    #[serde(default)]
    default_model: Option<String>,
    #[serde(default)]
    default_model_display: Option<String>,
    #[serde(default)]
    icon_path: Option<String>,
    #[serde(default)]
    logo_path: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct LogEvent {
    stream: &'static str, // "stdout" | "stderr" | "system"
    line: String,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct StatusEvent {
    stage: String,
    message: String,
}

fn emit_log(app: &AppHandle, stream: &'static str, line: impl Into<String>) {
    let _ = app.emit("install:log", LogEvent { stream, line: line.into() });
}

fn emit_status(app: &AppHandle, stage: &str, message: &str) {
    let _ = app.emit(
        "install:status",
        StatusEvent { stage: stage.to_string(), message: message.to_string() },
    );
}

fn home_dir() -> Result<PathBuf, String> {
    dirs_home()
        .ok_or_else(|| "Could not determine user home directory".to_string())
}

fn dirs_home() -> Option<PathBuf> {
    #[cfg(target_os = "windows")]
    {
        std::env::var_os("USERPROFILE").map(PathBuf::from)
    }
    #[cfg(not(target_os = "windows"))]
    {
        std::env::var_os("HOME").map(PathBuf::from)
    }
}

async fn check_git_available() -> bool {
    Command::new("git")
        .arg("--version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .await
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Clone or refresh the repo at ~/.opencode-cowork-install so the shell script
/// has a valid $COWORK_REPO_DIR to read assets/config/electron templates from.
async fn ensure_repo(app: &AppHandle) -> Result<PathBuf, String> {
    let clone_dir = home_dir()?.join(CLONE_DIR_NAME);

    // Always nuke any existing clone and fresh-clone the target branch. Shallow
    // clones + mid-stream branch switches are a mess; a fresh 15 MB clone each
    // run is the simpler, more reliable path.
    if clone_dir.exists() {
        emit_log(
            app,
            "system",
            format!("Removing existing clone at {}", clone_dir.display()),
        );
        if let Err(e) = std::fs::remove_dir_all(&clone_dir) {
            return Err(format!("failed to remove existing clone: {e}"));
        }
    }
    emit_log(
        app,
        "system",
        format!("Cloning {} (branch {}) to {}", REPO_URL, CLONE_BRANCH, clone_dir.display()),
    );
    if let Some(parent) = clone_dir.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let status = Command::new("git")
        .args([
            "clone",
            "--depth", "1",
            "--branch", CLONE_BRANCH,
            REPO_URL,
            clone_dir.to_string_lossy().as_ref(),
        ])
        .status()
        .await
        .map_err(|e| format!("failed to run git clone: {e}"))?;
    if !status.success() {
        return Err(format!(
            "git clone exited with status {}",
            status.code().map(|c| c.to_string()).unwrap_or_else(|| "unknown".into())
        ));
    }

    Ok(clone_dir)
}

fn platform_script(repo_dir: &PathBuf) -> Result<(PathBuf, &'static str, Vec<&'static str>), String> {
    // (script path, executable, arg prefix)
    #[cfg(target_os = "macos")]
    {
        let script = repo_dir.join("install-macos.sh");
        return Ok((script, "bash", vec![]));
    }
    #[cfg(target_os = "linux")]
    {
        let script = repo_dir.join("install-linux.sh");
        return Ok((script, "bash", vec![]));
    }
    #[cfg(target_os = "windows")]
    {
        let script = repo_dir.join("install-windows.ps1");
        return Ok((script, "powershell.exe", vec!["-ExecutionPolicy", "Bypass", "-File"]));
    }
    #[allow(unreachable_code)]
    {
        let _ = repo_dir;
        Err("unsupported platform".to_string())
    }
}

#[tauri::command]
async fn install_cowork(app: AppHandle, payload: InstallPayload) -> Result<i32, String> {
    emit_status(&app, "validating", "Validating input");
    if payload.app_name.trim().is_empty() {
        return Err("App name is required".to_string());
    }
    if payload.api_key.trim().is_empty() {
        return Err("API key is required".to_string());
    }
    // No default-model check — the shell installer picks Claude Sonnet 4.6
    // as the static default and loads the 5 newest models per family from
    // OpenRouter regardless of what we pass here.

    emit_status(&app, "checking-git", "Checking for git");
    if !check_git_available().await {
        return Err(
            "git was not found on your PATH. Install git (e.g. via Xcode Command Line Tools on macOS, winget on Windows, or your package manager on Linux) and try again.".to_string()
        );
    }

    emit_status(&app, "cloning", "Fetching installer files");
    let repo_dir = ensure_repo(&app).await?;

    emit_status(&app, "installing", "Running platform installer");
    let (script_path, executable, arg_prefix) = platform_script(&repo_dir)?;
    if !script_path.exists() {
        return Err(format!("Install script not found at {}", script_path.display()));
    }

    let mut cmd = Command::new(executable);
    for arg in &arg_prefix {
        cmd.arg(arg);
    }
    cmd.arg(&script_path);
    cmd.current_dir(&repo_dir);
    cmd.env("COWORK_APP_NAME", &payload.app_name);
    cmd.env("COWORK_API_KEY", &payload.api_key);
    // Only forward COWORK_DEFAULT_MODEL when the caller explicitly pinned one.
    // Otherwise leave it unset so the shell script's static Claude Sonnet 4.6
    // default applies cleanly.
    if let Some(model) = payload.default_model.as_ref().filter(|s| !s.trim().is_empty()) {
        cmd.env("COWORK_DEFAULT_MODEL", model);
    }
    if let Some(display) = payload.default_model_display.as_ref().filter(|s| !s.trim().is_empty()) {
        cmd.env("COWORK_DEFAULT_MODEL_DISPLAY", display);
    }
    // Pin the app build to the same branch the installer itself was built from,
    // so the installed app has all the feature-branch changes (Latest models,
    // etc.) during pre-merge testing. After merge to main, CLONE_BRANCH flips
    // to "main" and this env pass becomes a no-op.
    cmd.env("COWORK_GIT_BRANCH", CLONE_BRANCH);
    if let Some(icon) = payload.icon_path.as_ref().filter(|s| !s.trim().is_empty()) {
        cmd.env("COWORK_ICON_PATH", icon);
    }
    if let Some(logo) = payload.logo_path.as_ref().filter(|s| !s.trim().is_empty()) {
        cmd.env("COWORK_LOGO_PATH", logo);
    }
    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    let mut child = cmd
        .spawn()
        .map_err(|e| format!("failed to spawn installer script: {e}"))?;

    let stdout = child.stdout.take().ok_or("stdout not captured")?;
    let stderr = child.stderr.take().ok_or("stderr not captured")?;

    let app_stdout = app.clone();
    let stdout_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            emit_log(&app_stdout, "stdout", line);
        }
    });

    let app_stderr = app.clone();
    let stderr_task = tokio::spawn(async move {
        let mut reader = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            emit_log(&app_stderr, "stderr", line);
        }
    });

    let status = child
        .wait()
        .await
        .map_err(|e| format!("failed to wait for installer: {e}"))?;
    let _ = stdout_task.await;
    let _ = stderr_task.await;

    let code = status.code().unwrap_or(-1);
    if status.success() {
        emit_status(&app, "done", "Installation complete");
    } else {
        emit_status(&app, "error", &format!("Installer exited with code {code}"));
    }
    Ok(code)
}

#[tauri::command]
async fn open_openrouter_models_page(app: AppHandle) -> Result<(), String> {
    // Best-effort open browser to help users pick a model
    let url = "https://openrouter.ai/models";
    tauri_plugin_shell::ShellExt::shell(&app)
        .open(url, None)
        .map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let window = app.get_webview_window("main");
            if let Some(w) = window {
                let _ = w.show();
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![install_cowork, open_openrouter_models_page])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
