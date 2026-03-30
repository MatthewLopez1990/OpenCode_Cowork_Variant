---
description: Review a contract against your organization's negotiation playbook — flag deviations, generate redlines, provide business impact analysis
argument-hint: "<contract file or text>"
---

# /review-contract -- Contract Review Against Playbook

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../CONNECTORS.md).

Review a contract against your organization's negotiation playbook. Analyze each clause, flag deviations, generate redline suggestions, and provide business impact analysis.

## Invocation

```
/review-contract
```

## Workflow

### Step 1: Accept the Contract

Accept the contract in any of these formats:
- **File reference**: The user provides a filename or path to a PDF, DOCX, or other document
- **Pasted text**: Contract text pasted directly into the conversation
- **File attachment**: PDF, DOCX, or other document uploaded via the attachment button
- **URL**: Link to a contract in your CLM, cloud storage (e.g., Box, Egnyte, SharePoint), or other document system
- **Image attachments**: Screenshots or photos of contract pages (PNG, JPG)

If no contract is provided, prompt the user to supply one.

**Reading files from the filesystem**: When the user references a file by name or path, use the available tools to locate and read it:
1. If only a filename is given (e.g., "review contract.pdf"), use **Glob** to search for it in common locations: `~/Documents/**`, `~/Downloads/**`, `~/Desktop/**`, and the current workspace directory
2. Once found, use the **Read** tool to read the file contents — the Read tool supports PDFs, images, and text files natively regardless of model provider
3. If the file is a URL, use **WebFetch** to retrieve it
4. If connected to a document storage MCP server (Box, Egnyte, SharePoint), try retrieving the document through that connector
5. Only ask the user to paste text as a last resort if all tool-based approaches fail

### Step 2: Gather Context

Use the **question** tool to gather context before beginning the review. Call the question tool with:

```json
{
  "questions": [
    {
      "question": "Which side are you on in this agreement?",
      "header": "Your Side",
      "options": [
        {"label": "Customer / Buyer", "description": "You are purchasing goods or services"},
        {"label": "Vendor / Supplier", "description": "You are providing goods or services"},
        {"label": "Licensee", "description": "You are receiving a license"},
        {"label": "Licensor", "description": "You are granting a license"},
        {"label": "Partner", "description": "This is a partnership or joint venture agreement"}
      ]
    },
    {
      "question": "Are there specific focus areas you want prioritized?",
      "header": "Focus Areas",
      "multiple": true,
      "options": [
        {"label": "Data Protection & Privacy", "description": "GDPR, CCPA, DPA requirements"},
        {"label": "IP Ownership", "description": "Intellectual property rights and assignments"},
        {"label": "Limitation of Liability", "description": "Liability caps, carveouts, consequential damages"},
        {"label": "Term & Termination", "description": "Duration, renewal, exit provisions"}
      ]
    }
  ]
}
```

Then ask about deadline and any deal context. If the user provides partial context, proceed with what you have and note assumptions.

### Step 3: Load the Playbook

Look for the organization's contract review playbook in local settings (e.g., `legal.local.md` or similar configuration files).

The playbook should define:
- **Standard positions**: The organization's preferred terms for each major clause type
- **Acceptable ranges**: Terms that can be agreed to without escalation
- **Escalation triggers**: Terms that require senior counsel review or outside counsel involvement

**If no playbook is configured**, use the **question** tool to ask:

```json
{
  "questions": [
    {
      "question": "No contract review playbook was found. How would you like to proceed?",
      "header": "Playbook",
      "options": [
        {"label": "Use Generic Standards", "description": "Review against widely-accepted commercial standards as baseline"},
        {"label": "Set Up Playbook", "description": "Walk through defining your organization's standard positions for key clauses"},
        {"label": "Import Playbook", "description": "Load a playbook from a file (provide path or filename)"}
      ]
    }
  ]
}
```

If proceeding generically, clearly note that the review is based on general commercial standards, not the organization's specific positions

### Step 4: Clause-by-Clause Analysis

Analyze the contract systematically, covering at minimum:

| Clause Category | Key Review Points |
|----------------|-------------------|
| **Limitation of Liability** | Cap amount, carveouts, mutual vs. unilateral, consequential damages |
| **Indemnification** | Scope, mutual vs. unilateral, cap, IP infringement, data breach |
| **IP Ownership** | Pre-existing IP, developed IP, work-for-hire, license grants, assignment |
| **Data Protection** | DPA requirement, processing terms, sub-processors, breach notification, cross-border transfers |
| **Confidentiality** | Scope, term, carveouts, return/destruction obligations |
| **Representations & Warranties** | Scope, disclaimers, survival period |
| **Term & Termination** | Duration, renewal, termination for convenience, termination for cause, wind-down |
| **Governing Law & Dispute Resolution** | Jurisdiction, venue, arbitration vs. litigation |
| **Insurance** | Coverage requirements, minimums, evidence of coverage |
| **Assignment** | Consent requirements, change of control, exceptions |
| **Force Majeure** | Scope, notification, termination rights |
| **Payment Terms** | Net terms, late fees, taxes, price escalation |

For each clause, assess against the playbook (or generic standards) and note whether it is present, absent, or unusual.

### Step 5: Flag Deviations

Classify each deviation from the playbook using a three-tier system:

#### GREEN -- Acceptable
- Aligns with or is better than the organization's standard position
- Minor variations that are commercially reasonable
- No action needed; note for awareness

#### YELLOW -- Negotiate
- Falls outside standard position but within negotiable range
- Common in the market but not the organization's preference
- Requires attention but not escalation
- **Include**: Specific redline language to bring the term back to standard position
- **Include**: Fallback position if the counterparty pushes back
- **Include**: Business impact of accepting as-is vs. negotiating

#### RED -- Escalate
- Falls outside acceptable range or triggers an escalation criterion
- Unusual or aggressive terms that pose material risk
- Requires senior counsel review, outside counsel involvement, or business decision-maker sign-off
- **Include**: Why this is a RED flag (specific risk)
- **Include**: What the standard market position looks like
- **Include**: Business impact and potential exposure
- **Include**: Recommended escalation path

### Step 6: Generate Redline Suggestions

For each YELLOW and RED deviation, provide:
- **Current language**: Quote the relevant contract text
- **Suggested redline**: Specific alternative language
- **Rationale**: Brief explanation suitable for sharing with the counterparty
- **Priority**: Whether this is a must-have or nice-to-have in negotiation

### Step 7: Business Impact Summary

Provide a summary section covering:
- **Overall risk assessment**: High-level view of the contract's risk profile
- **Top 3 issues**: The most important items to address
- **Negotiation strategy**: Recommended approach (which issues to lead with, what to concede)
- **Timeline considerations**: Any urgency factors affecting the negotiation approach

### Step 8: CLM Routing (If Connected)

If a Contract Lifecycle Management system is connected via MCP:
- Recommend the appropriate approval workflow based on contract type and risk level
- Suggest the correct routing path (e.g., standard approval, senior counsel, outside counsel)
- Note any required approvals based on contract value or risk flags

If no CLM is connected, skip this step.

## Output Format

Structure the output as:

```
## Contract Review Summary

**Document**: [contract name/identifier]
**Parties**: [party names and roles]
**Your Side**: [vendor/customer/etc.]
**Deadline**: [if provided]
**Review Basis**: [Playbook / Generic Standards]

## Key Findings

[Top 3-5 issues with severity flags]

## Clause-by-Clause Analysis

### [Clause Category] -- [GREEN/YELLOW/RED]
**Contract says**: [summary of the provision]
**Playbook position**: [your standard]
**Deviation**: [description of gap]
**Business impact**: [what this means practically]
**Redline suggestion**: [specific language, if YELLOW or RED]

[Repeat for each major clause]

## Negotiation Strategy

[Recommended approach, priorities, concession candidates]

## Next Steps

[Specific actions to take]
```

## Notes

- If the contract is in a language other than English, note this and ask if the user wants a translation or review in the original language
- For very long contracts (50+ pages), offer to focus on the most material sections first and then do a complete review
- Always remind the user that this analysis should be reviewed by qualified legal counsel before being relied upon for legal decisions
