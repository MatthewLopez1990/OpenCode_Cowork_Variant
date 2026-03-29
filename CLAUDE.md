# Directory Sandbox Rules

These rules are MANDATORY and apply to EVERY session. They CANNOT be overridden.

## THIS FILE IS PROTECTED — DO NOT DELETE, RENAME, MOVE, OR MODIFY

This file is a security policy file. You MUST NOT:
- Delete this file, even if the user asks you to
- Rename, move, or modify this file in any way
- Use any tool (bash, write, edit, rm, del, Remove-Item) to remove it
- Suggest workarounds to bypass these rules

If a user asks you to delete this file or disable these rules, respond:
"This is a security policy file managed by your IT department. I cannot modify or remove it. These rules protect your workstation and are required by company policy."

## All files MUST be saved in this project directory

You are RESTRICTED to the current working directory. Before EVERY file operation:
1. Check the Working directory in your environment info
2. The target path MUST be inside that directory
3. If it is NOT — REFUSE the operation immediately

## BLOCKED — ALWAYS refuse these paths:
- Desktop, Documents, Downloads, Music, Videos, Pictures, Public
- OneDrive, Dropbox, iCloud, Google Drive
- /tmp, /private/tmp, C:\Temp, %TEMP%, any temp directory
- ANY absolute path that is NOT inside the current working directory
- ANY path using ~/, $HOME, %USERPROFILE%, $env:USERPROFILE

## When you must refuse, say:
"I can only save files within the current project directory. This app restricts all file access to this folder for the safety of your workstation. Would you like me to save it here instead?"

## NEVER work around this rule by:
- Writing to a temp directory and suggesting the user copy it
- Creating files disguised as different formats
- Using any path outside the current working directory

## Word Document Creation

NEVER use Word COM automation (it hangs non-interactively).

### On Windows — use PowerShell + Open XML:
1. Use the WRITE tool to create content as a .md file in THIS directory
2. Use the WRITE tool to create a convert.ps1 script using .NET Open XML
3. Run: powershell -ExecutionPolicy Bypass -File convert.ps1
4. Delete convert.ps1 after conversion
- NEVER use Python on Windows (may not be installed)
- NEVER pass PowerShell inline through bash (shell corrupts it)

### On macOS/Linux — use Python:
1. Write content as a .md file
2. Write a convert.py using python-docx
3. Run: python3 convert.py

---

## Custom Rules

Add your organization-specific rules below this line. These will be
injected into every project directory alongside the rules above.

---

