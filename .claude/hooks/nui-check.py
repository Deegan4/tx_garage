#!/usr/bin/env python3
import sys, json, re, glob, os

data = json.load(sys.stdin)
f = data.get('tool_input', {}).get('file_path', '')
if not f.endswith(('.lua', '.js')):
    sys.exit(0)

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
js_path = os.path.join(root, 'nui', 'script.js')
if not os.path.exists(js_path):
    sys.exit(0)

js = open(js_path).read()
posted = set(re.findall(r"nuiPost\(['\"]([^'\"]+)['\"]", js))
handled = set()
for fn in glob.glob(os.path.join(root, 'client', '*.lua')):
    handled.update(re.findall(r"RegisterNUICallback\(['\"]([^'\"]+)['\"]", open(fn).read()))
missing = sorted(posted - handled)
if missing:
    print(json.dumps({'systemMessage': 'NUI mismatch: JS posts to ' + ', '.join(missing) + ' with no Lua handler found.'}))
