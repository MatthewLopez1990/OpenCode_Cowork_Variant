import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { open as openDialog } from '@tauri-apps/plugin-dialog';
import type { InstallPayload, LatestFamily, LogEvent, OpenRouterModel, StatusEvent } from './types';

type WizardStep = 'branding' | 'model' | 'install' | 'finish';

const FAMILY_LABELS: Record<LatestFamily, string> = {
  anthropic: 'Anthropic',
  openai: 'OpenAI',
  google: 'Google',
};

const FAMILY_ORDER: readonly LatestFamily[] = ['anthropic', 'openai', 'google'];

function familyOf(modelId: string): LatestFamily | null {
  if (modelId.startsWith('anthropic/')) return 'anthropic';
  if (modelId.startsWith('openai/')) return 'openai';
  if (modelId.startsWith('google/')) return 'google';
  return null;
}

export function App() {
  const [step, setStep] = useState<WizardStep>('branding');
  const [appName, setAppName] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [iconPath, setIconPath] = useState<string | undefined>();
  const [logoPath, setLogoPath] = useState<string | undefined>();
  const [defaultModel, setDefaultModel] = useState('');
  const [defaultModelDisplay, setDefaultModelDisplay] = useState('');

  const canAdvanceBranding = appName.trim().length > 0 && apiKey.trim().length > 0;
  const canAdvanceModel = defaultModel.trim().length > 0;

  return (
    <div className="app">
      <header className="app-header">
        <h1>OpenCode Cowork Installer</h1>
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
        {step === 'model' && (
          <ModelStep
            defaultModel={defaultModel}
            setDefaultModel={setDefaultModel}
            defaultModelDisplay={defaultModelDisplay}
            setDefaultModelDisplay={setDefaultModelDisplay}
          />
        )}
        {step === 'install' && (
          <InstallStep
            payload={{
              appName: appName.trim(),
              apiKey: apiKey.trim(),
              defaultModel: defaultModel.trim(),
              defaultModelDisplay: defaultModelDisplay.trim() || undefined,
              iconPath,
              logoPath,
            }}
            onDone={() => setStep('finish')}
          />
        )}
        {step === 'finish' && <FinishStep appName={appName} />}
      </main>
      {step !== 'install' && step !== 'finish' && (
        <footer className="app-footer">
          {step !== 'branding' && (
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setStep(step === 'model' ? 'branding' : 'model')}
            >
              Back
            </button>
          )}
          <div className="spacer" />
          <button
            type="button"
            className="btn btn-primary"
            disabled={step === 'branding' ? !canAdvanceBranding : !canAdvanceModel}
            onClick={() => setStep(step === 'branding' ? 'model' : 'install')}
          >
            {step === 'model' ? 'Install' : 'Continue'}
          </button>
        </footer>
      )}
    </div>
  );
}

function StepIndicator({ current }: { current: WizardStep }) {
  const steps: Array<{ key: WizardStep; label: string }> = [
    { key: 'branding', label: 'Branding' },
    { key: 'model', label: 'Model' },
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
        Assets are optional — defaults will be used if omitted.
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

function ModelStep(props: {
  defaultModel: string;
  setDefaultModel: (v: string) => void;
  defaultModelDisplay: string;
  setDefaultModelDisplay: (v: string) => void;
}) {
  const [models, setModels] = useState<OpenRouterModel[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeFamily, setActiveFamily] = useState<LatestFamily>('anthropic');
  const [customMode, setCustomMode] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const resp = await fetch('https://openrouter.ai/api/v1/models', {
          headers: { Accept: 'application/json' },
        });
        if (!resp.ok) throw new Error(`OpenRouter returned ${resp.status}`);
        const json = (await resp.json()) as { data?: OpenRouterModel[] };
        if (cancelled) return;
        setModels(Array.isArray(json.data) ? json.data : []);
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const familyModels = useMemo(() => {
    const result: Record<LatestFamily, OpenRouterModel[]> = {
      anthropic: [],
      openai: [],
      google: [],
    };
    if (!models) return result;
    for (const model of models) {
      const fam = familyOf(model.id);
      if (!fam) continue;
      result[fam].push(model);
    }
    for (const fam of FAMILY_ORDER) {
      result[fam].sort((a, b) => (b.created ?? 0) - (a.created ?? 0));
    }
    return result;
  }, [models]);

  // Pre-select the latest model of the currently-focused family on first load
  useEffect(() => {
    if (props.defaultModel || !models) return;
    for (const fam of FAMILY_ORDER) {
      const first = familyModels[fam][0];
      if (first) {
        props.setDefaultModel(first.id);
        props.setDefaultModelDisplay(first.name || first.id);
        setActiveFamily(fam);
        return;
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [models]);

  return (
    <div className="step">
      <h2>Pick the default model</h2>
      <p className="muted">
        End users can change this later. Models are fetched live from OpenRouter —
        the newest of each family is pre-selected.
      </p>

      {error && (
        <div className="alert alert-error">
          Failed to load models: {error}. You can still enter a model ID by hand below.
        </div>
      )}

      <div className="family-tabs">
        {FAMILY_ORDER.map((fam) => (
          <button
            key={fam}
            type="button"
            className={`family-tab${activeFamily === fam && !customMode ? ' active' : ''}`}
            onClick={() => {
              setCustomMode(false);
              setActiveFamily(fam);
            }}
          >
            {FAMILY_LABELS[fam]}
            <span className="family-count">{familyModels[fam].length}</span>
          </button>
        ))}
        <button
          type="button"
          className={`family-tab${customMode ? ' active' : ''}`}
          onClick={() => setCustomMode(true)}
        >
          Custom
        </button>
      </div>

      {customMode ? (
        <div className="custom-model">
          <label className="field">
            <span>Model ID</span>
            <input
              type="text"
              value={props.defaultModel}
              onChange={(e) => props.setDefaultModel(e.target.value)}
              placeholder="anthropic/claude-sonnet-4.5"
            />
            <span className="field-hint">
              Any model ID from openrouter.ai/models is valid.
            </span>
          </label>
          <label className="field">
            <span>Display name (optional)</span>
            <input
              type="text"
              value={props.defaultModelDisplay}
              onChange={(e) => props.setDefaultModelDisplay(e.target.value)}
              placeholder="Defaults to the model ID"
            />
          </label>
        </div>
      ) : models === null && !error ? (
        <div className="muted">Loading models from OpenRouter…</div>
      ) : (
        <div className="model-list">
          {familyModels[activeFamily].length === 0 && (
            <div className="muted">No {FAMILY_LABELS[activeFamily]} models found.</div>
          )}
          {familyModels[activeFamily].map((m) => {
            const selected = m.id === props.defaultModel;
            return (
              <button
                key={m.id}
                type="button"
                className={`model-row${selected ? ' selected' : ''}`}
                onClick={() => {
                  props.setDefaultModel(m.id);
                  props.setDefaultModelDisplay(m.name || m.id);
                }}
              >
                <div className="model-main">
                  <span className="model-name">{m.name || m.id}</span>
                  <span className="model-id">{m.id}</span>
                </div>
                <div className="model-meta">
                  {m.created ? new Date(m.created * 1000).toISOString().slice(0, 10) : ''}
                </div>
              </button>
            );
          })}
        </div>
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
