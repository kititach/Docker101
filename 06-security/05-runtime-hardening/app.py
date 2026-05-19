from flask import Flask, jsonify
import os, socket

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({
        "service": "hardened-app",
        "uid": os.getuid(),
        "host": socket.gethostname(),
    })

@app.route("/health")
def health():
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
