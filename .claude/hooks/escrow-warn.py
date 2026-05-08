#!/usr/bin/env python3
"""
PostToolUse advisory: when an edit lands in a file that will be ENCRYPTED
by Tebex escrow (i.e., not in fxmanifest.lua's escrow_ignore allowlist),
surface a systemMessage so the editor remembers buyers cannot patch it.

Mode: QUIET — only fires for escrowed files. Silent on allowlisted ones.

Exit codes are non-blocking; we always exit 0.
"""
import sys, json, os, re, fnmatch

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get('tool_input', {}) or {}
file_path = tool_input.get('file_path', '') or ''
if not file_path:
    sys.exit(0)

# Resolve project root from this script's location
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Only inspect edits inside the resource directory
try:
    rel = os.path.relpath(file_path, root)
except ValueError:
    sys.exit(0)
if rel.startswith('..'):
    sys.exit(0)

# Skip non-shipping files (Claude config, git, etc.) — they aren't escrowed
SKIP_PREFIXES = ('.claude/', '.git/', '.github/')
if rel.startswith(SKIP_PREFIXES):
    sys.exit(0)

# Skip non-shipping documentation
SKIP_EXACT = {'CLAUDE.md', 'README.md', 'LICENSE', 'INSTALL.sql'}
if rel in SKIP_EXACT:
    sys.exit(0)

# Read fxmanifest.lua and extract escrow_ignore patterns
manifest = os.path.join(root, 'fxmanifest.lua')
if not os.path.exists(manifest):
    sys.exit(0)

with open(manifest, 'r', encoding='utf-8') as f:
    mtxt = f.read()

# Find: escrow_ignore { ... }
m = re.search(r"escrow_ignore\s*\{([^}]*)\}", mtxt, re.DOTALL)
if not m:
    sys.exit(0)

block = m.group(1)
patterns = re.findall(r"['\"]([^'\"]+)['\"]", block)

# fnmatch the relative path against each pattern
for pat in patterns:
    if fnmatch.fnmatch(rel, pat):
        # File is buyer-editable — quiet mode skips notification
        sys.exit(0)

# File IS escrowed — warn
msg = (
    f"⚠ Tebex escrow: {rel} will be ENCRYPTED at upload. "
    f"Buyers cannot edit or patch this file. "
    f"Move runtime-configurable defaults to config.lua / locales/ (already in escrow_ignore)."
)
print(json.dumps({"systemMessage": msg}))
sys.exit(0)
