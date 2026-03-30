package theme

import (
	"github.com/charmbracelet/lipgloss"
)

// SpencerFaneTheme implements the Theme interface with Spencer Fane brand colors.
type SpencerFaneTheme struct {
	BaseTheme
}

// NewSpencerFaneTheme creates a new instance of the Spencer Fane theme.
func NewSpencerFaneTheme() *SpencerFaneTheme {
	// Spencer Fane brand palette
	darkBackground := "#1A2332"
	darkCurrentLine := "#1E2A3A"
	darkSelection := "#2A3A4A"
	darkForeground := "#E0E6ED"
	darkComment := "#6B8A9E"
	darkPrimary := "#0076D6"    // Spencer Fane blue
	darkSecondary := "#6B8A9E"  // Steel gray
	darkAccent := "#2B8FC7"     // Light blue accent
	darkRed := "#E06C75"
	darkOrange := "#F5A742"
	darkGreen := "#7FD88F"
	darkCyan := "#2B8FC7"
	darkYellow := "#E5C07B"
	darkBorder := "#3A4A5C"

	lightBackground := "#F5F7FA"
	lightCurrentLine := "#EDF0F5"
	lightSelection := "#D8DDE5"
	lightForeground := "#1A2332"
	lightComment := "#7A8A9A"
	lightPrimary := "#0076D6"
	lightSecondary := "#6B8A9E"
	lightAccent := "#2B8FC7"
	lightRed := "#D1383D"
	lightOrange := "#D68C27"
	lightGreen := "#3D9A57"
	lightCyan := "#2B8FC7"
	lightYellow := "#B0851F"
	lightBorder := "#C8CED6"

	theme := &SpencerFaneTheme{}

	theme.PrimaryColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.SecondaryColor = lipgloss.AdaptiveColor{Dark: darkSecondary, Light: lightSecondary}
	theme.AccentColor = lipgloss.AdaptiveColor{Dark: darkAccent, Light: lightAccent}

	theme.ErrorColor = lipgloss.AdaptiveColor{Dark: darkRed, Light: lightRed}
	theme.WarningColor = lipgloss.AdaptiveColor{Dark: darkOrange, Light: lightOrange}
	theme.SuccessColor = lipgloss.AdaptiveColor{Dark: darkGreen, Light: lightGreen}
	theme.InfoColor = lipgloss.AdaptiveColor{Dark: darkCyan, Light: lightCyan}

	theme.TextColor = lipgloss.AdaptiveColor{Dark: darkForeground, Light: lightForeground}
	theme.TextMutedColor = lipgloss.AdaptiveColor{Dark: darkComment, Light: lightComment}
	theme.TextEmphasizedColor = lipgloss.AdaptiveColor{Dark: darkYellow, Light: lightYellow}

	theme.BackgroundColor = lipgloss.AdaptiveColor{Dark: darkBackground, Light: lightBackground}
	theme.BackgroundSecondaryColor = lipgloss.AdaptiveColor{Dark: darkCurrentLine, Light: lightCurrentLine}
	theme.BackgroundDarkerColor = lipgloss.AdaptiveColor{Dark: "#121A26", Light: "#FFFFFF"}

	theme.BorderNormalColor = lipgloss.AdaptiveColor{Dark: darkBorder, Light: lightBorder}
	theme.BorderFocusedColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.BorderDimColor = lipgloss.AdaptiveColor{Dark: darkSelection, Light: lightSelection}

	theme.DiffAddedColor = lipgloss.AdaptiveColor{Dark: "#478247", Light: "#2E7D32"}
	theme.DiffRemovedColor = lipgloss.AdaptiveColor{Dark: "#7C4444", Light: "#C62828"}
	theme.DiffContextColor = lipgloss.AdaptiveColor{Dark: "#A0A0A0", Light: "#757575"}
	theme.DiffHunkHeaderColor = lipgloss.AdaptiveColor{Dark: "#A0A0A0", Light: "#757575"}
	theme.DiffHighlightAddedColor = lipgloss.AdaptiveColor{Dark: "#DAFADA", Light: "#A5D6A7"}
	theme.DiffHighlightRemovedColor = lipgloss.AdaptiveColor{Dark: "#FADADD", Light: "#EF9A9A"}
	theme.DiffAddedBgColor = lipgloss.AdaptiveColor{Dark: "#1E3A2E", Light: "#E8F5E9"}
	theme.DiffRemovedBgColor = lipgloss.AdaptiveColor{Dark: "#3A1E1E", Light: "#FFEBEE"}
	theme.DiffContextBgColor = lipgloss.AdaptiveColor{Dark: darkBackground, Light: lightBackground}
	theme.DiffLineNumberColor = lipgloss.AdaptiveColor{Dark: "#6B8A9E", Light: "#9E9E9E"}
	theme.DiffAddedLineNumberBgColor = lipgloss.AdaptiveColor{Dark: "#1A3226", Light: "#C8E6C9"}
	theme.DiffRemovedLineNumberBgColor = lipgloss.AdaptiveColor{Dark: "#331A1A", Light: "#FFCDD2"}

	theme.MarkdownTextColor = lipgloss.AdaptiveColor{Dark: darkForeground, Light: lightForeground}
	theme.MarkdownHeadingColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.MarkdownLinkColor = lipgloss.AdaptiveColor{Dark: darkAccent, Light: lightAccent}
	theme.MarkdownLinkTextColor = lipgloss.AdaptiveColor{Dark: darkCyan, Light: lightCyan}
	theme.MarkdownCodeColor = lipgloss.AdaptiveColor{Dark: darkGreen, Light: lightGreen}
	theme.MarkdownBlockQuoteColor = lipgloss.AdaptiveColor{Dark: darkYellow, Light: lightYellow}
	theme.MarkdownEmphColor = lipgloss.AdaptiveColor{Dark: darkYellow, Light: lightYellow}
	theme.MarkdownStrongColor = lipgloss.AdaptiveColor{Dark: darkAccent, Light: lightAccent}
	theme.MarkdownHorizontalRuleColor = lipgloss.AdaptiveColor{Dark: darkComment, Light: lightComment}
	theme.MarkdownListItemColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.MarkdownListEnumerationColor = lipgloss.AdaptiveColor{Dark: darkCyan, Light: lightCyan}
	theme.MarkdownImageColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.MarkdownImageTextColor = lipgloss.AdaptiveColor{Dark: darkCyan, Light: lightCyan}
	theme.MarkdownCodeBlockColor = lipgloss.AdaptiveColor{Dark: darkForeground, Light: lightForeground}

	theme.SyntaxCommentColor = lipgloss.AdaptiveColor{Dark: darkComment, Light: lightComment}
	theme.SyntaxKeywordColor = lipgloss.AdaptiveColor{Dark: darkPrimary, Light: lightPrimary}
	theme.SyntaxFunctionColor = lipgloss.AdaptiveColor{Dark: darkAccent, Light: lightAccent}
	theme.SyntaxVariableColor = lipgloss.AdaptiveColor{Dark: darkRed, Light: lightRed}
	theme.SyntaxStringColor = lipgloss.AdaptiveColor{Dark: darkGreen, Light: lightGreen}
	theme.SyntaxNumberColor = lipgloss.AdaptiveColor{Dark: darkAccent, Light: lightAccent}
	theme.SyntaxTypeColor = lipgloss.AdaptiveColor{Dark: darkYellow, Light: lightYellow}
	theme.SyntaxOperatorColor = lipgloss.AdaptiveColor{Dark: darkCyan, Light: lightCyan}
	theme.SyntaxPunctuationColor = lipgloss.AdaptiveColor{Dark: darkForeground, Light: lightForeground}

	return theme
}

func init() {
	RegisterTheme("spencer-fane", NewSpencerFaneTheme())
}
