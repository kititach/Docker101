from flask import Flask, jsonify
from cryptography.fernet import Fernet
import os, socket

app = Flask(__name__)
KEY = Fernet.generate_key()
cipher = Fernet(KEY)


@app.route("/")
def index():
    token = cipher.encrypt(b"hello-world").decode()
    plain = cipher.decrypt(token.encode()).decode()
    return jsonify({
        "service": "python-app",
        "host": socket.gethostname(),
        "encrypted": token[:30] + "...",
        "decrypted": plain,
    })


@app.route("/health")
def health():
    return "OK", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
