from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.js': 'text/javascript', '.mjs': 'text/javascript'}
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

if __name__ == '__main__':
    root = Path(__file__).resolve().parent / 'public'
    print('Vaulty browser preview listening on 0.0.0.0:8080', flush=True)
    ThreadingHTTPServer(('0.0.0.0', 8080), partial(Handler, directory=str(root))).serve_forever()
