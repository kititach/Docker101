import http.server
import os
import socket
import socketserver

PORT = int(os.environ.get("PORT", "8080"))
VERSION = os.environ.get("APP_VERSION", "dev")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._reply(200, "ok\n")
            return
        body = f"hello from CI/CD lab — version={VERSION} host={socket.gethostname()}\n"
        self._reply(200, body)

    def _reply(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"listening on :{PORT}", flush=True)
    httpd.serve_forever()
