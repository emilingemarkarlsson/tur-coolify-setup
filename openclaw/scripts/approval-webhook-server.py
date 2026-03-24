#!/usr/bin/env python3
"""
TUR OpenClaw – Approval Webhook Server
Lyssnar på HTTP-anrop från n8n och kör publish/reject-kommandon.

Port: 9191
Endpoints:
  POST /publish?slug=SLUG&site=SITE
  POST /reject?slug=SLUG

Kör som systemd-tjänst på hosten (ej i container).
"""
import http.server
import urllib.parse
import subprocess
import json
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("approval-webhook")

CONTAINER = "openclaw-w44cc84w8kog4og400008csg"
SCRIPTS    = "/data/.openclaw/scripts"


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log.info(fmt % args)

    def send_json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        slug   = params.get("slug",  [""])[0]
        site   = params.get("site",  [""])[0]

        if parsed.path == "/publish" and slug and site:
            if site == "thehockeybrain":
                script = f"{SCRIPTS}/publish-draft-thehockeybrain.sh"
            else:
                script = f"{SCRIPTS}/publish-draft.sh"
            cmd = ["docker", "exec", CONTAINER, "bash", script, slug]
            log.info("PUBLISH %s site=%s", slug, site)

        elif parsed.path == "/reject" and slug:
            cmd = [
                "docker", "exec", CONTAINER, "bash", "-c",
                f"rm -f {SCRIPTS}/../drafts/{slug}.md "
                f"{SCRIPTS}/../drafts/{slug}.meta && echo 'Kasserad: {slug}'"
            ]
            log.info("REJECT %s", slug)

        else:
            self.send_json(400, {"error": "bad request", "path": self.path})
            return

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if result.returncode == 0:
                self.send_json(200, {"ok": True, "stdout": result.stdout[-500:]})
            else:
                log.error("Command failed: %s", result.stderr)
                self.send_json(500, {"ok": False, "stderr": result.stderr[-500:]})
        except subprocess.TimeoutExpired:
            self.send_json(504, {"error": "timeout"})
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ok": True})
        else:
            self.send_json(404, {"error": "not found"})


if __name__ == "__main__":
    port = 9191
    server = http.server.HTTPServer(("0.0.0.0", port), Handler)
    log.info("Approval webhook server listening on :%d", port)
    server.serve_forever()
