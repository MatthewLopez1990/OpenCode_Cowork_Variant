---
description: Rapidly triage an incoming NDA — classify as standard approval, counsel review, or full legal review
argument-hint: "<NDA file or text>"
---

# /triage-nda -- NDA Pre-Screening

> If you see unfamiliar placeholders or need to check which tools are connected, see [CONNECTORS.md](../CONNECTORS.md).

Rapidly triage incoming NDAs against standard screening criteria. Classify the NDA for routing: standard approval, counsel review, or full legal review.

## Invocation

```
/triage-nda
```

## Workflow

### Step 1: Accept the NDA

Accept the NDA in any format:
- **File reference**: The user provides a filename or path to a PDF, DOCX, or other document
- **Pasted text**: NDA text pasted directly into the conversation
- **File attachment**: PDF, DOCX, or other document uploaded via the attachment button
- **URL**: Link to the NDA in a document system
- **Image attachments**: Screenshots or photos of NDA pages (PNG, JPG)

If no NDA is provided, prompt the user to supply one.

**Reading files from the filesystem**: When the user references a file by name or path, use the available tools to locate and read it:
1. If only a filename is given (e.g., "nda.pdf"), use **Glob** to search for it in common locations: `~/Documents/**`, `~/Downloads/**`, `~/Desktop/**`, and the current workspace directory
2. Once found, use the **Read** tool to read the file contents — the Read tool supports PDFs, images, and text files natively regardless of model provider
3. If the file is a URL, use **WebFetch** to retrieve it
4. If connected to a document storage MCP server (Box, Egnyte, SharePoint), try retrieving the document through that connector
5. Only ask the user to paste text as a last resort if all tool-based approaches fail

### Step 2: Load NDA Playbook

Look for NDA screening criteria in local settings (e.g., `legal.local.md`).

The NDA playbook should define:
- Mutual vs. unilateral requirements
- Acceptable term lengths
- Required carveouts
- Prohibited provisions
- Organization-specific requirements

**If no NDA playbook is configured:**
- Proceed with reasonable market-standard defaults
- Note clearly that defaults are being used
- Defaults applied:
  - Mutual obligations required (unless the organization is only disclosing)
  - Term: 2-3 years standard, up to 5 years for trade secrets
  - Standard carveouts required: independently developed, publicly available, rightfully received from third party, required by law
  - No non-solicitation or non-compete provisions
  - No residuals clause (or narrowly scoped if present)
  - Governing law in a reasonable commercial jurisdiction

### Step 3: Quick Screen

Evaluate the NDA against each screening criterion:

| Criterion | Check |
|-----------|-------|
| **Mutual vs. Unilateral** | Are obligations mutual? If unilateral, is that appropriate for the relationship? |
| **Definition of Confidential Information** | Reasonable scope? Not overbroad (e.g., "all information of any kind")? |
| **Term** | Within acceptable range? Reasonable for the type of information? |
| **Standard Carveouts** | All required carveouts present? (independent development, public knowledge, third-party receipt, legal compulsion) |
| **Permitted Disclosures** | Can share with employees, advisors, contractors who need to know? |
| **Return/Destruction** | Reasonable obligations on termination? Allows retention of legal/compliance copies? |
| **Residuals** | If present, narrowly scoped to unaided memory? |
| **Non-Solicitation** | Any non-solicit provisions embedded? |
| **Non-Compete** | Any non-compete provisions embedded? |
| **Injunctive Relief** | Reasonable or one-sided? Pre-determined damages? |
| **Governing Law** | Acceptable jurisdiction? |
| **Assignment** | Reasonable assignment provisions? |
| **Unusual Provisions** | Any non-standard clauses that don't belong in an NDA? |

### Step 4: Classify

Based on the screening results, assign a classification:

#### GREEN -- Standard Approval
All criteria met. NDA is market-standard with no unusual provisions.
- **Route**: Can be approved and signed via standard process
- **Action**: Proceed to signature with standard delegation of authority

#### YELLOW -- Counsel Review Needed
One or more criteria have minor deviations that need review but are potentially acceptable:
- Definition of confidential information is broader than ideal but not unreasonable
- Term is longer than standard but within market range
- Residuals clause present but narrowly scoped
- Minor jurisdiction preference issue
- Missing one standard carveout that could be added
- **Route**: Flag specific issues for counsel review
- **Action**: Counsel can likely resolve in a single review pass

#### RED -- Significant Issues
One or more criteria have material deviations that pose risk:
- Unilateral obligations when mutual is required
- Missing critical carveouts (e.g., no independent development carveout)
- Non-solicitation or non-compete provisions embedded
- Unreasonable term (10+ years) without justification
- Overbroad definition that could capture public information
- Unusual provisions (exclusivity, audit rights, IP assignment)
- Highly unfavorable jurisdiction with no negotiation room
- **Route**: Full legal review required
- **Action**: Do not sign; requires negotiation or counterproposal

### Step 5: Generate Triage Report

Output a structured report:

```
## NDA Triage Report

**Classification**: [GREEN / YELLOW / RED]
**Parties**: [party names]
**Type**: [Mutual / Unilateral (disclosing) / Unilateral (receiving)]
**Term**: [duration]
**Governing Law**: [jurisdiction]
**Review Basis**: [Playbook / Default Standards]

## Screening Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| Mutual Obligations | [PASS/FLAG/FAIL] | [details] |
| Definition Scope | [PASS/FLAG/FAIL] | [details] |
| Term | [PASS/FLAG/FAIL] | [details] |
| Standard Carveouts | [PASS/FLAG/FAIL] | [details] |
| [etc.] | | |

## Issues Found

### [Issue 1 -- YELLOW/RED]
**What**: [description]
**Risk**: [what could go wrong]
**Suggested Fix**: [specific language or approach]

[Repeat for each issue]

## Recommendation

[Specific next step: approve, send for review with specific notes, or reject/counter]

## Next Steps

1. [Action item 1]
2. [Action item 2]
```

### Step 6: Routing Suggestion

After the triage report, use the **question** tool to ask the user what they want to do next:

```json
{
  "questions": [
    {
      "question": "How would you like to proceed with this NDA?",
      "header": "Next Step",
      "options": [
        {"label": "Approve & Route to Signature", "description": "Send for standard approval and signature (GREEN items only)"},
        {"label": "Send for Counsel Review", "description": "Route flagged issues to counsel for review"},
        {"label": "Generate Counterproposal", "description": "Draft alternative NDA language addressing the issues found"},
        {"label": "Full Contract Review", "description": "Escalate to a comprehensive /review-contract analysis"}
      ]
    }
  ]
}
```

Based on the classification:
- **GREEN**: Suggest the user proceed to signature under their standard delegation of authority
- **YELLOW**: Identify which specific issues need counsel attention and suggest the user route to the appropriate reviewer
- **RED**: Recommend the user engage counsel for a full review, and provide a counterproposal NDA if the organization has a standard form

## Notes

- If the document is not actually an NDA (e.g., it's labeled as an NDA but contains substantive commercial terms), flag this immediately as a RED and recommend full contract review instead
- For NDAs that are part of a larger agreement (e.g., confidentiality section in an MSA), note that the broader agreement context may affect the analysis
- Always note that this is a screening tool and counsel should review any items the user is uncertain about
