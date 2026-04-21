"""Screenshot capture server for the CI screenshot workflow.

Listens on <port> and, on POST /screenshot/<name>, shells out to the
platform's native capture command and writes build/screenshots/<name>.png.
The synchronous 200 response is the test's signal that the PNG is written
and it can advance to the next screenshot.

Modes:
  android — `adb exec-out screencap -p`. TLS is required because the test
            runs inside the emulator and reaches the host via 10.0.2.2.
            Cert is minted per run and trust-pinned in the test.
  ios     — `xcrun simctl io <udid> screenshot <file>`. The sim shares the
            host's loopback, so plain HTTP on 127.0.0.1 is fine and no cert
            is needed.
  macos   — `screencapture -x <file>` on the host itself (Flutter macOS app
            runs in-process, not in a sim). Captures the full primary
            display; cropping to just the Pensine window is a v2 problem if
            the artifact ends up noisy. Plain HTTP on loopback, same as iOS.

Why host-driven at all: `binding.takeScreenshot` / `convertFlutterSurfaceToImage`
both hang on continuous-animation Flutter apps (the ticker calls setState
every frame). Capturing from the host sidesteps the Flutter screenshot path.
"""

import argparse
import ssl
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Mirrors the names produced by integration_test/screenshot_test.dart.
ALLOWED_NAMES = frozenset({
    "01_home",
    "02_thoughts",
    "03_flashcards",
    "04_flashcards_flipped",
    "05_checklist",
    "06_todo",
})


def capture_android(out_path: Path) -> None:
    with out_path.open("wb") as f:
        subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            stdout=f, check=True,
        )


def capture_ios(out_path: Path, udid: str) -> None:
    subprocess.run(
        ["xcrun", "simctl", "io", udid, "screenshot",
         "--type=png", str(out_path)],
        check=True,
    )


def capture_macos(out_path: Path) -> None:
    # -x: suppress shutter sound · full primary display. Cropping to the
    # Pensine window is deferred — if artifacts come back noisy we'll add
    # AppleScript + screencapture -R <region>.
    subprocess.run(
        ["screencapture", "-x", str(out_path)],
        check=True,
    )


def make_handler(out_dir: Path, capture):
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
            if not self.path.startswith("/screenshot/"):
                self._reply(404)
                return
            name = self.path.removeprefix("/screenshot/")
            if name not in ALLOWED_NAMES:
                self._reply(400, b"unknown name")
                return
            try:
                capture(out_dir / f"{name}.png")
            except subprocess.CalledProcessError as e:
                self._reply(500, f"capture failed: {e}".encode())
                return
            self._reply(200, b"ok")

        def log_message(self, fmt, *args):
            sys.stderr.write("[screenshot-server] " + fmt % args + "\n")

    return Handler


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True, choices=["android", "ios", "macos"])
    ap.add_argument("--udid", help="iOS simulator UDID (required for --mode ios)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--cert", type=Path, help="PEM cert path (enables HTTPS)")
    ap.add_argument("--key", type=Path, help="PEM private key path (enables HTTPS)")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    if args.mode == "android":
        capture = lambda path: capture_android(path)
    elif args.mode == "ios":
        if not args.udid:
            ap.error("--udid is required for --mode ios")
        capture = lambda path: capture_ios(path, args.udid)
    else:  # macos
        capture = lambda path: capture_macos(path)

    server = ThreadingHTTPServer(
        ("0.0.0.0", args.port), make_handler(args.out, capture)
    )
    scheme = "http"
    if args.cert and args.key:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(certfile=args.cert, keyfile=args.key)
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
        scheme = "https"
    sys.stderr.write(
        f"[screenshot-server] {scheme} on 0.0.0.0:{args.port}, "
        f"mode={args.mode}, out={args.out}\n"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
