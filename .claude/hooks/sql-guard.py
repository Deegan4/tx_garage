#!/usr/bin/env python3
"""
PreToolUse guard: blocks Write/Edit operations that would introduce
SQL injection patterns into Lua server code.

Detection strategy: PRAGMATIC (mode B)
  - Inspects the first argument of MySQL.{query,update,insert,scalar}.await(...)
  - Flags Lua string concatenation (..) or string.format inside that argument
  - Allows concatenation inside the params table (second argument)
  - Allows multi-line static SQL ([[ ... ]]) and ternary-style SQL constants

Exit codes:
  0 = allow
  2 = block (PreToolUse contract: stderr is shown to the user)
"""
import sys, json, re

# Read tool input from Claude Code
data = json.load(sys.stdin)
tool_input = data.get('tool_input', {}) or {}
file_path = tool_input.get('file_path', '') or ''

# Only audit Lua files in server-side directories
if not file_path.endswith('.lua'):
    sys.exit(0)
if '/server/' not in file_path and not file_path.endswith('/main.lua'):
    # only server-side SQL is reachable by clients
    if '/server/' not in file_path:
        sys.exit(0)

# Reconstruct the file content as it WILL look after the edit
content = ''
if data.get('tool_name') == 'Write':
    content = tool_input.get('content', '') or ''
elif data.get('tool_name') == 'Edit':
    # For Edit, we can't easily reconstruct the post-state without reading
    # the file. The new_string is the most actionable thing to scan.
    content = tool_input.get('new_string', '') or ''
else:
    sys.exit(0)

# Find every MySQL.<method>.await( ... ) call and extract its first argument.
# We don't need a real Lua parser; we just need to find the query-string arg.
# Regex grabs the call up to the first comma at paren-depth 0, OR up to the
# closing paren if there's no params table.
CALL_RE = re.compile(
    r"MySQL\.(?:query|update|insert|scalar|prepare)(?:\.await)?\s*\(",
    re.IGNORECASE,
)

def first_arg_span(src, open_paren_idx):
    """Return (start, end) of the first argument inside a call whose '(' is at open_paren_idx."""
    depth = 1
    i = open_paren_idx + 1
    start = i
    in_long = False
    long_close = None
    in_str = None  # ' or "
    while i < len(src) and depth > 0:
        c = src[i]
        # Long brackets [[ ]]
        if not in_str and not in_long and c == '[' and i + 1 < len(src) and src[i+1] == '[':
            in_long = True
            long_close = ']]'
            i += 2
            continue
        if in_long:
            if src.startswith(long_close, i):
                in_long = False
                i += 2
                continue
            i += 1
            continue
        # Short strings
        if not in_str and c in ("'", '"'):
            in_str = c
            i += 1
            continue
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        # Parens
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return (start, i)
        elif c == ',' and depth == 1:
            return (start, i)
        i += 1
    return (start, i)

violations = []
for m in CALL_RE.finditer(content):
    open_idx = m.end() - 1  # the '(' position
    a_start, a_end = first_arg_span(content, open_idx)
    arg = content[a_start:a_end]

    # Strip long-bracket and short-string literals; what remains is "code"
    arg_no_long = re.sub(r"\[\[.*?\]\]", "", arg, flags=re.DOTALL)
    arg_no_str = re.sub(r"'(?:\\.|[^'\\])*'", "", arg_no_long)
    arg_no_str = re.sub(r'"(?:\\.|[^"\\])*"', "", arg_no_str)

    # Look for ".." (concat) or string.format outside literals
    if re.search(r"\.\.", arg_no_str) or re.search(r"\bstring\.format\b", arg_no_str):
        # Find the line number for a useful error message
        line_no = content.count('\n', 0, m.start()) + 1
        snippet = content[m.start():a_end + 1].replace('\n', ' ')[:140]
        violations.append((line_no, snippet))

if violations:
    msg_lines = [
        "BLOCKED: Possible SQL injection in " + file_path,
        "",
        "tx_garage rule: never concatenate or string.format into the query argument.",
        "Use ? placeholders and pass values in the params table.",
        "",
    ]
    for line_no, snip in violations:
        msg_lines.append(f"  line {line_no}: {snip}")
    msg_lines.append("")
    msg_lines.append("If this is a false positive (e.g., joining two static SQL constants),")
    msg_lines.append("refactor the constant into a single [[ ... ]] block before retrying.")
    print("\n".join(msg_lines), file=sys.stderr)
    sys.exit(2)

sys.exit(0)
