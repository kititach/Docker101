import http.server
import os
import signal
import time

PORT = int(os.environ.get("PORT", 8080))
NAME = os.environ.get("APP_NAME", "hello-docker")
START_TIME = time.time()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        uptime = int(time.time() - START_TIME)
        body = f"{NAME} | uptime: {uptime}s | pid: {os.getpid()}\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, format, *args):
        print(f"[{self.address_string()}] {format % args}", flush=True)


def handle_sigterm(signum, frame):
    print("SIGTERM received — shutting down gracefully", flush=True)
    raise SystemExit(0)


signal.signal(signal.SIGTERM, handle_sigterm)

print(f"Starting {NAME} on port {PORT} (pid {os.getpid()})", flush=True)
with http.server.HTTPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
