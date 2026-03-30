package tui

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/opencode-ai/opencode/internal/tui/components/chat"
	"github.com/opencode-ai/opencode/internal/tui/components/dialog"
	"github.com/opencode-ai/opencode/internal/tui/util"
)

func legalCmd(prompt string) func(dialog.Command) tea.Cmd {
	return func(_ dialog.Command) tea.Cmd {
		return tea.Batch(util.CmdHandler(chat.SendMsg{Text: prompt}))
	}
}

// RegisterLegalCommands adds Spencer Fane legal slash commands to the command palette.
func RegisterLegalCommands(model *appModel) {
	cmds := []dialog.Command{
		{
			ID:          "memo",
			Title:       "/memo — Legal Memorandum",
			Description: "Draft a legal memorandum with standard sections",
			Handler: legalCmd("Draft a legal memorandum. Include: Question Presented, Brief Answer, Statement of Facts, Discussion (with Bluebook citations), and Conclusion. Default jurisdiction: Missouri. Include disclaimer: 'This is AI-generated content for attorney review and does not constitute legal advice.'"),
		},
		{
			ID:          "brief",
			Title:       "/brief — Legal Brief",
			Description: "Draft a legal brief or motion brief",
			Handler: legalCmd("Draft a legal brief. Include: Caption, Table of Contents, Table of Authorities, Statement of Issues, Statement of Facts, Argument (with Bluebook citations), and Conclusion. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "contract",
			Title:       "/contract — Contract Drafting",
			Description: "Draft or review a contract",
			Handler: legalCmd("Help draft a contract. Ask me about the parties, subject matter, key terms, and governing law. Use standard contract provisions (recitals, definitions, representations, covenants, conditions, remedies, boilerplate). Default governing law: Missouri. Include disclaimer."),
		},
		{
			ID:          "review",
			Title:       "/review — Document Review",
			Description: "Review a legal document for issues",
			Handler: legalCmd("Review the provided legal document. Identify: potential issues, ambiguities, missing provisions, unfavorable terms, inconsistencies, and compliance concerns. Provide specific recommendations with references to the document text. Include disclaimer."),
		},
		{
			ID:          "research",
			Title:       "/research — Legal Research",
			Description: "Conduct legal research on a topic",
			Handler: legalCmd("Conduct legal research on the topic I'll describe. Identify: applicable statutes, key case law, regulatory guidance, and secondary sources. Use Bluebook citation format. Note any circuit splits or evolving areas of law. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "summarize",
			Title:       "/summarize — Case/Document Summary",
			Description: "Summarize a case, statute, or document",
			Handler: legalCmd("Summarize the legal document or case I'll provide. Include: key facts, legal issues, holdings/provisions, reasoning, and practical implications. Use Bluebook citations. Include disclaimer."),
		},
		{
			ID:          "compare",
			Title:       "/compare — Legal Comparison",
			Description: "Compare legal authorities or documents",
			Handler: legalCmd("Compare the legal authorities or documents I'll identify. Create a structured comparison covering: key provisions, differences, similarities, implications, and recommendations. Include Bluebook citations. Include disclaimer."),
		},
		{
			ID:          "draft",
			Title:       "/draft — General Legal Drafting",
			Description: "Draft a legal document",
			Handler: legalCmd("Help me draft a legal document. Ask me about the type of document, parties, purpose, and key provisions. Follow applicable legal conventions and formatting. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "analyze",
			Title:       "/analyze — Legal Analysis",
			Description: "Analyze a legal issue or scenario",
			Handler: legalCmd("Analyze the legal issue I'll describe. Apply the IRAC method (Issue, Rule, Application, Conclusion). Identify applicable law, analyze facts against legal standards, and provide a reasoned conclusion. Use Bluebook citations. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "explain",
			Title:       "/explain — Legal Explanation",
			Description: "Explain a legal concept in plain language",
			Handler: legalCmd("Explain the following legal concept in plain language suitable for a client or non-lawyer. Include key points, practical implications, and relevant examples. Avoid jargon where possible. Include disclaimer."),
		},
		{
			ID:          "timeline",
			Title:       "/timeline — Legal Timeline",
			Description: "Create a timeline of events or deadlines",
			Handler: legalCmd("Create a chronological timeline for the matter I'll describe. Include: key dates, filing deadlines, statute of limitations, contractual deadlines, and procedural milestones. Flag any approaching or critical deadlines. Include disclaimer."),
		},
		{
			ID:          "checklist",
			Title:       "/checklist — Legal Checklist",
			Description: "Generate a legal checklist",
			Handler: legalCmd("Generate a comprehensive legal checklist for the task I'll describe. Include all required steps, filings, approvals, and considerations. Organize by phase or priority. Include disclaimer."),
		},
		{
			ID:          "cite",
			Title:       "/cite — Citation Formatting",
			Description: "Format or verify Bluebook citations",
			Handler: legalCmd("Format the following legal references in proper Bluebook citation format. Verify citation accuracy and provide both full and short-form citations. Include disclaimer."),
		},
		{
			ID:          "outline",
			Title:       "/outline — Argument Outline",
			Description: "Create an argument or document outline",
			Handler: legalCmd("Create a detailed outline for the legal argument or document I'll describe. Include main points, sub-arguments, supporting authorities, and counterarguments to address. Use Bluebook citations. Include disclaimer."),
		},
		{
			ID:          "discovery",
			Title:       "/discovery — Discovery Requests",
			Description: "Draft discovery requests or responses",
			Handler: legalCmd("Help draft discovery requests or responses for the matter I'll describe. Follow applicable rules of civil procedure. Include instructions, definitions, and properly numbered requests. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "deposition",
			Title:       "/deposition — Deposition Prep",
			Description: "Prepare deposition questions or outlines",
			Handler: legalCmd("Prepare a deposition outline for the witness and matter I'll describe. Include: background questions, topic areas, key document references, and follow-up lines of questioning. Organize by topic. Include disclaimer."),
		},
		{
			ID:          "motion",
			Title:       "/motion — Motion Drafting",
			Description: "Draft a motion or motion response",
			Handler: legalCmd("Draft a motion for the matter I'll describe. Include: caption, introduction, statement of facts, legal standard, argument with Bluebook citations, and proposed order. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "letter",
			Title:       "/letter — Legal Correspondence",
			Description: "Draft a legal letter",
			Handler: legalCmd("Draft a professional legal letter. Ask me about the recipient, purpose, and key points. Follow standard legal correspondence format. Include appropriate legal disclaimers and confidentiality notices. Include disclaimer."),
		},
		{
			ID:          "redline",
			Title:       "/redline — Redline Review",
			Description: "Compare and redline document versions",
			Handler: legalCmd("Compare the document versions I'll provide. Identify all changes, categorize them (substantive vs. non-substantive), flag potentially problematic changes, and provide recommendations. Include disclaimer."),
		},
		{
			ID:          "risk",
			Title:       "/risk — Risk Assessment",
			Description: "Assess legal risks in a scenario",
			Handler: legalCmd("Assess the legal risks in the scenario I'll describe. For each risk: identify the issue, assess likelihood and severity, cite applicable law, and recommend mitigation strategies. Use Bluebook citations. Default jurisdiction: Missouri. Include disclaimer."),
		},
		{
			ID:          "privilege",
			Title:       "/privilege — Privilege Analysis",
			Description: "Analyze privilege issues",
			Handler: legalCmd("Analyze the privilege issues in the scenario I'll describe. Consider: attorney-client privilege, work product doctrine, common interest doctrine, and potential waiver issues. Cite applicable law. Default jurisdiction: Missouri. Include disclaimer."),
		},
	}

	for _, cmd := range cmds {
		model.RegisterCommand(cmd)
	}
}
