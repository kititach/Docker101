from flask import Flask, jsonify
import os
import redis
import socket

app = Flask(__name__)
r = redis.Redis(
    host=os.environ.get("REDIS_HOST", "redis"),
    port=6379,
    decode_responses=True,
)


@app.route("/")
def index():
    hits = r.incr("hits")
    return jsonify({
        "service": "backend",
        "hostname": socket.gethostname(),
        "hits": hits,
    })


@app.route("/health")
def health():
    r.ping()
    return "OK", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
