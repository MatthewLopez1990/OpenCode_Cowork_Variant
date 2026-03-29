const { app, BrowserWindow, shell, dialog, nativeImage, Tray } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const net = require('net');
const fs = require('fs');
const os = require('os');

let mainWindow = null;
let serverProcess = null;
let serverPort = null;
let tray = null;

// Read app name from branding config or default
const BRANDING_FILE = path.join(os.homedir(), '.cowork-branding.json');
let APP_NAME = 'OpenCode Cowork';
try {
  if (fs.existsSync(BRANDING_FILE)) {
    const branding = JSON.parse(fs.readFileSync(BRANDING_FILE, 'utf8'));
    if (branding.appName) APP_NAME = branding.appName;
  }
} catch (e) {}

// Sandbox: auto-inject CLAUDE.md into every project directory
// Reads from the user's customized template saved during install
const SANDBOX_TEMPLATE = path.join(os.homedir(), '.config', 'opencode', 'sandbox', 'CLAUDE.md.template');

function ensureSandboxRules(directory) {
  if (!directory) return;
  const claudePath = path.join(directory, 'CLAUDE.md');
  try {
    // Read the user's customized template
    let rules = '';
    if (fs.existsSync(SANDBOX_TEMPLATE)) {
      rules = fs.readFileSync(SANDBOX_TEMPLATE, 'utf8');
    }
    if (!rules) return; // No template = no injection

    fs.writeFileSync(claudePath, rules, 'utf8');
    // On Windows: hide the file
    if (process.platform === 'win32') {
      try {
        const { execSync } = require('child_process');
        execSync(`attrib +H +S "${claudePath}"`, { stdio: 'ignore', timeout: 5000 });
      } catch (e) {}
    }
  } catch (e) {}
}

const BUILD_DIR_NAME = '.opencode-cowork-build';

function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      server.close(() => resolve(port));
    });
    server.on('error', reject);
  });
}

function findBuildDir() {
  const home = os.homedir();
  const candidates = [
    path.join(home, BUILD_DIR_NAME),
    path.join(home, 'opencode-cowork'),
    path.join(__dirname, '..'),
  ];

  for (const dir of candidates) {
    const serverFile = path.join(dir, 'packages', 'web', 'server', 'index.js');
    const distDir = path.join(dir, 'packages', 'web', 'dist');
    if (fs.existsSync(serverFile) && fs.existsSync(distDir)) {
      return dir;
    }
  }
  return null;
}

function findRuntime() {
  const home = os.homedir();
  const bunPaths = process.platform === 'win32'
    ? [path.join(home, '.bun', 'bin', 'bun.exe')]
    : [
        path.join(home, '.bun', 'bin', 'bun'),
        '/usr/local/bin/bun',
        '/opt/homebrew/bin/bun',
      ];

  for (const p of bunPaths) {
    if (fs.existsSync(p)) return p;
  }

  try {
    const cmd = process.platform === 'win32' ? 'where bun' : 'which bun';
    const result = execSync(cmd, { encoding: 'utf8', timeout: 5000 }).trim();
    if (result) return result.split(/\r?\n/)[0].trim();
  } catch {}

  return null;
}

function getIconPath() {
  const home = os.homedir();
  const locations = [];

  if (app.isPackaged) {
    locations.push(path.join(process.resourcesPath, 'icon.png'));
    locations.push(path.join(process.resourcesPath, 'icon.ico'));
  }

  const buildDirs = [
    path.join(home, BUILD_DIR_NAME),
    path.join(__dirname, '..'),
  ];

  for (const dir of buildDirs) {
    locations.push(path.join(dir, 'branding', 'icon.ico'));
    locations.push(path.join(dir, 'branding', 'icon.png'));
    locations.push(path.join(dir, 'packages', 'web', 'public', 'favicon.png'));
  }

  for (const p of locations) {
    if (fs.existsSync(p)) return p;
  }
  return undefined;
}

function getNativeIcon() {
  const iconPath = getIconPath();
  if (iconPath) {
    try { return nativeImage.createFromPath(iconPath); } catch {}
  }
  return undefined;
}

async function startBrandedServer(buildDir, runtime) {
  const port = await findFreePort();
  serverPort = port;

  const serverScript = path.join(buildDir, 'packages', 'web', 'server', 'index.js');
  console.log(`Starting ${APP_NAME} server on port ${port}...`);

  serverProcess = spawn(runtime, [serverScript, '--port', String(port)], {
    cwd: buildDir,
    env: {
      ...process.env,
      PORT: String(port),
      OPENCHAMBER_PORT: String(port),
      NODE_ENV: 'production',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
    detached: process.platform === 'win32',
  });

  if (process.platform === 'win32') {
    serverProcess.unref();
  }

  serverProcess.stdout.on('data', (d) => console.log(`[server] ${d.toString().trim()}`));
  serverProcess.stderr.on('data', (d) => console.error(`[server] ${d.toString().trim()}`));
  serverProcess.on('exit', (code) => {
    console.log(`Server exited: ${code}`);
    serverProcess = null;
  });

  const maxWait = 30000;
  const start = Date.now();
  while (Date.now() - start < maxWait) {
    try {
      await new Promise((resolve, reject) => {
        const req = require('http').get(`http://127.0.0.1:${port}/`, (res) => resolve(res.statusCode));
        req.on('error', reject);
        req.setTimeout(2000, () => { req.destroy(); reject(new Error('timeout')); });
      });
      console.log(`${APP_NAME} server ready on port ${port}`);
      return port;
    } catch {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  throw new Error('Server failed to start within 30 seconds');
}

function createWindow(port) {
  const icon = getNativeIcon();

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 850,
    minWidth: 800,
    minHeight: 600,
    title: APP_NAME,
    icon: icon,
    titleBarStyle: 'default',
    webPreferences: { nodeIntegration: false, contextIsolation: true },
    show: false,
    backgroundColor: '#1A2332',
  });

  if (icon && process.platform === 'win32') {
    mainWindow.setIcon(icon);
  }

  mainWindow.loadURL(`http://127.0.0.1:${port}`);
  mainWindow.once('ready-to-show', () => mainWindow.show());

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http')) shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

app.setName(APP_NAME);

app.whenReady().then(async () => {
  try {
    const buildDir = findBuildDir();
    if (!buildDir) {
      await dialog.showMessageBox({
        type: 'error',
        title: `${APP_NAME} Not Found`,
        message: `Could not find the ${APP_NAME} installation.`,
        detail: 'Run the install script first.',
        buttons: ['OK'],
      });
      app.quit();
      return;
    }

    const runtime = findRuntime();
    if (!runtime) {
      await dialog.showMessageBox({
        type: 'error',
        title: 'Bun Not Found',
        message: `${APP_NAME} requires Bun to run.`,
        detail: 'Install Bun from: https://bun.sh\n\nThen restart.',
        buttons: ['OK'],
      });
      app.quit();
      return;
    }

    console.log(`Build dir: ${buildDir}`);
    // Inject sandbox rules into the build directory (where OpenCode runs from)
    ensureSandboxRules(buildDir);
    const port = await startBrandedServer(buildDir, runtime);
    createWindow(port);
  } catch (err) {
    console.error('Startup error:', err);
    dialog.showErrorBox(APP_NAME, `Failed to start: ${err.message}`);
    app.quit();
  }
});

app.on('window-all-closed', () => {
  if (serverProcess) {
    try { serverProcess.kill(); } catch {}
    serverProcess = null;
  }
  app.quit();
});

app.on('before-quit', () => {
  if (serverProcess) {
    try { serverProcess.kill(); } catch {}
    serverProcess = null;
  }
});

app.on('activate', () => {
  if (mainWindow === null && serverPort) createWindow(serverPort);
});
