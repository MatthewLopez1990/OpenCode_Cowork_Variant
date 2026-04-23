import React, { useEffect, useRef, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { open as openDialog } from '@tauri-apps/plugin-dialog';
import type { InstallPayload, LogEvent, StatusEvent } from './types';

type WizardStep = 'branding' | 'install' | 'finish';

// Default name pre-filled in the App Name field. Users can override if they
// want a different white-label brand.
const DEFAULT_APP_NAME = 'ChatFortAI Cowork';

export function App() {
  const [step, setStep] = useState<WizardStep>('branding');
  const [appName, setAppName] = useState(DEFAULT_APP_NAME);
  const [apiKey, setApiKey] = useState('');
  const [iconPath, setIconPath] = useState<string | undefined>();
  const [logoPath, setLogoPath] = useState<string | undefined>();

  const canAdvanceBranding = appName.trim().length > 0 && apiKey.trim().length > 0;

  return (
    <div className="app">
      <header className="app-header">
        <h1>ChatFortAI Cowork Installer</h1>
        <StepIndicator current={step} />
      </header>
      <main className="app-body">
        {step === 'branding' && (
          <BrandingStep
            appName={appName}
            setAppName={setAppName}
            apiKey={apiKey}
            setApiKey={setApiKey}
            iconPath={iconPath}
            setIconPath={setIconPath}
            logoPath={logoPath}
            setLogoPath={setLogoPath}
          />
        )}
        {step === 'install' && (
          <InstallStep
            payload={{
              appName: appName.trim(),
              apiKey: apiKey.trim(),
              // Model handling is automatic: the shell installer fetches the
              // 5 newest Anthropic/OpenAI/Google models from OpenRouter and
              // loads them all. These payload fields are kept for backward
              // compatibility with the Rust command signature.
              defaultModel: '',
              defaultModelDisplay: undefined,
              iconPath,
              logoPath,
            }}
            onDone={() => setStep('finish')}
          />
        )}
        {step === 'finish' && <FinishStep appName={appName} />}
      </main>
      {step === 'branding' && (
        <footer className="app-footer">
          <div className="spacer" />
          <button
            type="button"
            className="btn btn-primary"
            disabled={!canAdvanceBranding}
            onClick={() => setStep('install')}
          >
            Install
          </button>
        </footer>
      )}
    </div>
  );
}

function StepIndicator({ current }: { current: WizardStep }) {
  const steps: Array<{ key: WizardStep; label: string }> = [
    { key: 'branding', label: 'Branding' },
    { key: 'install', label: 'Install' },
    { key: 'finish', label: 'Finish' },
  ];
  const currentIndex = steps.findIndex((s) => s.key === current);
  return (
    <ol className="step-indicator">
      {steps.map((s, i) => (
        <li
          key={s.key}
          className={
            i === currentIndex ? 'active' : i < currentIndex ? 'done' : 'upcoming'
          }
        >
          <span className="step-number">{i + 1}</span>
          <span className="step-label">{s.label}</span>
        </li>
      ))}
    </ol>
  );
}

function BrandingStep(props: {
  appName: string;
  setAppName: (v: string) => void;
  apiKey: string;
  setApiKey: (v: string) => void;
  iconPath: string | undefined;
  setIconPath: (v: string | undefined) => void;
  logoPath: string | undefined;
  setLogoPath: (v: string | undefined) => void;
}) {
  const pickFile = async (setter: (v: string | undefined) => void) => {
    const selected = await openDialog({
      multiple: false,
      filters: [{ name: 'PNG images', extensions: ['png'] }],
    });
    if (typeof selected === 'string' && selected.length > 0) {
      setter(selected);
    }
  };

  return (
    <div className="step">
      <h2>Brand your app</h2>
      <p className="muted">
        End users will see this name everywhere — the title bar, the install prompt, and the
        provider label inside the chat UI.
      </p>

      <label className="field">
        <span>App name</span>
        <input
          type="text"
          value={props.appName}
          onChange={(e) => props.setAppName(e.target.value)}
          placeholder="Acme AI Assistant"
          autoFocus
        />
      </label>

      <label className="field">
        <span>OpenRouter API key</span>
        <input
          type="password"
          value={props.apiKey}
          onChange={(e) => props.setApiKey(e.target.value)}
          placeholder="sk-or-v1-..."
          autoComplete="off"
        />
        <span className="field-hint">
          Get one at <span className="code">openrouter.ai/keys</span>
        </span>
      </label>

      <div className="asset-row">
        <AssetDrop
          label="Icon (PNG, 512×512+)"
          path={props.iconPath}
          onPick={() => pickFile(props.setIconPath)}
          onClear={() => props.setIconPath(undefined)}
        />
        <AssetDrop
          label="Logo (PNG)"
          path={props.logoPath}
          onPick={() => pickFile(props.setLogoPath)}
          onClear={() => props.setLogoPath(undefined)}
        />
      </div>
      <p className="muted small">
        Assets are optional — ChatFortAI defaults will be used if omitted. Models
        are loaded automatically: the 5 newest from Anthropic, OpenAI, and Google,
        with Claude Sonnet as the starting default.
      </p>
    </div>
  );
}

function AssetDrop(props: {
  label: string;
  path: string | undefined;
  onPick: () => void;
  onClear: () => void;
}) {
  const basename = props.path ? props.path.split(/[\\/]/).pop() : undefined;
  return (
    <div className={`asset-drop${props.path ? ' has-file' : ''}`}>
      <div className="asset-drop-label">{props.label}</div>
      {props.path ? (
        <>
          <div className="asset-file" title={props.path}>
            {basename}
          </div>
          <button type="button" className="btn btn-link" onClick={props.onClear}>
            Remove
          </button>
        </>
      ) : (
        <button type="button" className="btn btn-secondary" onClick={props.onPick}>
          Choose PNG…
        </button>
      )}
    </div>
  );
}

function InstallStep(props: { payload: InstallPayload; onDone: () => void }) {
  const [lines, setLines] = useState<LogEvent[]>([]);
  const [status, setStatus] = useState<StatusEvent>({ stage: 'starting', message: 'Starting…' });
  const [exitCode, setExitCode] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const logRef = useRef<HTMLDivElement>(null);
  const startedRef = useRef(false);

  useEffect(() => {
    const unlistenLog = listen<LogEvent>('install:log', (e) => {
      setLines((prev) => [...prev, e.payload]);
    });
    const unlistenStatus = listen<StatusEvent>('install:status', (e) => {
      setStatus(e.payload);
    });
    return () => {
      unlistenLog.then((fn) => fn());
      unlistenStatus.then((fn) => fn());
    };
  }, []);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    (async () => {
      try {
        const code = await invoke<number>('install_cowork', { payload: props.payload });
        setExitCode(code);
        if (code === 0) {
          setTimeout(() => props.onDone(), 600);
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (logRef.current) {
      logRef.current.scrollTop = logRef.current.scrollHeight;
    }
  }, [lines]);

  const statusClass =
    status.stage === 'error' || exitCode !== null && exitCode !== 0 || error
      ? 'status-error'
      : status.stage === 'done'
      ? 'status-done'
      : 'status-running';

  return (
    <div className="step">
      <h2>Installing {props.payload.appName}</h2>
      <div className={`install-status ${statusClass}`}>
        <span className="dot" />
        {error ? error : `${status.stage}: ${status.message}`}
      </div>
      <div className="log" ref={logRef}>
        {lines.map((l, idx) => (
          <div key={idx} className={`log-line log-${l.stream}`}>
            {l.line}
          </div>
        ))}
      </div>
      {(exitCode !== null && exitCode !== 0) && (
        <div className="alert alert-error">
          Installer exited with code {exitCode}. Scroll the log for details.
        </div>
      )}
    </div>
  );
}

function FinishStep({ appName }: { appName: string }) {
  return (
    <div className="step finish">
      <h2>Done — {appName || 'your app'} is installed</h2>
      <p className="muted">
        Look for <strong>{appName || 'the app'}</strong> in your Applications
        folder (macOS), Start Menu (Windows), or application launcher (Linux).
      </p>
      <p className="muted small">
        You can close this installer now.
      </p>
    </div>
  );
}
