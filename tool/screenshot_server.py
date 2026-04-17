"""Screenshot capture server for the Android CI screenshot workflow.

Listens on 0.0.0.0:<port> over HTTPS using a CI-generated self-signed cert.
The integration test (inside the emulator) POSTs to
https://10.0.2.2:<port>/screenshot/<name>; we shell out to
`adb exec-out screencap -p` and write build/screenshots/<name>.png, then
return 200. The synchronous response is the test's signal that the frame is
captured and it can advance.

The matching cert is bundled into the debug APK via res/raw and trusted via
network_security_config.xml (scoped to 10.0.2.2). Release builds don't
include either resource.

Why this exists: binding.convertFlutterSurfaceToImage() deadlocks on the
Android emulator, so capture has to be host-driven. See screenshots.yml.
"""

import argparse
import os
import re
import ssl
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NAME_RE = re.compile(r"^[A-Za-z0-9_]+$")


def make_handler(out_dir):
    class Handler(BaseHTTPRequestHandler):
        def _reply(self, status, body=b""):
            self.send_response(status)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body:
                self.wfile.write(body)

        def do_GET(self):
            if self.path == "/health":
                self._reply(200, b"ok")
            else:
                self._reply(404)

        def do_POST(self):
            prefix = "/screenshot/"
            if not self.path.startswith(prefix):
                self._reply(404)
                return
            name = self.path[len(prefix):]
            if not NAME_RE.match(name):
                self._reply(400, b"invalid name")
                return
            path = os.path.join(out_dir, f"{name}.png")
            try:
                with open(path, "wb") as f:
                    subprocess.run(
                        ["adb", "exec-out", "screencap", "-p"],
                        stdout=f, check=True,
                    )
            except subprocess.CalledProcessError as e:
                self._reply(500, f"screencap failed: {e}".encode())
                return
            self._reply(200, b"ok")

        def log_message(self, fmt, *args):
            sys.stderr.write("[screenshot-server] " + fmt % args + "\n")

    return Handler


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cert", required=True, help="PEM cert path")
    ap.add_argument("--key", required=True, help="PEM private key path")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=args.cert, keyfile=args.key)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), make_handler(args.out))
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    sys.stderr.write(
        f"[screenshot-server] HTTPS on 0.0.0.0:{args.port}, out={args.out}\n"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
