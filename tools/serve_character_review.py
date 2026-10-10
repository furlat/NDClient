"""Local review of actual character source-interaction materials; no game server."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import struct
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def review_cases():
    components = json.loads((ROOT / 'authoring/characters/sheet-components.json').read_text())
    resources = json.loads((ROOT / 'authoring/catalog/resources.json').read_text())
    rigs = json.loads((ROOT / 'authoring/catalog/rigs.json').read_text())
    clocks = {}
    for rig in rigs.values():
        for clip in rig['clips'].values():
            for resource in clip['sheets'].values():
                clocks[resources[resource]] = clip['fps']
    cases = []
    for url, row in components.items():
        if row.get('composition', {}).get('kind') != 'source_interaction':
            continue
        relative = Path(url.removeprefix('/media/'))
        with (ROOT / '.media' / relative).open('rb') as source:
            header = source.read(24)
        width, height = struct.unpack('>II', header[16:24])
        cases.append(dict(url=url, pack=relative.parts[2], character=relative.parts[-2],
                          action=relative.stem, frames=width//128, cell=128, width=width,
                          height=height, fps=clocks.get(url), hasAccent=row['composition']['has_accent']))
    return cases


def run(port):
    cases = json.dumps(review_cases()).encode()

    class ReviewHandler(SimpleHTTPRequestHandler):
        def do_GET(self):
            path = unquote(urlsplit(self.path).path)
            if path == '/cases.json':
                self.send_response(200); self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(cases))); self.end_headers()
                self.wfile.write(cases)
                return
            return super().do_GET()

        def translate_path(self, path):
            path = unquote(urlsplit(path).path)
            if path == '/':
                return str(ROOT / 'tools/character-review/index.html')
            if path == '/vendor/pixi.mjs':
                return str(ROOT / 'node_modules/pixi.js/dist/pixi.mjs')
            prefix = next((p for p in ('/media/', '/authoring/', '/src/', '/tools/character-review/') if path.startswith(p)), None)
            if prefix is None:
                return str(ROOT / '__not_served__')
            base = ROOT / ('.media' if prefix == '/media/' else prefix.strip('/'))
            target = (base / path.removeprefix(prefix)).resolve()
            return str(target) if target.is_relative_to(base.resolve()) else str(ROOT / '__not_served__')

        def log_message(self, format, *args):
            if args and str(args[1]) != '200':
                super().log_message(format, *args)

    print(f'Character materials: http://127.0.0.1:{port}/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), ReviewHandler).serve_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8798)
    run(parser.parse_args().port)
