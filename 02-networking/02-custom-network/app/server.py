import http.server
import json
import os
import socket
import urllib.request

PORT = int(os.environ.get("PORT", 8080))
SERVICE = os.environ.get("SERVICE_NAME", "unknown")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        info = {
            "service": SERVICE,
            "hostname": socket.gethostname(),
            "ip": socket.gethostbyname(socket.gethostname()),
        }
        # ถ้าส่ง ?target=<hostname> จะพยายาม resolve และ fetch
        target = None
        if self.path.startswith("/?target="):
            target = self.path.split("=", 1)[1]
            try:
                resolved_ip = socket.gethostbyname(target)
                resp = urllib.request.urlopen(f"http://{target}:8080", timeout=2)
                info["target"] = target
                info["target_ip"] = resolved_ip
                info["target_response"] = json.loads(resp.read())
            except Exception as e:
                info["target"] = target
                info["target_error"] = str(e)

        body = json.dumps(info, indent=2).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{SERVICE}] {self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    print(f"[{SERVICE}] listening on :{PORT}")
    http.server.HTTPServer(("", PORT), Handler).serve_forever()
