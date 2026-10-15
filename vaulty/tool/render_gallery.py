#!/usr/bin/env python3
"""Package the Flutter test renderings into an offline HTML gallery."""
import base64
from pathlib import Path
root = Path(__file__).resolve().parents[1]
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Vaulty · Design gallery</title><style>body{margin:0;background:#f1eee8;color:#2b2d2f;font:16px system-ui;padding:32px}h1,h2{font-weight:600}p{color:#5e6164;max-width:760px;line-height:1.5}main{display:flex;flex-wrap:wrap;gap:32px}figure{margin:0}img{width:min(100%,390px);border-radius:20px}figcaption{margin:16px 0}section{margin-top:48px}</style><h1>Vaulty / Design gallery</h1><p>Real Flutter renders. Public Sans, accessible muted tones, light & dark. Run the debug gallery to inspect every component and token; these are static snapshots, not a second app.</p><main>'''
def figure(path, label):
    image = base64.b64encode(path.read_bytes()).decode()
    return f'<figure><figcaption>{label}</figcaption><img alt="{label}" src="data:image/png;base64,{image}"></figure>'
for mode in ['light', 'dark']:
    html += figure(root / f'docs/gallery-{mode}.png', mode.title() + ' / Components')
html += '</main><section><h2>A quiet home for important things.</h2><p>Android UI preview · mock data only</p><main>'
for name in ['insights', 'documents', 'detail', 'shared', 'settings']:
    html += figure(root / f'docs/screens/{name}.png', name.title())
html += '</main></section></html>'
(root / 'docs/design-gallery.html').write_text(html)
print('Updated self-contained Flutter gallery.')
