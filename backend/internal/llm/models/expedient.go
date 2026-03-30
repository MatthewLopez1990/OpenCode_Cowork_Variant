package models

const (
	ProviderExpedient ModelProvider = "expedient"

	ExpedientClaude45Sonnet ModelID = "expedient.claude-sonnet-4-5"
	ExpedientClaude46Sonnet ModelID = "expedient.claude-sonnet-4-6"
	ExpedientClaude46Opus   ModelID = "expedient.claude-opus-4-6"
	ExpedientGPT52          ModelID = "expedient.gpt-5.2"
	ExpedientGPT53Codex     ModelID = "expedient.gpt-5.3-codex"
	ExpedientGPT54          ModelID = "expedient.gpt-5.4"
)

var ExpedientModels = map[ModelID]Model{
	ExpedientClaude45Sonnet: {
		ID:                  ExpedientClaude45Sonnet,
		Name:                "Claude 4.5 Sonnet (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "claude-sonnet-4-5-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       200000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
	ExpedientClaude46Sonnet: {
		ID:                  ExpedientClaude46Sonnet,
		Name:                "Claude 4.6 Sonnet (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "claude-sonnet-4-6-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       200000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
	ExpedientClaude46Opus: {
		ID:                  ExpedientClaude46Opus,
		Name:                "Claude 4.6 Opus (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "claude-opus-4-6-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       200000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
	ExpedientGPT52: {
		ID:                  ExpedientGPT52,
		Name:                "GPT-5.2 (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "gpt-5.2-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       128000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
	ExpedientGPT53Codex: {
		ID:                  ExpedientGPT53Codex,
		Name:                "GPT-5.3 Codex (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "gpt-5.3-codex-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       128000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
	ExpedientGPT54: {
		ID:                  ExpedientGPT54,
		Name:                "GPT-5.4 (Expedient)",
		Provider:            ProviderExpedient,
		APIModel:            "gpt-5.4-opencode",
		CostPer1MIn:         0,
		CostPer1MOut:        0,
		ContextWindow:       128000,
		DefaultMaxTokens:    16384,
		SupportsAttachments: true,
	},
}
