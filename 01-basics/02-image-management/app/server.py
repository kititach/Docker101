import http.server
import json
import os

VERSION = os.environ.get("APP_VERSION", "1.0")
PORT = int(os.environ.get("PORT", 8080))


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "version": VERSION,
            "hostname": os.uname().nodename,
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    print(f"myapp v{VERSION} listening on :{PORT}")
    http.server.HTTPServer(("", PORT), Handler).serve_forever()
