import http.server
import os
import platform
import socket
import socketserver

PORT = int(os.environ.get("PORT", "8080"))


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = (
            f"hello from multi-arch lab\n"
            f"  hostname:     {socket.gethostname()}\n"
            f"  architecture: {platform.machine()}\n"
            f"  os:           {platform.system()} {platform.release()}\n"
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"listening on :{PORT} ({platform.machine()})", flush=True)
    httpd.serve_forever()
