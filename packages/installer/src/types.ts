export interface InstallPayload {
  appName: string;
  apiKey: string;
  defaultModel: string;
  defaultModelDisplay?: string;
  iconPath?: string;
  logoPath?: string;
}

export interface OpenRouterModel {
  id: string;
  name?: string;
  description?: string;
  created?: number;
  context_length?: number;
}

export type LatestFamily = 'anthropic' | 'openai' | 'google';

export interface LogEvent {
  stream: 'stdout' | 'stderr' | 'system';
  line: string;
}

export interface StatusEvent {
  stage: string;
  message: string;
}
