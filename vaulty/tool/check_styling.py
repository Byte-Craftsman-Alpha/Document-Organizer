#!/usr/bin/env python3
"""Fail when presentation constants leak out of the theme boundary."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
patterns = {
    'raw color': r'\b(?:Color\s*\(|Colors\.)',
    'inline typography': r'\b(?:TextStyle\s*\(|fontSize\s*:|fontFamily\s*:|fontWeight\s*:)',
    'inline shadow': r'\bBoxShadow\s*\(',
    'numeric spacing': r'\bEdgeInsets(?:\.\w+)?\([^)]*\b\d+(?:\.\d+)?',
    'numeric radius': r'\b(?:BorderRadius|Radius)\.\w+\(\s*\d',
    'numeric duration': r'Duration\(\s*(?:milliseconds|microseconds)\s*:',
    'numeric dimension': r'\b(?:height|width|size|elevation|blurRadius)\s*:\s*\d',
}
failures = []
for file in (root / 'lib').rglob('*.dart'):
    rel = file.relative_to(root)
    if 'theme' in rel.parts or 'data' in rel.parts or 'domain' in rel.parts:
        continue
    text = re.sub(r'//[^\n]*', '', file.read_text())
    for name, pattern in patterns.items():
        for match in re.finditer(pattern, text):
            failures.append(f'{rel}:{text[:match.start()].count(chr(10))+1}: {name}: {match.group(0)}')
if failures:
    print('\n'.join(failures))
    raise SystemExit(1)
print('PASS: no raw colors, typography, shadows, spacing, radius, dimensions or millisecond timings outside core/theme.')
print('Data/domain excluded: byte counts, seed counts, dates and simulated I/O latency are not styling.')
